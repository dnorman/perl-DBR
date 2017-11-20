use crate::error::ConfigError;

enum SQLiteConnMethod{
    File{
        filename: String
    },
}
impl PgConnMethod {
    fn new (section: &ConfigHashMap) -> Result<Self,ConfigError> {
        
        let mut filename   : String = section.get(["dbfile"])?;

        SQLiteConnMethod::File{hostname, database};
        
    },

}

pub struct PostgreSQL {
    method      MysqlConnMethod,
    database    String,
    user        String,
    password    String
}

impl SQLite {
    pub fn new () -> Result<PostgreSQL,ConfigError>{
        Sqlite {
		    method:        SQLiteConnMethod::new(&section)?
        }
    }
}

impl Adapter for SQLite {
    fn connect {}

    //     sub getSequenceValue{
    //       my $self = shift;
    //       my $call = shift;

    //       my ($insert_id)  = $self->{dbh}->func('last_insert_rowid');
    //       return $insert_id;

    // }

    // sub can_lock { 0 }
}