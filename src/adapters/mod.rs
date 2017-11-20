use error::ConfigError;
use util::ConfigHashMap;

mod mysql;
mod pg;
mod sqlite;

pub trait Adapter {

}

pub fn get_adapter ( section: ConfigHashMap ) -> Result<Adapter,ConfigError> {

    let name = section.get(["module","adapter","type"])?;

    match name.to_lowercase() {
        "mysql"     => mysql::Mysql::new(section)?,
        "sqlite"    => sqlite::SQLite::new(section)?
        "pg"        => pg::PostgreSQL::new(section)?
        _           => Err(ConfigError::UnsupportedAdapter(name))
    }
}