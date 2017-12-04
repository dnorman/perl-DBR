use std::ops::Deref;
use core::str::ParseBoolError;
use std::str::FromStr;

// Silly newtype necessary for perl truthiness parsing
#[derive(Debug)]
pub struct PerlyBool (bool);

impl Deref for PerlyBool {
    type Target = bool;

    fn deref(&self) -> &bool {
        &self.0
    }
}

impl FromStr for PerlyBool {
    type Err = ParseBoolError;
    fn from_str(s: &str) -> Result<Self, ParseBoolError> {
        match s {
            "" | "0" => Ok(PerlyBool(false)),
            _  => Ok(PerlyBool(true)),
        }
    }
}