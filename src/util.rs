use std::ops::Deref;
use core;
use core::str::ParseBoolError;
use std::str::FromStr;
use std::collections::HashMap;

use error::ConfigError;

// Silly newtype necessary for perl truthiness parsing
#[derive(Debug, Clone)]
pub struct PerlyBool (pub bool);

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

impl core::convert::From<bool> for PerlyBool{
    fn from(v: bool) -> Self {
        PerlyBool(v)
    }
}

pub (crate) struct ConfigHashMap(pub HashMap<String,String>);

impl ConfigHashMap {
    pub fn new () -> Self {
        ConfigHashMap(HashMap::new())
    }
    pub fn get<T>(&self, keys: &[&str]) -> Result<T,ConfigError> 
        where T: FromStr {
        for key in keys {
            if let Some(s) = self.hm.get(key) {
                return match s.parse() {
                    Ok(v)  => Ok(Some(v)),
                    Err(_e) => Err(ConfigError::ParseField(key.to_string()))
                }
            }
        }

        Err(ConfigError::MissingField(keys[0]))
    }
    pub fn get_opt<T>(&self, keys: &[&str]) -> Result<Option<T>,ConfigError> 
        where T: FromStr {
        for key in keys {
            if let Some(s) = self.hm.get(key) {
                return match s.parse() {
                    Ok(v)  => Ok(Some(v)),
                    Err(_e) => Err(ConfigError::ParseField(key.to_string()))
                }
            }
        }

        Ok(None)
    }
}