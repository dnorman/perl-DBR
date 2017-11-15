use std::io::{self, BufReader};
use std::io::prelude::*;
use std::fs::File;
use regex::Regex;

use crate::Session;

pub struct Config {
    instances: Vec<Instance>,
    loaded_files: Vec<String>
}

pub struct Schema {
    
}

pub struct Instance {
    handle      String,
    module      String,
    database    Option<String>,
    hostname    Option<String>,
    user        Option<String>,
    dbfile      Option<String>,
    tag         Option<String>,
    password    String,
    class:      String,
    instance_id Option<usize>,
    schema_id   Option<usize>,
    allowquery: bool,
    readonly    bool
};

      $config->{connectstring} = $connectstrings{$config->{module}} || return $self->_error("module '$config->{module}' is not a supported database type");
      if ($config->{module} eq 'Mysql' && $config->{hostname} =~ m|^/|) {
	    $config->{connectstring} = $connectstrings{Mysql_UDS};
      }

      my $connclass = 'DBR::Misc::Connection::' . $config->{module};
      return $self->_error("Failed to Load $connclass ($@)") unless eval "require $connclass";

      $config->{connclass} = $connclass;

      my $reqfields = $connclass->required_config_fields or return $self->_error('Failed to determine required config fields');

      foreach my $name (@$reqfields){
	    return $self->_error( $name . ' parameter is required' ) unless $config->{$name};
      }

      $config->{dbr_bootstrap} = $spec->{dbr_bootstrap}? 1:0;

      foreach my $key (keys %{$config}) {
	    $config->{connectstring} =~ s/-$key-/$config->{$key}/;
      }

}


impl Config {
    pub fn new -> Self {
        Config::default()
    }
    pub fn load_file(context: &mut Context, filename: String ) -> Result<(),ConfigError> {

        if self.loaded_files.contains(filename) {
            return Err(ConfigLoadError::FileAlreadyLoaded);
        }

        let f = File::open(filename)?;
        let mut buf_reader = BufReader::new(file);

        let mut fields = Some(HashMap::new());
        let mut sections = Vec::new();

        // Strip comments, leading and traling whitespace
        let re_strip   = Regex::new(r"(\#.*$|^\s*|\s*$)").unwrap();
        let re_fdelim  = Regex::new(r"/\s*\;\s*/").unwrap();
        let re_section = Regex::new(r"^---").unwrap();
        let re_kv      = Regex::new(r"^(.+?)\s*=\s*(.+)$").unwrap();

        for line in buf_reader.lines() {
            let line = re_strip.replace_all(line?, "");

            if line.len() == 0 {
                continue;
            }

            if re_section.is_match(part) {
                if fields.len(){
                    sections.push(fields.take());
                    fields = Some(HashMap::new());
                }
                continue;
            }

            for part in line.split(&re_fdelim){
                if let Some(caps) = re_kv.captures(part){
                    let key = caps.get(0).unwrap();
                    let val = caps.get(1).unwrap();
                    fields.insert(key,val);
                }
            }
        }
        
        let mut handle = fields.get("handle");
        if let None = handle {
            handle = fields.get("name");
        }
        let mut module = fields.get("module");
        if let None = module {
            module = fields.get("type");
        }

        let instance = Instance{
            handle:     handle.ok_or(ConfigError::MissingField("handle"))?,
		    module:     handle.ok_or(ConfigError::MissingField("module"))?,
		    database:   $spec->{dbname}   || $spec->{database},
		    hostname:   $spec->{hostname} || $spec->{host},
		    user:       $spec->{username} || $spec->{user},
		    dbfile:     $spec->{dbfile},
		    tag:        $spec->{tag} || '',
		    password    => $spec->{password},
		    class       => $spec->{class}       || 'master', # default to master
		    instance_id => $spec->{instance_id} || '',
		    schema_id   => $spec->{schema_id}   || '',
		    allowquery  => $spec->{allowquery}  || 0,
		    readonly    => $spec->{readonly}    || 0,
        }

        self.instances.push(instance);

    //     my $count;
    //     foreach my $instspec (@conf){
    //         $count++;

    //         my $instance = DBR::Config::Instance->register(
    //                             dbr    => $dbr,
    //                             session => $self->{session},
    //                             spec   => $instspec
    //                             ) or $self->_error("failed to load DBR conf file '$file' (stanza #$count)") && next;
    //         if($instance->dbr_bootstrap){
    //         #don't bail out here on error
    //         $self->load_dbconf(
    //                     dbr      => $dbr,
    //                     instance => $instance
    //                     ) || $self->_error("failed to load DBR config tables") && next;
    //         }
    //     }

        self.loaded_files.push(filename);
        Ok()

    }

    // sub load_dbconf{
    //     my $self  = shift;
    //     my %params = @_;



    //     my $dbr         = $params{'dbr'}      or return $self->_error( 'dbr parameter is required'    );
    //     my $parent_inst = $params{'instance'} or return $self->_error( 'instance parameter is required' );



    //     $self->_error("failed to create instance handles") unless
    //     my $instances = DBR::Config::Instance->load_from_db(
    //                                 session   => $self->{session},
    //                                 dbr      => $dbr,
    //                                 parent_inst => $parent_inst
    //                             );

    //     my %schema_ids;
    //     map {$schema_ids{ $_->schema_id } = 1 } @$instances;

    //     if(%schema_ids){
    //         $self->_error("failed to create schema handles") unless
    //         my $schemas = DBR::Config::Schema->load(
    //                             session    => $self->{session},
    //                             schema_id => [keys %schema_ids],
    //                             instance  => $parent_inst,
    //                             );
    //     }

    //     return 1;
    // }

}