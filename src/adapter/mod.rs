use error::ConfigError;
use util::ConfigHashMap;

mod mysql;
mod pg;
mod sqlite;

pub trait Adapter {
    fn close_all_filehandles(&mut self);
}

pub fn get_adapter ( section: ConfigHashMap ) -> Result<Box<Adapter>,ConfigError> {

    let name = section.get(["module","adapter","type"])?;

    match name.to_lowercase() {
        "mysql"     => Ok(Box::new(mysql::Mysql::new(section)?)),
        "sqlite"    => Ok(Box::new(sqlite::SQLite::new(section)?)),
        "pg"        => Ok(Box::new(pg::PostgreSQL::new(section)?)),
        _           => Err(ConfigError::UnsupportedAdapter(name)),
    }
}