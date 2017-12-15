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

#[derive(Debug)]
pub (crate) struct ConfigHashMap(HashMap<String,String>);

impl ConfigHashMap {
    pub fn new () -> Self {
        ConfigHashMap(HashMap::new())
    }
    pub fn get<T>(&self, keys: &'static [&'static str]) -> Result<T,ConfigError> 
        where T: FromStr {
        for key in keys {
            if let Some(s) = self.0.get(&key.to_string()) {
                return match s.parse() {
                    Ok(v)  => Ok(v),
                    Err(_e) => Err(ConfigError::ParseField(key))
                }
            }
        }

        Err(ConfigError::MissingField(keys))
    }
    pub fn get_opt<T>(&self, keys: &[&'static str]) -> Result<Option<T>,ConfigError> 
        where T: FromStr {
        for key in keys {
            if let Some(s) = self.0.get(&key.to_string()) {
                return match s.parse() {
                    Ok(v)  => Ok(Some(v)),
                    Err(_e) => Err(ConfigError::ParseField(key))
                }
            }
        }

        Ok(None)
    }

    pub fn len (&self) -> usize {
        self.0.len()
    }
    pub fn insert (&mut self, k: String, v: String) {
        self.0.insert(k,v);
    }
}