
use config::Config;
#[derive(FromPerlKV,Debug)]
pub struct ContextOptions {
    use_exceptions: bool,
    
    app:            Option<String>,

    #[perlxs(key = "-conf")]
    conf:           Option<String>,

    logpath:        Option<String>,

    loglevel:       Option<String>,

    #[perlxs(key = "-logger")]
    logger:         Option<String>,

    #[perlxs(key = "-admin")]
    admin:          bool,

    #[perlxs(key = "-fudge_tz")]
    fudge_tz:       bool,
}

pub struct Context {
    opts:   ContextOptions,
    config: Config,
}

impl Context {
    pub fn new (opts: ContextOptions) -> Self {
        let config = Config::new();
        let mut context = Self{
            opts,
            config
        };

        if let Some(ref conf_file) = context.opts.conf {
            context.config.load_file( conf_file );
        }
        context
    }
    pub fn close_all_filehandles (&mut self) {
        self.config.close_all_filehandles();
    }
}
    //   return $self->_error("Failed to create DBR::Util::Session object") unless
	// $self->{session} = DBR::Misc::Session->new(
	// 					   logger   => $self->{logger},
	// 					   admin    => $params{-admin} ? 1 : 0, # make the user jump through some hoops for updating metadata
	// 					   fudge_tz => $params{-fudge_tz},
	// 					   use_exceptions => $params{-use_exceptions},
	// 					  );

    //   return $self->_error("Failed to create DBR::Config object") unless
	// my $config = DBR::Config->new( session => $self->{session} );

    //   $config -> load_file(
	// 		   dbr  => $self,
	// 		   file => $params{-conf}
	// 		  ) or return $self->_error("Failed to load DBR conf file");