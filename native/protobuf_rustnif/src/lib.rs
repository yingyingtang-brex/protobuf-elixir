#[macro_use]
extern crate rustler;
#[macro_use]
extern crate rustler_codegen;
#[macro_use]
extern crate lazy_static;

mod decoder;

use decoder::Buffer;
use rustler::types::binary::Binary;
use rustler::{Encoder, Env, NifResult, Term};

mod atoms {
    rustler_atoms! {
        atom ok;
        //atom error;
        //atom __true__ = "true";
        //atom __false__ = "false";
    }
}

rustler_export_nifs! {
    "Elixir.Protobuf.RustNif",
    [("parse_bin", 2, parse_bin)],
    None
}

fn parse_bin<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    // let num1: i64 = args[0].decode()?;
    // let num2: i64 = args[1].decode()?;
    let binary: Binary = args[0].decode()?;
    let mut buffer = Buffer {
        buffer: binary.to_vec(),
        index: 0,
    };
    let key: u64 = buffer.decode_varint().unwrap();
    Ok((atoms::ok(), key).encode(env))
}
