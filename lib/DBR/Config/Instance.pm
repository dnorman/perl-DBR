package DBR::Config::Instance;

use strict;
use DBI;
use base 'DBR::Common';
use DBR::Config::Schema;

my $GUID = 1;

#here is a list of the currently supported databases and their connect string formats
my %connectstrings = (
		      Mysql => 'dbi:mysql:database=-database-;host=-hostname-',
		      Pg    => 'dbi:Pg:dbname=-database-;host=-hostname-',
		     );

my %INSTANCES;
my %INSTANCES_BY_GUID;

sub lookup{
      my $package = shift;
      my %params = @_;

      my $self = { logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $handle = $params{handle} || return $self->_error('handle is required');
      my $class  = $params{class}  || 'master';

      my $instance = $INSTANCES{$handle}->{$class} || $INSTANCES{$handle}->{'*'}; # handle aliases if there's no exact match

      return $self->_error("No DB instance found for '$handle','$class'") unless $instance;

      return $instance;

}

sub load_from_db{

      my( $package ) = shift;
      my %params = @_;

      my $self = { logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $dbr    = $params{dbr}    || return $self->_error('dbr is required');
      my $handle = $params{handle} || return $self->_error('handle is required');
      my $class  = $params{class}  || return $self->_error('class is required');

      my $dbh = $dbr->connect($handle,$class) || return $self->_error("Failed to connect to '$handle','$class'");

      return $self->_error('Failed to select instances') unless
	my $instrows = $dbh->select(
				     -table => 'dbr_instances',
				     -fields => 'instance_id schema_id class dbname username password host module'
				    );
      my @instances;
      foreach my $instrow (@$instrows){

	    my $instance = $self->register(
					   logger => $self->{logger},
					   spec   => $instrow
					  ) || $self->_error("failed to load instance from database ($handle,$class)") && next;
	    push @instances, $instance;
      }

      return \@instances;
}

sub register { # basically the same as a new
      my( $package ) = shift;
      $package = ref( $package ) || $package;
      my %params = @_;


      my $self = { logger => $params{logger} };
      bless( $self, $package );

      my $spec = $params{spec};

      my $config = {
		    handle      => $spec->{handle}   || $spec->{name} || $spec->{dbname},
		    module      => $spec->{module}   || $spec->{type},
		    database    => $spec->{dbname}   || $spec->{database},
		    hostname    => $spec->{hostname} || $spec->{host},
		    user        => $spec->{username} || $spec->{user},
		    password    => $spec->{password},
		    class       => $spec->{class}       || 'master', # default to master
		    instance_id => $spec->{instance_id} || '',
		    schema_id   => $spec->{schema_id}   || '',
		    allowquery  => $spec->{allowquery}  || 0,
		   };

      return $self->_error( 'handle/name parameter is required'     ) unless $config->{handle};
      return $self->_error( 'module/type parameter is required'     ) unless $config->{module};
      return $self->_error( 'database/dbname parameter is required' ) unless $config->{database};
      return $self->_error( 'host[name] parameter is required'      ) unless $config->{hostname};
      return $self->_error( 'user[name] parameter is required'      ) unless $config->{user};
      return $self->_error( 'password parameter is required'        ) unless $config->{password};

      $config->{connectstring} = $connectstrings{$config->{module}} || return $self->_error("module '$config->{module}' is not a supported database type");

      $config->{dbr_bootstrap} = 1 if $spec->{dbr_bootstrap};

      foreach my $key (keys %{$config}) {
	    $config->{connectstring} =~ s/-$key-/$config->{$key}/;
      }

      $config->{guid} = $GUID++;
      $self->{_conf} = $config;

      # Now register this instance in the global repository
      $INSTANCES{ $self->handle }->{ $self->class } = $self;

      $INSTANCES_BY_GUID{ $self->guid } = $self;
      if ($spec->{alias}) {
	    $INSTANCES{ $spec->{alias} }->{'*'} = $self;
      }


      return( $self );
}

sub new_connection{
      my $self = shift;

      my $config = $self->{_conf};
      my @params = ($config->{connectstring}, $config->{user}, $config->{password});

      my $dbh = DBI->connect(@params) or
	return $self->_error("Error: Failed to connect to db $config->{handle},$config->{class}");

      return $dbh;
}

sub handle { $_[0]->{_conf}->{handle}   }
sub class  { $_[0]->{_conf}->{class}    }
sub guid   { $_[0]->{_conf}->{guid}     }
sub module { $_[0]->{_conf}->{module}   }
sub dbr_bootstrap{ $_[0]->{_conf}->{dbr_bootstrap} || 0 }
sub schema_id { $_[0]->{_conf}->{schema_id} }

#shortcut to fetch the schema object that corresponds to this instance
sub schema{
      my $self = shift;

      my $schema_id = $self->schema_id || return '';

      my $schema = DBR::Config::Schema->new(
							 logger    => $self->{logger},
							 schema_id => $schema_id,
							) || return $self->_error("failed to fetch schema object for schema_id $schema_id");

      return $schema;
}

1;
