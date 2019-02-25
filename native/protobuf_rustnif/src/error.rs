#[derive(Debug)]
pub enum Error {
    // Varint decoding error
    Varint,
}

pub type Result<T> = ::std::result::Result<T, Error>;
