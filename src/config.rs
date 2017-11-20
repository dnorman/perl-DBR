use std::io::{self, BufReader};
use std::io::prelude::*;
use std::fs::File;
use regex::Regex;
use std::mem;

use util::PerlyBool;

use crate::Session;
use adapter::Adapter;

pub struct Config {
    instances: Vec<Instance>,
    loaded_files: Vec<String>
}

pub struct Schema {
    
}

pub struct Instance {
    adapter:    Adapter,
    handle      String,
    tag         Option<String>,
    class:      String,
    instance_id Option<usize>,
    schema_id   Option<usize>,
    allowquery: PerlyBool,
    readonly:    PerlyBool,
    dbr_bootstrap: PerlyBool
};

pub (crate) struct ConfigHashMap(pub HashMap<String,String>);

impl ConfigHashMap {
    fn new () -> Self {
        ConfigHashMap(HashMap::new())
    }
    fn get<T>(&self, keys: &[&str]) -> Result<T,ConfigError> 
        where T: std::str::FromStr {
        for key in keys {
            if let Some(s) = self.hm.get(key) {
                return match s.parse() {
                    Ok(v)  => Ok(Some(v)),
                    Err(_e) => Err(ConfigError::ParseField(key.to_string()))
                }
            }
        }

        Err(ConfigError::MissingField(keys[0]))
    }
    fn get_opt<T>(&self, keys: &[&str]) -> Result<Option<T>,ConfigError> 
        where T: std::str::FromStr {
        for key in keys {
            if let Some(s) = self.hm.get(key) {
                return match s.parse() {
                    Ok(v)  => Ok(Some(v)),
                    Err(_e) => Err(ConfigError::ParseField(key.to_string()))
                }
            }
        }

        Ok(None)
    }
}

impl Config {
    pub fn new -> Self {
        Config::default()
    }
    pub fn load_file(context: &mut Context, filename: String ) -> Result<_,ConfigError> {

        if self.loaded_files.contains(filename) {
            return Err(ConfigLoadError::FileAlreadyLoaded);
        }

        let f = File::open(filename)?;
        let mut buf_reader = BufReader::new(file);

        let mut section = ConfigHashMap::new();
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
                if section.0.len(){
                    self.process_section( mem::replace(section,ConfigHashMap::new())?;
                }
                continue;
            }

            for part in line.split(&re_fdelim){
                if let Some(caps) = re_kv.captures(part){
                    let key = caps.get(0).unwrap();
                    let val = caps.get(1).unwrap();
                    fields.0.insert(key,val);
                }
            }
            if 
        }

        if section.0.len(){
            self.process_section( section )?;
        }

        Ok()
    }

    fn process_section(&mut self, mut section: ConfigHashMap) -> Result<(),ConfigError>{

       let adapter = adapter::get_adapter( section )?

            handle:        section.get(["handle","name"])?,
		    tag:           section.get_opt(["tag"])?,
		    class          section.get_opt(["class"]),
		    instance_id:   section.get_opt(["instance_id"])?,
		    schema_id:     section.get_opt(["schema_id"])?,
		    allowquery:    section.get_opt(["allowquery"])?,
		    readonly:      section.get_opt(["readonly"])?,
            dbr_bootstrap: section.get_opt(["dbr_bootstrap"])?,


 

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

        self.instances.push(instance.clone());

        if instance.dbr_bootstrap {
            
        }
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