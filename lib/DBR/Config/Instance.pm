# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Instance;

use strict;
use DBI;
use base 'DBR::Common';
use DBR::Config::Schema;

my $GUID = 1;
my %CONCACHE;

#here is a list of the currently supported databases and their connect string formats
my %connectstrings = (
		      Mysql => 'dbi:mysql:database=-database-;host=-hostname-',
		      Pg    => 'dbi:Pg:dbname=-database-;host=-hostname-',
		     );

my %INSTANCES;
my %INSTANCES_BY_GUID;


sub flush_all_handles {
      # can be run with or without an object
      my $cache = \%CONCACHE;
      foreach my $dbname (keys %{$cache}){

	    foreach my $class (keys %{$cache->{$dbname}}){

		my $dbh = $cache->{$dbname}->{$class};
		$dbh->disconnect();
		delete $cache->{$dbname}->{class};

	  }

      }

      return 1;
}

sub lookup{
      my $package = shift;
      my %params = @_;

      my $self = {
		  logger => $params{logger}
		 };
      bless( $self, $package );

      return $self->_error('logger is required') unless $self->{logger};

      if( $params{guid} ){

	    $INSTANCES_BY_GUID{ $params{guid} } or return $self->_error('no such guid');
	    $self->{guid} = $params{guid};

      }else{
	    my $handle = $params{handle} || return $self->_error('handle is required');
	    my $class  = $params{class}  || 'master';

	    my $conf = $INSTANCES{$handle}->{$class} || $INSTANCES{$handle}->{'*'}; # handle aliases if there's no exact match

	    return $self->_error("No DB instance found for '$handle','$class'") unless $conf;

	    $self->{guid} = $conf->{guid};
      }

      return $self;

}

sub load_from_db{

      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $parent = $params{parent_inst} || return $self->_error('parent_inst is required');
      my $dbh = $parent->connect || return $self->_error("Failed to connect to (@{[$parent->handle]} @{[$parent->class]})");

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
					  ) || $self->_error("failed to load instance from database (@{[$parent->handle]} @{[$parent->class]})") && next;
	    push @instances, $instance;
      }

      return \@instances;
}

sub register { # basically the same as a new
      my( $package ) = shift;
      $package = ref( $package ) || $package;
      my %params = @_;


      my $self = {
		  logger => $params{logger}
		 };
      bless( $self, $package );

      return $self->_error( 'logger is required'  ) unless $self->{logger};


      my $spec = $params{spec} or return $self->_error( 'spec ref is required' );

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

      $config->{dbr_bootstrap} = $spec->{dbr_bootstrap}? 1:0;

      foreach my $key (keys %{$config}) {
	    $config->{connectstring} =~ s/-$key-/$config->{$key}/;
      }

      my $guid = $GUID++;
      $INSTANCES_BY_GUID{ $guid } = $config;
      $self->{guid} = $config->{guid} = $guid;
      # Now we are cool to start calling accessors

      # Register this instance in the global repository
      $INSTANCES{ $self->handle }->{ $self->class } = $config;

      if ($spec->{alias}) {
	    $INSTANCES{ $spec->{alias} }->{'*'} = $config;
      }


      return( $self );
}


#######################################################################
############################                                          #
############################  All subs below here require an object   #
############################                                          #
#######################################################################


sub connect{
      my $self = shift;
      my $flag = shift;

      return $self->_error('failed to get database handle') unless
	my $dbh = $self->_gethandle;

      if (lc($flag) eq 'dbh') {
	    return $dbh;
      } else {

	    return $self->_error("Failed to create Handle object") unless
	      my $dbrh = DBR::Handle->new(
					  dbh      => $dbh,
					  logger   => $self->{logger},
					  instance => $self,
					 );
	    return $dbrh;
      }
}

sub _gethandle{
      my $self = shift;
      my $dbh;

      #Ask the instance what it's handle and class are because it may have been gotten by an alias.
      my $realname  = $self->handle;
      my $realclass = $self->class;
      my $guid      = $self->guid;

      $self->_logDebug2("Connecting to $realname, $realclass");
      my $cache = \%CONCACHE;

      $dbh = $cache->{ $guid };
      if ($dbh) {
	    if (  $dbh->ping  ) { #$dbh->do( "SELECT 1" ) 
		  $self->_logDebug2('Re-using existing connection');
	    } else {
		  $dbh->disconnect();
		  $dbh = $cache->{ $guid } = undef;
	    }
      }

      if (!$dbh) {
	    $self->_logDebug2('getting a new connection');
	    $dbh = $self->_new_connection() or return $self->_error("Failed to connect to $realname, $realclass");

	    $cache->{ $guid } = $dbh;
	    $self->_logDebug2('Connected');

      }

      return $dbh;
}

sub _new_connection{
      my $self = shift;

      my $config = $INSTANCES_BY_GUID{ $self->{guid} };
      my @params = ($config->{connectstring}, $config->{user}, $config->{password});

      my $dbh = DBI->connect(@params) or
	return $self->_error("Error: Failed to connect to db $config->{handle},$config->{class}");

      return $dbh;
}

sub handle        { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{handle}   }
sub class         { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{class}    }
sub guid          { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{guid}     }
sub module        { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{module}   }
sub dbr_bootstrap { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{dbr_bootstrap} }
sub schema_id     { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{schema_id} }
sub name          { return $_[0]->handle . ' ' . $_[0]->class }

#shortcut to fetch the schema object that corresponds to this instance
sub schema{
      my $self = shift;
      my %params = @_;

      my $schema_id = $self->schema_id || return ''; # No schemas here

      my $schema = DBR::Config::Schema->new(
					    logger    => $self->{logger},
					    schema_id => $schema_id,
					   ) || return $self->_error("failed to fetch schema object for schema_id $schema_id");

      return $schema;
}

1;
