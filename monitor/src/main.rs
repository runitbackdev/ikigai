//! ikigai-monitor: the shell's task manager data, as JSON lines on stdout. Runs Mission
//! Center's data daemon (Magpie) as a child, asks it for the CPU, memory, GPUs, processes
//! and running apps every tick and prints one `sample` event per tick. Requests come in on
//! stdin, one JSON object per line: `terminate` and `kill` with `pids`, `interval` with
//! `ms`. Stdin closing ends it, and the child with it: Quickshell runs one of these for as
//! long as the card is up, so nothing polls while it is closed.
//!
//! A reply that fails (a timeout, an error from the daemon, one that won't decode) is an
//! `error` event and not the end: the connection is opened again, the daemon started again
//! if it died, and the next tick carries on. Only failing to get it back ends the bridge.

mod nng;
mod sample;

use std::io::{self, BufRead, Write};
use std::os::unix::process::CommandExt;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::mpsc::{self, RecvTimeoutError};
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};

/// The daemon's binary; the Nix package substitutes its store path.
const MAGPIE: &str = "missioncenter-magpie";
/// How long to wait for the daemon to open its socket. Its first CPU reading takes about
/// half a second on top, with the answer being zeros until then.
const START_WAIT: Duration = Duration::from_secs(5);
/// Failed replies in a row before giving up on getting the daemon back.
const RETRIES: u32 = 3;

#[derive(Deserialize)]
#[serde(tag = "request", rename_all = "snake_case")]
enum Request {
    Terminate { pids: Vec<u32> },
    Kill { pids: Vec<u32> },
    Interval { ms: u64 },
}

#[derive(Serialize)]
struct Error<'a> {
    event: &'static str,
    message: &'a str,
}

enum Input {
    Line(String),
    Closed,
}

struct Daemon {
    child: Child,
    socket: PathBuf,
}

impl Daemon {
    fn spawn() -> io::Result<Daemon> {
        // A daemon started again gets its own socket, as the old one's Drop removes its own.
        static STARTS: AtomicU32 = AtomicU32::new(0);
        let start = STARTS.fetch_add(1, Ordering::Relaxed);
        let runtime_dir = std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
        let socket = runtime_dir.join(format!("ikigai-monitor-{}-{start}.ipc", std::process::id()));
        let _ = std::fs::remove_file(&socket);
        let mut command = Command::new(MAGPIE);
        command.arg("--addr").arg(format!("ipc://{}", socket.display())).stdin(Stdio::null()).stdout(Stdio::null());
        // The daemon goes with us, whichever way we go.
        unsafe {
            command.pre_exec(|| {
                rustix::process::set_parent_process_death_signal(Some(rustix::process::Signal::TERM))?;
                Ok(())
            });
        }
        let child = command.spawn()?;
        Ok(Daemon { child, socket })
    }

    fn connect(&mut self) -> io::Result<nng::Client> {
        let deadline = Instant::now() + START_WAIT;
        loop {
            if let Some(status) = self.child.try_wait()? {
                return Err(io::Error::other(format!("{MAGPIE} exited at start: {status}")));
            }
            if self.socket.exists() {
                match nng::Client::connect(&self.socket) {
                    Ok(client) => return Ok(client),
                    Err(e) if Instant::now() >= deadline => return Err(e),
                    Err(_) => {}
                }
            } else if Instant::now() >= deadline {
                return Err(io::Error::other(format!("{MAGPIE} did not open {}", self.socket.display())));
            }
            std::thread::sleep(Duration::from_millis(20));
        }
    }
}

impl Drop for Daemon {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
        let _ = std::fs::remove_file(&self.socket);
    }
}

fn emit<T: Serialize>(out: &mut impl Write, event: &T) -> io::Result<()> {
    let mut line = serde_json::to_string(event).expect("events are always serializable");
    line.push('\n');
    out.write_all(line.as_bytes())?;
    out.flush()
}

/// One failed reply: says so, and gets the daemon back before the next one.
fn failed(out: &mut impl Write, daemon: &mut Daemon, client: &mut nng::Client, failures: &mut u32, e: io::Error) -> io::Result<()> {
    *failures += 1;
    emit(out, &Error { event: "error", message: &e.to_string() })?;
    if *failures > RETRIES {
        return Err(e);
    }
    recover(daemon, client)
}

/// Gets a working connection back after a failed reply. A fresh one, since a timed-out
/// request can still be answered late and would put every reply after it one behind.
fn recover(daemon: &mut Daemon, client: &mut nng::Client) -> io::Result<()> {
    if daemon.child.try_wait()?.is_some() {
        *daemon = Daemon::spawn()?;
    }
    *client = daemon.connect()?;
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        let stdout = io::stdout();
        let _ = emit(&mut stdout.lock(), &Error { event: "error", message: &e.to_string() });
        eprintln!("ikigai-monitor: {e}");
        std::process::exit(1);
    }
}

fn run() -> io::Result<()> {
    let stop = Arc::new(AtomicBool::new(false));
    for signal in [signal_hook::consts::SIGTERM, signal_hook::consts::SIGINT, signal_hook::consts::SIGHUP] {
        signal_hook::flag::register(signal, stop.clone())?;
    }

    let mut daemon = Daemon::spawn()?;
    let mut client = daemon.connect()?;

    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        let stdin = io::stdin();
        for line in stdin.lock().lines() {
            let Ok(line) = line else { break };
            if tx.send(Input::Line(line)).is_err() {
                break;
            }
        }
        let _ = tx.send(Input::Closed);
    });

    let stdout = io::stdout();
    let mut out = stdout.lock();
    let mut interval = Duration::from_millis(1000);
    let mut failures = 0;

    while !stop.load(Ordering::Relaxed) {
        let next = Instant::now() + interval;
        match sample::read(&mut client) {
            Ok(sample) => {
                failures = 0;
                emit(&mut out, &sample)?;
            }
            Err(e) => failed(&mut out, &mut daemon, &mut client, &mut failures, e)?,
        }

        loop {
            let now = Instant::now();
            if now >= next || stop.load(Ordering::Relaxed) {
                break;
            }
            match rx.recv_timeout(next - now) {
                Ok(Input::Line(line)) => match serde_json::from_str::<Request>(&line) {
                    Ok(Request::Terminate { pids }) => {
                        if let Err(e) = sample::terminate(&mut client, pids) {
                            failed(&mut out, &mut daemon, &mut client, &mut failures, e)?;
                        }
                    }
                    Ok(Request::Kill { pids }) => {
                        if let Err(e) = sample::kill(&mut client, pids) {
                            failed(&mut out, &mut daemon, &mut client, &mut failures, e)?;
                        }
                    }
                    Ok(Request::Interval { ms }) => interval = Duration::from_millis(ms.clamp(250, 10_000)),
                    Err(e) => emit(&mut out, &Error { event: "error", message: &format!("bad request {line:?}: {e}") })?,
                },
                Ok(Input::Closed) | Err(RecvTimeoutError::Disconnected) => return Ok(()),
                Err(RecvTimeoutError::Timeout) => break,
            }
        }
    }
    Ok(())
}
