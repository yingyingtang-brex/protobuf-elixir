use rustler::types::binary::OwnedBinary;
use rustler::{Encoder, Env, Term};
use std::io::Write;

pub const WIRE_TYPE_VARINT: u8 = 0;
pub const WIRE_TYPE_64BITS: u8 = 1;
pub const WIRE_TYPE_LENGTH_DELIMITED: u8 = 2;
// pub const WIRE_TYPE_START_GROUP: u8 = 3;
// pub const WIRE_TYPE_END_GROUP: u8 = 4;
pub const WIRE_TYPE_32BITS: u8 = 5;

// impl<'a, T> Encoder for &[u8] {
//     fn encode<'b>(&self, env: Env<'b>) -> Term<'b> {
//         let term_array: Vec<::wrapper::nif_interface::NIF_TERM> =
//             self.iter().map(|x| x.encode(env).as_c_arg()).collect();
//         unsafe { Term::new(env, list::make_list(env.as_c_arg(), &term_array)) }
//     }
// }

pub struct Binary {
    pub bin: Vec<u8>,
}

impl Encoder for Binary {
    fn encode<'b>(&self, env: Env<'b>) -> Term<'b> {
        let mut binary = OwnedBinary::new(self.bin.len()).unwrap();
        binary.as_mut_slice().write(self.bin.as_slice()).unwrap();
        binary.release(env).encode(env)
    }
}
