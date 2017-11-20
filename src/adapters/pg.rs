use crate::error::ConfigError;

enum PgConnMethod{
    HostName{
        hostname: String,
        database: String
    },
}
impl PgConnMethod {
    fn new (section: &ConfigHashMap) -> Result<Self,ConfigError> {
        MysqlConnMethod::HostName{
            hostname: section.get(["hostname","host"])?,
            database: section.get(["database","dbname"])?
        }
    },
    fn connectstring(&self) -> String {
        match self {
            HostName{hostname,database})   => format!("dbi:Pg:dbname={};host={}", database, hostname )
        }
    }
}

pub struct PostgreSQL {
    method      MysqlConnMethod,
    database    String,
    user        String,
    password    String
}

impl PostgreSQL {
    pub fn new () -> Result<PostgreSQL,ConfigError>{
        PostgreSQL {
		    method:        PgConnMethod::new(&section)?
            database:      section.get(["database","dbname"])?
		    user:          section.get(["username","user"])?,
		    password:      section.get(["password"])?,
        }
    }
}

impl Adapter for PostgreSQL {
    fn connect {}


    // sub getSequenceValue{
    //     my $self = shift;
    //     my $call = shift;

    //     my ($last_id)  = $self->{dbh}->selectrow_array('select lastval()');
    //     return $last_id;

    // }
}