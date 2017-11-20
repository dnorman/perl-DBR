use crate::error::ConfigError;

enum MysqlConnMethod{
    HostName(String),
    SocketFile(String)
}
impl MysqlConnMethod {
    fn new (section: &ConfigHashMap) -> Result<Self,ConfigError> {

        let re_mysqluds  = Regex::new(r"^/").unwrap();
        
        let mut hostname   : Option<String> = section.get_opt(["hostname","host"])?;
        let mut socketfile : Option<String> = section.get_opt(["dbfile","socket"])?;

        match (hostname,socketfile){
            (Some(h),_) => {
                if re_mysqluds.is_match(h) {
                    MysqlConnMethod::SocketFile(h.clone());
                }else{
                    MysqlConnMethod::HostName(h.clone());
                }
            },
            (None,Some(s)) => {
                MysqlConnMethod::SocketFile(h.clone());
            },
            _ => {
                ConfigError::MissingField(["hostname","dbfile"]);
            }
        }
    },
    fn connectstring(&self) -> String {
        match self {
            HostName(h)   => format!("dbi:mysql:host={};mysql_enable_utf8=1", h ),
            SocketFile(s) => format!("dbi:mysql:mysql_socket={};mysql_enable_utf8=1", h )
        }
    }
}

pub struct Mysql {
    method      MysqlConnMethod,
    database    String,
    user        String,
    password    String
}

impl Mysql {
    pub fn new () -> Result<Mysql,ConfigError>{
        Mysql {
		    method:        MysqlConnMethod::new(&section)?
            database:      section.get(["database","dbname"])?
		    user:          section.get(["username","user"])?,
		    password:      section.get(["password"])?,
        }
    }
}

impl Adapter for Mysql {
    fn connect {
        //IMPORTANT: mysql_enable_utf8
    }

    // sub getSequenceValue{
    //     my $self = shift;
    //     my $call = shift;

    //     my ($insert_id)  = $self->{dbh}->selectrow_array('select last_insert_id()');
    //     return $insert_id;

    // }

    // sub can_trust_execute_rowcount{ 1 } # NOTE: This should be variable when mysql_use_result is implemented

    // sub qualify_table {
    //     my $self = shift;
    //     my $inst = shift;
    //     my $table = shift;

    //     return $self->quote_identifier($inst->database) . '.' . $self->quote_identifier($table);
    // }

    // sub quote {
    //     my $self = shift;

    //     # MEGA HACK: the MySQL driver, with ;mysql_enable_utf8=1, doesn't like strings
    //     # *unless* they are *internally* coded in UTF8.  So we need to disable Perl's
    //     # ISO-8859-only optimization here

    //     ("\x{100}" x 0) . $self->{dbh}->quote(@_);
    // }
}
