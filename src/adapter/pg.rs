
use util::ConfigHashMap;
use error::ConfigError;
use adapter::Adapter;

enum PgConnMethod{
    HostName{
        hostname: String,
        database: String
    },
}
impl PgConnMethod {
    fn new (section: &ConfigHashMap) -> Result<Self,ConfigError> {
        Ok(PgConnMethod::HostName{
            hostname: section.get(&["hostname","host"])?,
            database: section.get(&["database","dbname"])?,
        })
    }
    fn connectstring(&self) -> String {
        use self::PgConnMethod::*;
        match self {
            &HostName{ref hostname,ref database}   => format!("dbi:Pg:dbname={};host={}", database, hostname )
        }
    }
}

pub struct PostgreSQL {
    method:      PgConnMethod,
    database:    String,
    user:        String,
    password:    String,
}

impl PostgreSQL {
    pub fn new (section: &ConfigHashMap) -> Result<PostgreSQL,ConfigError>{
        PostgreSQL {
		    method:        PgConnMethod::new(&section)?,
            database:      section.get(&["database","dbname"])?,
		    user:          section.get(&["username","user"])?,
		    password:      section.get(&["password"])?,
        }
    }
}

impl Adapter for PostgreSQL {
    fn close_all_filehandles(&mut self){
        unimplemented!()
    }


    // sub getSequenceValue{
    //     my $self = shift;
    //     my $call = shift;

    //     my ($last_id)  = $self->{dbh}->selectrow_array('select lastval()');
    //     return $last_id;

    // }
}