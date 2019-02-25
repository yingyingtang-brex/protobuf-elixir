#[macro_use]
extern crate rustler;
#[macro_use]
extern crate rustler_codegen;
#[macro_use]
extern crate lazy_static;

mod decoder;
mod error;
mod wire;

use rustler::types::binary::Binary;
use rustler::{Encoder, Env, NifResult, Term};

use rustler::schedule::SchedulerFlags;

mod atoms {
    rustler_atoms! {
        atom ok;
        atom error;
        //atom __true__ = "true";
        //atom __false__ = "false";
    }
}

rustler_export_nifs! {
    "Elixir.Protobuf.RustNif",
    [("parse_bin", 2, parse_bin, SchedulerFlags::Normal)],
    None
}

fn parse_bin<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    // let num1: i64 = args[0].decode()?;
    // let num2: i64 = args[1].decode()?;
    let binary: Binary = args[0].decode()?;
    // let result = decoder::decode_varint(binary.as_slice());
    let result = decoder::unmarshal(&mut binary.as_slice());
    // let mut buf = decoder::Buffer {
    //     buf: &binary.as_slice(),
    //     idx: 0,
    //     len: binary.len(),
    // };
    // let result = buf.unmarshal();

    // match result {
    //     Ok(list) => {
    //         let result = list.into_iter();
    //         let result = result.map(|x| x.encode(env));
    //         let result: Vec<_> = result.collect();
    //         Ok(result.encode(env))
    //     }
    //     Err(_) => Ok((atoms::error()).encode(env)),
    // }
    Ok((atoms::ok()).encode(env))
}
