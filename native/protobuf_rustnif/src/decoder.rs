use error::{Error, Result};
// use rustler::types::binary::Binary;
use rustler::types::binary::OwnedBinary;
use rustler::{Encoder, Env};
use std::io::Write;
use std::rc::Rc;
use wire::*;

pub fn unmarshal<'a>(buf: &mut &'a [u8]) -> Result<Vec<Box<Encoder>>> {
    let mut result: Vec<Box<Encoder>> = vec![];
    loop {
        if buf.len() == 0 {
            break;
        }

        let (x, n) = decode_varint(buf);
        if n == 0 {
            return Err(Error::Varint);
        }
        *buf = &buf[n..];

        let tag = x >> 3;
        let wire = (x as u8) & 7;
        result.push(Box::new(tag));
        result.push(Box::new(wire));

        match wire {
            WIRE_TYPE_VARINT => {
                let (x, n) = decode_varint(buf);
                if n == 0 {
                    return Err(Error::Varint);
                }
                *buf = &buf[n..];
                result.push(Box::new(x))
            }
            WIRE_TYPE_64BITS => {
                let mut bin = Binary { bin: vec![0; 8] };
                bin.bin.clone_from_slice(&buf[..8]);
                *buf = &buf[8..];
                result.push(Box::new(bin))
            }
            WIRE_TYPE_32BITS => {
                let mut bin = Binary { bin: vec![0; 4] };
                bin.bin.clone_from_slice(&buf[..4]);
                *buf = &buf[4..];
                result.push(Box::new(bin))
            }
            WIRE_TYPE_LENGTH_DELIMITED => {
                let (x, n) = decode_varint(buf);
                if n == 0 {
                    return Err(Error::Varint);
                }
                *buf = &buf[n..];

                let x = x as usize;
                if x > buf.len() {
                    return Err(Error::Varint);
                }

                let mut bin = Binary { bin: vec![0; x] };
                bin.bin.clone_from_slice(&buf[..x]);
                *buf = &buf[x..];
                result.push(Box::new(bin))
            }
            _ => continue,
        };
    }
    return Ok(result);
}

pub struct Buffer<'a> {
    pub buf: &'a [u8],
    pub idx: usize,
    pub len: usize,
}

impl<'a> Buffer<'a> {
    pub fn unmarshal<'b>(&mut self, env: Env<'b>) -> Result<Vec<Rc<Encoder>>> {
        let mut result: Vec<Rc<Encoder>> = vec![];
        let len = self.len;
        loop {
            if self.idx >= len {
                break;
            }

            let vari = self.decode_varint();
            let x = match vari {
                Ok(x) => x,
                Err(e) => {
                    return Err(Error::Varint);
                }
            };

            let tag = x >> 3;
            let wire = (x as u8) & 7;
            result.push(Rc::new(tag));
            result.push(Rc::new(wire));

            match wire {
                WIRE_TYPE_VARINT => {
                    let vari = self.decode_varint();
                    let x = match vari {
                        Ok(x) => x,
                        Err(e) => {
                            return Err(Error::Varint);
                        }
                    };
                    result.push(Rc::new(x));
                }
                WIRE_TYPE_64BITS => {
                    // let mut bin = Binary { bin: vec![0; 8] };
                    let mut bin = OwnedBinary::new(8).unwrap();
                    let i = self.idx;
                    bin.as_mut_slice().write(&self.buf[i..i + 8]).unwrap();
                    // bin.bin.clone_from_slice(&self.buf[i..i + 8]);
                    self.idx = i + 8;
                    result.push(Rc::new(bin.release(env)));
                }
                WIRE_TYPE_32BITS => {
                    let bin = OwnedBinary::new(8).unwrap();
                    let i = self.idx;
                    bin.as_mut_slice().write(&self.buf[i..i + 4]).unwrap();
                    self.idx = i + 4;
                    result.push(Rc::new(bin.release(env)));
                }
                WIRE_TYPE_LENGTH_DELIMITED => {
                    let vari = self.decode_varint();
                    let x = match vari {
                        Ok(x) => x,
                        Err(e) => {
                            return Err(Error::Varint);
                        }
                    };

                    let i = self.idx;
                    let x = x as usize;
                    if x > (self.len - i) {
                        return Err(Error::Varint);
                    }

                    let bin = OwnedBinary::new(x).unwrap();
                    bin.as_mut_slice().write(&self.buf[i..i + x]).unwrap();
                    self.idx = i + x;
                    result.push(Rc::new(bin.release(env)));
                }
                _ => continue,
            };
        }
        return Ok(result);
    }

    pub fn decode_varint(&mut self) -> Result<u64> {
        let mut i = self.idx;
        let buf = self.buf;
        let len = self.len;
        let mut b: u64;
        let mut v: u64;

        // 1st byte
        if i >= len {
            return Err(Error::Varint);
        }
        v = buf[i] as u64;
        i += 1;
        if v < 0x80 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80;

        // 2nd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 7;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 7;

        // 3rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 14;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 14;

        // 4rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 21;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 21;

        // 5rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 28;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 28;

        // 6rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 35;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 35;

        // 7rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 42;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 42;

        // 8rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 49;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 49;

        // 9rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 56;
        if b & 0x80 == 0 {
            self.idx = i;
            return Ok(v);
        }
        v -= 0x80 << 56;

        // 10rd byte
        if i >= len {
            return Err(Error::Varint);
        }
        b = buf[i] as u64;
        i += 1;
        v += b << 63;
        if b < 2 {
            self.idx = i;
            return Ok(v);
        }

        return Err(Error::Varint);
    }
}

