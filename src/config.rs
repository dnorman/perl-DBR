use std::io::BufReader;
use std::io::prelude::*;
use std::fs::File;
use regex::Regex;
use std::mem;
use std::sync::Arc;

use util::PerlyBool;
use adapter::{self,Adapter};
use error::ConfigError;
use util::ConfigHashMap;

#[derive(Default)]
pub struct Config {
    instances: Vec<Instance>,
    loaded_files: Vec<String>
}

pub struct Schema {
}

#[derive(Clone)]
pub struct Instance {
    // TODO: Adapter should probably not be an Arc
    adapter:       Box<Arc<Adapter>>,
    handle:        String,
    tag:           Option<String>,
    class:         String,
    instance_id:   Option<usize>,
    schema_id:     Option<usize>,
    allowquery:    PerlyBool,
    readonly:      PerlyBool,
}

impl Config {
    pub fn new() -> Self {
        Config::default()
    }
    pub fn load_file(&mut self, filename: &String ) -> Result<(),ConfigError> {

        if self.loaded_files.contains(filename) {
            return Err(ConfigError::FileAlreadyLoaded);
        }

        let f = File::open(filename)?;
        let mut buf_reader = BufReader::new(f);

        let mut section = ConfigHashMap::new();

        // Strip comments, leading and traling whitespace
        let re_strip   = Regex::new(r"(\#.*$|^\s*|\s*$)").unwrap();
        let re_fdelim  = Regex::new(r"/\s*\;\s*/").unwrap();
        let re_section = Regex::new(r"^---").unwrap();
        let re_kv      = Regex::new(r"^(.+?)\s*=\s*(.+)$").unwrap();

        for line in buf_reader.lines() {
            let line = re_strip.replace_all(&line?, "");

            if line.len() == 0 {
                continue;
            }

            if re_section.is_match(&line) {
                if section.0.len() > 0 {
                    self.process_section( mem::replace(&mut section,ConfigHashMap::new()) );
                }
                continue;
            }

            for part in re_fdelim.split(&line){
                if let Some(caps) = re_kv.captures(part){
                    let key = caps.get(0).unwrap();
                    let val = caps.get(1).unwrap();
                    section.0.insert(key.as_str().to_string(), val.as_str().to_string());
                }
            }
        }

        if section.0.len() > 0 {
            self.process_section( section )?;
        }

        self.loaded_files.push( filename.clone() );
        Ok(())
    }

    fn process_section(&mut self, mut section: ConfigHashMap) -> Result<(),ConfigError>{

        let adpt = adapter::get_adapter( &section )?;

        let instance = Instance {
            adapter:       Box::new(Arc::new(adpt)),
            handle:        Arc::new(section.get(&["handle","name"])?),
            tag:           section.get_opt(&["tag"])?,
            class:         section.get_opt(&["class"])?.unwrap_or("master".to_string()),
            instance_id:   section.get_opt(&["instance_id"])?,
            schema_id:     section.get_opt(&["schema_id"])?,
            allowquery:    section.get_opt(&["allowquery"])?.unwrap_or(PerlyBool(true)),
            readonly:      section.get_opt(&["readonly"])?.unwrap_or(PerlyBool(false)),
        };
         
        self.instances.push(instance.clone());

        
        let dbr_bootstrap: Option<PerlyBool> = section.get_opt(&["dbr_bootstrap"])?;
        if let Some(PerlyBool(true)) = dbr_bootstrap {
            self.load_dbconf(&instance)?;
        }

        Ok()

    }

    fn load_dbconf (&mut self, seed_instance: &Instance) -> Result<(),ConfigError> {
        unimplemented!()
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
    pub fn close_all_filehandles (&mut self) {
        for instance in self.instances.iter() {
            instance.adapter.close_all_filehandles()
        }
    }
}

// sub load_from_db{

//       my( $package ) = shift;
//       my %params = @_;

//       my $self = {
// 		  session => $params{session},
// 		 };
//       bless( $self, $package ); # Dummy object

//       my $parent = $params{parent_inst} || return $self->_error('parent_inst is required');
//       my $dbh = $parent->connect || return $self->_error("Failed to connect to (@{[$parent->handle]} @{[$parent->class]})");
//       my $loaded = $INSTANCES_BY_GUID{ $parent->{guid} }{ loaded_instances } ||= [];

//       return $self->_error('Failed to select instances') unless
// 	my $instrows = $dbh->select(
// 				    -table => 'dbr_instances',
//                                     -where  => (@$loaded ? { instance_id => [ "d!", @$loaded ] } : undef),
// 				    -fields => 'instance_id schema_id class dbname username password host dbfile module handle readonly tag'
// 				   );

//       my @instances;
//       foreach my $instrow (@$instrows){

// 	    my $instance = $self->register(
// 					   session => $self->{session},
// 					   spec   => $instrow
// 					  ) || $self->_error("failed to load instance from database (@{[$parent->handle]} @{[$parent->class]})") or next;
// 	    push @instances, $instance;
//             push @$loaded, $instrow->{instance_id};
//       }

//       return \@instances;
// }

#[cfg(test)]
mod tests {
    use config::Config;
    #[test]
    fn load_dbconf() {
        let mut config = Config::new();
        config.load_file("t/resource/dbr_conf_mysql_fake.conf");
    }
}