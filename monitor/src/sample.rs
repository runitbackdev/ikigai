//! One reading of the daemon, as the shell wants it: the numbers the Processes and
//! Performance views show, camelCase, nothing the first pass does not draw. Magpie
//! answers each request from its cache and refreshes after, so a sample is the state
//! as of the previous tick; the first one is mostly zeros.

use std::io;

use magpie_types::apps::apps_response;
use magpie_types::common::Empty;
use magpie_types::cpu::cpu_response;
use magpie_types::gpus::gpus_response;
use magpie_types::ipc::{Request, Response, request, response};
use magpie_types::memory::memory_response::memory_info;
use magpie_types::memory::{MemoryRequest, memory_request, memory_response};
use magpie_types::processes::{
    self as proc, KillProcessesRequest, ProcessState, ProcessesRequest, TerminateProcessesRequest, processes_request,
    processes_response,
};
use magpie_types::prost::Message;
use magpie_types::{apps, cpu, gpus, memory};
use serde::Serialize;

use crate::nng::Client;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Sample {
    pub event: &'static str,
    pub cpu: Cpu,
    pub memory: Memory,
    pub gpus: Vec<Gpu>,
    pub processes: Vec<Process>,
    pub apps: Vec<App>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Cpu {
    pub name: String,
    /// Percent of all logical processors, and the kernel's share of it.
    pub usage: f32,
    pub kernel: f32,
    pub cores: Vec<f32>,
    pub freq_mhz: u64,
    pub base_khz: Option<u64>,
    pub temp: Option<f32>,
    pub power: Option<f32>,
    pub processes: u64,
    pub threads: u64,
    pub handles: u64,
    pub uptime: u64,
    pub sockets: Option<u32>,
    pub l1: Option<u64>,
    pub l2: Option<u64>,
    pub l3: Option<u64>,
    pub governor: Option<String>,
    pub driver: Option<String>,
    pub virtualization: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Memory {
    pub total: u64,
    pub available: u64,
    pub free: u64,
    pub used: u64,
    pub cached: u64,
    pub buffers: u64,
    pub committed: u64,
    pub commit_limit: u64,
    pub swap_total: u64,
    pub swap_free: u64,
    pub zswapped: u64,
    pub zswap: u64,
    pub dirty: u64,
    pub shmem: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Gpu {
    pub id: String,
    pub name: String,
    pub vendor_id: u32,
    pub device_id: u32,
    pub usage: Option<f32>,
    pub mem_total: Option<u64>,
    pub mem_used: Option<u64>,
    pub shared_total: Option<u64>,
    pub shared_used: Option<u64>,
    pub temp: Option<f32>,
    pub power: Option<f32>,
    pub max_power: Option<f32>,
    pub clock: Option<u32>,
    pub max_clock: Option<u32>,
    pub mem_clock: Option<u32>,
    pub max_mem_clock: Option<u32>,
    pub encode: Option<f32>,
    pub decode: Option<f32>,
    pub pcie_gen: Option<u32>,
    pub pcie_lanes: Option<u32>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Process {
    pub pid: u32,
    pub parent: u32,
    pub name: String,
    /// Base names only, as the kernel and the command line give them: what the shell
    /// matches desktop entries against.
    pub exe: String,
    pub argv0: String,
    /// The command line, joined, cut to a tooltip's length.
    pub cmd: String,
    pub state: &'static str,
    /// Percent of the whole machine.
    pub cpu: f32,
    pub memory: u64,
    pub swap: u64,
    pub gpu: f32,
    pub gpu_memory: u64,
    pub threads: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct App {
    pub id: String,
    pub name: String,
    pub pids: Vec<u32>,
}

fn bad(what: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, format!("unexpected reply to {what}"))
}

fn call(client: &mut Client, what: &str, body: request::Body) -> io::Result<response::Body> {
    let bytes = client.request(&Request { body: Some(body) }.encode_to_vec())?;
    let response = Response::decode(bytes.as_slice()).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
    match response.body {
        Some(response::Body::Error(e)) => Err(io::Error::other(format!("{what}: {}", e.message))),
        Some(body) => Ok(body),
        None => Err(bad(what)),
    }
}

pub fn read(client: &mut Client) -> io::Result<Sample> {
    let cpu = read_cpu(client)?;
    let cores = cpu.cores.len().max(1) as f32;
    Ok(Sample {
        event: "sample",
        memory: read_memory(client)?,
        gpus: read_gpus(client)?,
        processes: read_processes(client, cores)?,
        apps: read_apps(client)?,
        cpu,
    })
}

fn read_cpu(client: &mut Client) -> io::Result<Cpu> {
    let response::Body::Cpu(cpu::CpuResponse { response: Some(cpu_response::Response::Cpu(c)) }) =
        call(client, "cpu", request::Body::GetCpu(cpu::CpuRequest {}))?
    else {
        return Err(bad("cpu"));
    };
    Ok(Cpu {
        name: c.name.unwrap_or_default(),
        usage: c.total_usage_percent,
        kernel: c.kernel_usage_percent,
        cores: c.core_usage_percent,
        freq_mhz: c.current_frequency_mhz,
        base_khz: c.base_freq_khz,
        temp: c.temperature_celsius,
        power: c.power_draw_w,
        processes: c.total_process_count,
        threads: c.total_thread_count,
        handles: c.total_handle_count,
        uptime: c.uptime_seconds,
        sockets: c.socket_count,
        l1: c.l1_combined_cache_bytes,
        l2: c.l2_cache_bytes,
        l3: c.l3_cache_bytes,
        governor: c.frequency_governor,
        driver: c.frequency_driver,
        virtualization: c.virtualization_technology,
    })
}

fn read_memory(client: &mut Client) -> io::Result<Memory> {
    let request = MemoryRequest { kind: memory_request::Kind::Memory as i32 };
    let response::Body::Memory(memory::MemoryResponse {
        response: Some(memory_response::Response::MemoryInfo(memory_response::MemoryInfo {
            response: Some(memory_info::Response::Memory(m)),
        })),
        ..
    }) = call(client, "memory", request::Body::GetMemory(request))?
    else {
        return Err(bad("memory"));
    };
    Ok(Memory {
        total: m.mem_total,
        available: m.mem_available,
        free: m.mem_free,
        used: m.mem_total.saturating_sub(m.mem_available),
        cached: m.cached,
        buffers: m.buffers,
        committed: m.committed,
        commit_limit: m.commit_limit,
        swap_total: m.swap_total,
        swap_free: m.swap_free,
        zswapped: m.zswapped,
        zswap: m.zswap,
        dirty: m.dirty,
        shmem: m.sh_mem,
    })
}

fn read_gpus(client: &mut Client) -> io::Result<Vec<Gpu>> {
    let response::Body::Gpus(gpus::GpusResponse { response: Some(gpus_response::Response::Gpus(map)) }) =
        call(client, "gpus", request::Body::GetGpus(gpus::GpusRequest {}))?
    else {
        return Err(bad("gpus"));
    };
    let mut gpus: Vec<Gpu> = map
        .gpus
        .into_values()
        .map(|g| Gpu {
            id: g.id,
            name: g.device_name.unwrap_or_default(),
            vendor_id: g.vendor_id,
            device_id: g.device_id,
            usage: g.utilization_percent,
            mem_total: g.total_memory,
            mem_used: g.used_memory,
            shared_total: g.total_shared_memory,
            shared_used: g.used_shared_memory,
            temp: g.temperature_c,
            power: g.power_draw_watts,
            max_power: g.max_power_draw_watts,
            clock: g.clock_speed_mhz,
            max_clock: g.max_clock_speed_mhz,
            mem_clock: g.memory_speed_mhz,
            max_mem_clock: g.max_memory_speed_mhz,
            encode: g.encoder_percent,
            decode: g.decoder_percent,
            pcie_gen: g.pcie_gen,
            pcie_lanes: g.pcie_lanes,
        })
        .collect();
    // The map's order is a hash's; the bus address is stable across ticks.
    gpus.sort_by(|a, b| a.id.cmp(&b.id));
    Ok(gpus)
}

fn base_name(path: &str) -> String {
    path.rsplit('/').next().unwrap_or(path).to_string()
}

/// What to call a process: its binary's name rather than the kernel's 15-character comm,
/// which on NixOS is a wrapper's (".ghostty-wrappe"). The wrapper's dressing comes off:
/// ".Discord-wrapped" is Discord.
fn display_name(exe: &str, argv0: &str, comm: &str) -> String {
    for candidate in [exe, argv0] {
        let name = candidate.strip_prefix('.').unwrap_or(candidate);
        let name = name.strip_suffix("-wrapped").unwrap_or(name);
        if !name.is_empty() && !name.contains(' ') {
            return name.to_string();
        }
    }
    comm.to_string()
}

fn state_name(state: i32) -> &'static str {
    match ProcessState::try_from(state).unwrap_or(ProcessState::Unknown) {
        ProcessState::Running => "running",
        ProcessState::Sleeping => "sleeping",
        ProcessState::SleepingUninterruptible => "waiting",
        ProcessState::Zombie => "zombie",
        ProcessState::Stopped => "stopped",
        ProcessState::Tracing => "traced",
        ProcessState::Dead => "dead",
        ProcessState::WakeKill => "waking",
        ProcessState::Waking => "waking",
        ProcessState::Parked => "parked",
        ProcessState::Unknown => "unknown",
    }
}

/// `cores` turns Magpie's per-core percentages into a share of the whole machine, the way
/// the CPU total and Task Manager count.
fn read_processes(client: &mut Client, cores: f32) -> io::Result<Vec<Process>> {
    let request = ProcessesRequest { request: Some(processes_request::Request::ProcessMap(Empty {})) };
    let response::Body::Processes(proc::ProcessesResponse {
        response: Some(processes_response::Response::Processes(map)),
    }) = call(client, "processes", request::Body::GetProcesses(request))?
    else {
        return Err(bad("processes"));
    };
    let mut processes: Vec<Process> = map
        .processes
        .into_values()
        .map(|p| {
            let mut cmd = p.cmd.join(" ");
            if cmd.len() > 240 {
                let mut cut = 240;
                while !cmd.is_char_boundary(cut) {
                    cut -= 1;
                }
                cmd.truncate(cut);
                cmd.push('…');
            }
            let stats = p.usage_stats;
            let exe = base_name(&p.exe);
            let argv0 = p.cmd.first().map(|a| base_name(a)).unwrap_or_default();
            Process {
                pid: p.pid,
                parent: p.parent,
                name: display_name(&exe, &argv0, &p.name),
                exe,
                argv0,
                cmd,
                state: state_name(p.state),
                cpu: stats.cpu_usage / cores,
                memory: stats.memory_usage,
                swap: stats.swap_usage,
                gpu: stats.gpu_usage,
                gpu_memory: stats.gpu_memory_usage,
                threads: p.task_count,
            }
        })
        .collect();
    processes.sort_by_key(|p| p.pid);
    Ok(processes)
}

fn read_apps(client: &mut Client) -> io::Result<Vec<App>> {
    let response::Body::Apps(apps::AppsResponse { response: Some(apps_response::Response::Apps(list)) }) =
        call(client, "apps", request::Body::GetApps(apps::AppsRequest {}))?
    else {
        return Err(bad("apps"));
    };
    Ok(list.apps.into_iter().map(|a| App { id: a.id, name: a.name, pids: a.pids }).collect())
}

/// SIGTERM to each pid, through the daemon like the rest.
pub fn terminate(client: &mut Client, pids: Vec<u32>) -> io::Result<()> {
    let request = ProcessesRequest { request: Some(processes_request::Request::Terminate(TerminateProcessesRequest { pids })) };
    call(client, "terminate", request::Body::GetProcesses(request)).map(|_| ())
}

/// SIGKILL to each pid.
pub fn kill(client: &mut Client, pids: Vec<u32>) -> io::Result<()> {
    let request = ProcessesRequest { request: Some(processes_request::Request::Kill(KillProcessesRequest { pids })) };
    call(client, "kill", request::Body::GetProcesses(request)).map(|_| ())
}