pub fn decode_varint(buf: &[u8]) -> (u64, usize) {
    let mut b: u64;
    let mut v: u64;

    // 1st byte
    if buf.len() == 0 {
        return (0, 0);
    }
    v = buf[0] as u64;
    if v < 0x80 {
        return (v, 1);
    }
    v -= 0x80;

    // 2nd byte
    if buf.len() <= 1 {
        return (0, 0);
    }
    b = buf[1] as u64;
    v += b << 7;
    if b & 0x80 == 0 {
        return (v, 2);
    }
    v -= 0x80 << 7;

    // 3rd byte
    if buf.len() <= 2 {
        return (0, 0);
    }
    b = buf[2] as u64;
    v += b << 14;
    if b & 0x80 == 0 {
        return (v, 3);
    }
    v -= 0x80 << 14;

    // 4rd byte
    if buf.len() <= 3 {
        return (0, 0);
    }
    b = buf[3] as u64;
    v += b << 21;
    if b & 0x80 == 0 {
        return (v, 4);
    }
    v -= 0x80 << 21;

    // 5rd byte
    if buf.len() <= 4 {
        return (0, 0);
    }
    b = buf[4] as u64;
    v += b << 28;
    if b & 0x80 == 0 {
        return (v, 5);
    }
    v -= 0x80 << 28;

    // 6rd byte
    if buf.len() <= 5 {
        return (0, 0);
    }
    b = buf[5] as u64;
    v += b << 35;
    if b & 0x80 == 0 {
        return (v, 6);
    }
    v -= 0x80 << 35;

    // 7rd byte
    if buf.len() <= 6 {
        return (0, 0);
    }
    b = buf[6] as u64;
    v += b << 42;
    if b & 0x80 == 0 {
        return (v, 7);
    }
    v -= 0x80 << 42;

    // 8rd byte
    if buf.len() <= 7 {
        return (0, 0);
    }
    b = buf[7] as u64;
    v += b << 49;
    if b & 0x80 == 0 {
        return (v, 8);
    }
    v -= 0x80 << 49;

    // 9rd byte
    if buf.len() <= 8 {
        return (0, 0);
    }
    b = buf[8] as u64;
    v += b << 56;
    if b & 0x80 == 0 {
        return (v, 9);
    }
    v -= 0x80 << 56;

    // 10rd byte
    if buf.len() <= 9 {
        return (0, 0);
    }
    b = buf[9] as u64;
    v += b << 63;
    if b < 2 {
        return (v, 10);
    }

    return (0, 0);
}

// fn decode_64bits(buf: &[u8]) -> ([u8], usize) {}
