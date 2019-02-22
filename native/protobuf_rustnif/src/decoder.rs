use std::io;

#[derive(Debug, Clone, PartialEq)]
pub struct Buffer {
    pub buffer: Vec<u8>,
    pub index: usize,
}

impl Buffer {
    pub fn decode_varint(&mut self) -> Result<u64, io::Error> {
        let i = self.index;
        let buf = &self.buffer;
        if i >= buf.len() {
        } else if buf[i] < 0x80 {
            self.index += 1;
            return Ok(buf[i] as u64);
        }
        Err(io::Error::new(io::ErrorKind::Other, "wrong index"))
    }
}
