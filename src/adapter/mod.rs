use std::sync::{Arc,Mutex};

use error::ConfigError;
use util::ConfigHashMap;

mod mysql;
mod pg;
mod sqlite;

pub trait Adapter {
    fn close_all_filehandles(&mut self);
}

pub  (crate) fn get_adapter ( section: &ConfigHashMap ) -> Result<Arc<Mutex<Adapter>>,ConfigError> {

    let name : String = section.get(&["module","adapter","type"])?;

    match &*name.to_lowercase() {
        "mysql"     => Ok(Arc::new(Mutex::new(mysql::Mysql::new(section)?))),
        "sqlite"    => Ok(Arc::new(Mutex::new(sqlite::SQLite::new(section)?))),
        "pg"        => Ok(Arc::new(Mutex::new(pg::PostgreSQL::new(section)?))),
        _           => Err(ConfigError::UnsupportedAdapter(name)),
    }
}