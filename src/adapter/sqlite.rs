
use util::ConfigHashMap;
use error::ConfigError;
use adapter::Adapter;

enum SQLiteConnMethod{
    File{
        filename: String
    },
}
impl SQLiteConnMethod {
    fn new (section: &ConfigHashMap) -> Result<Self,ConfigError> {
        
        let mut filename   : String = section.get(&["dbfile"])?;

        Ok(SQLiteConnMethod::File{filename});
        
    }
}

pub struct SQLite {
    method:      SQLiteConnMethod,
}

impl SQLite {
    pub fn new (section: &ConfigHashMap) -> Result<SQLite,ConfigError>{
        SQLite {
		    method: SQLiteConnMethod::new(&section)?
        }
    }
}

impl Adapter for SQLite {
    fn close_all_filehandles(&mut self){
        unimplemented!()
    }

    //     sub getSequenceValue{
    //       my $self = shift;
    //       my $call = shift;

    //       my ($insert_id)  = $self->{dbh}->func('last_insert_rowid');
    //       return $insert_id;

    // }

    // sub can_lock { 0 }
}