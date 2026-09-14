//! The client side of Magpie's socket: nng's REQ/REP pair over its IPC transport, done by
//! hand so the daemon's protobuf is the only thing shared with it. Enough of the wire for
//! one request at a time from one connection; nothing of nng's retries or its backtrace.
//!
//! On connect each side sends `0 'S' 'P' 0 <protocol u16 BE> 0 0`, REQ0 being 0x30 and
//! REP0 0x31. Every frame after that is a type byte (1 = data), a u64 BE length and the
//! body; REQ0 puts a u32 BE request id with its high bit set in front of the payload and
//! REP0 echoes it back in front of the reply.

use std::io::{self, ErrorKind, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::Path;
use std::time::Duration;

const REQ0: u16 = 0x30;
const REP0: u16 = 0x31;

pub struct Client {
    stream: UnixStream,
    next_id: u32,
}

impl Client {
    pub fn connect(path: &Path) -> io::Result<Self> {
        let mut stream = UnixStream::connect(path)?;
        stream.set_read_timeout(Some(Duration::from_secs(15)))?;
        stream.set_write_timeout(Some(Duration::from_secs(5)))?;
        stream.write_all(&[0, b'S', b'P', 0, (REQ0 >> 8) as u8, REQ0 as u8, 0, 0])?;
        let mut greeting = [0u8; 8];
        stream.read_exact(&mut greeting)?;
        let protocol = u16::from_be_bytes([greeting[4], greeting[5]]);
        if greeting[..4] != [0, b'S', b'P', 0] || protocol != REP0 {
            return Err(io::Error::new(ErrorKind::InvalidData, format!("not a REP0 peer: {greeting:02x?}")));
        }
        Ok(Client { stream, next_id: 1 })
    }

    /// Sends one payload and returns the reply's, without the request id.
    pub fn request(&mut self, payload: &[u8]) -> io::Result<Vec<u8>> {
        let id = self.next_id | 0x8000_0000;
        self.next_id = if self.next_id == 0x7fff_ffff { 1 } else { self.next_id + 1 };

        let mut frame = Vec::with_capacity(9 + 4 + payload.len());
        frame.push(1);
        frame.extend_from_slice(&((4 + payload.len()) as u64).to_be_bytes());
        frame.extend_from_slice(&id.to_be_bytes());
        frame.extend_from_slice(payload);
        self.stream.write_all(&frame)?;

        let mut head = [0u8; 9];
        self.stream.read_exact(&mut head)?;
        if head[0] != 1 {
            return Err(io::Error::new(ErrorKind::InvalidData, format!("frame type {}", head[0])));
        }
        let len = u64::from_be_bytes(head[1..].try_into().unwrap());
        if len < 4 || len > 256 * 1024 * 1024 {
            return Err(io::Error::new(ErrorKind::InvalidData, format!("frame of {len} bytes")));
        }
        let mut body = vec![0u8; len as usize];
        self.stream.read_exact(&mut body)?;
        let echoed = u32::from_be_bytes(body[..4].try_into().unwrap());
        if echoed != id {
            return Err(io::Error::new(ErrorKind::InvalidData, format!("reply to {echoed:#x}, wanted {id:#x}")));
        }
        body.drain(..4);
        Ok(body)
    }
}
