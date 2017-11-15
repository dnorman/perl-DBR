use std::io;

pub enum ConfigError{
    FileAlreadyLoaded,
    FileIo(std::io::Error),
    MissingField(&'const str)
}


impl From<io::Error> for ConfigError {
    fn from(error: io::Error) -> Self {
        ConfigError::FileIo(error)
    }
}