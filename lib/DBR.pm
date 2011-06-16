# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR;

use strict;
use DBR::Handle;
use DBR::Config;
use DBR::Config::Instance;
use DBR::Misc::Session;
use Scalar::Util 'blessed';
use base 'DBR::Common';
use DBR::Util::Logger;
use Carp;

our $VERSION = '-DBR-VERSION-TAG-';

my %APP_BY_CONF;
my %CONF_BY_APP;
my %OBJECTS;
my $CT;

sub import {
      my $pkg = shift;
      my %params = @_;

      my ($callpack, $callfile, $callline) = caller;

      my $app  = $params{app};
      my $exc  = $params{use_exceptions} || 0;
      my $conf;

      if( $params{conf} ){
	    croak "conf file '$params{conf}' not found" unless -e $params{conf};

	    $conf = $params{conf};
	    $app ||= $APP_BY_CONF{ $conf } ||= 'auto_' . $CT++; # use existing app id if conf exists, or make one up
	    $CONF_BY_APP{ $app } = $conf;
      }elsif ( defined $app && length $app ){
	    $conf = $CONF_BY_APP{ $app };
      }

      return 1 unless $app; # No import requested

      if($conf){
	    $OBJECTS{ $app }{ $exc } ||= DBR->new(
						  -logger => DBR::Util::Logger->new(
										    -logpath  => $params{logpath} || '/tmp/dbr_auto.log',
										    -logLevel => $params{loglevel} || 'warn'
										   ),
						  -conf           => $conf,
						  -use_exceptions => $exc,
						 );
      }

      my $dbr = $OBJECTS{ $app }{ $exc } or croak "No DBR object could be located";

      no strict 'refs';
      *{"${callpack}::dbr_connect"} =
	sub {
	      shift if blessed($_[0]) || $_[0]->isa( [caller]->[0] );
	      $dbr->connect(@_);
	};
        
      *{"${callpack}::dbr_instance"} =
	sub {
	      shift if blessed($_[0]) || $_[0]->isa( [caller]->[0] );
	      $dbr->get_instance(@_);
	};
        

}
sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {logger => $params{-logger}};

      bless( $self, $package );

      return $self->_error("Error: -conf must be specified") unless $params{-conf};

      return $self->_error("Failed to create DBR::Util::Session object") unless
	$self->{session} = DBR::Misc::Session->new(
						   logger   => $self->{logger},
						   admin    => $params{-admin} ? 1 : 0, # make the user jump through some hoops for updating metadata
						   fudge_tz => $params{-fudge_tz},
						   use_exceptions => $params{-use_exceptions},
						  );

      return $self->_error("Failed to create DBR::Config object") unless
	my $config = DBR::Config->new( session => $self->{session} );

      $config -> load_file(
			   dbr  => $self,
			   file => $params{-conf}
			  ) or return $self->_error("Failed to load DBR conf file");


      DBR::Config::Instance->flush_all_handles(); # Make it safer for forking

      return( $self );
}


sub setlogger {
      my $self = shift;
      $self->{logger} = shift;
}

sub session { $_[0]->{session} }

sub connect {
      my $self = shift;
      my $name = shift;
      my $class = shift;
      my $flag;

      if ($class && $class eq 'dbh') {	# legacy
	    $flag = 'dbh';
	    $class = undef;
      }

      my $instance = DBR::Config::Instance->lookup(
						   dbr    => $self,
						   session => $self->{session},
						   handle => $name,
						   class  => $class
						  ) or return $self->_error("No config found for db '$name' class '$class'");

      return $instance->connect($flag);

}

sub get_instance {
      my $self = shift;
      my $name = shift;
      my $class = shift;
      my $flag;

      if ($class && $class eq 'dbh') {	# legacy
	    $flag = 'dbh';
	    $class = undef;
      }

      my $instance = DBR::Config::Instance->lookup(
						   dbr    => $self,
						   session => $self->{session},
						   handle => $name,
						   class  => $class
						  ) or return $self->_error("No config found for db '$name' class '$class'");
      return $instance;
}

sub timezone{
      my $self = shift;
      my $tz   = shift;
      $self->{session}->timezone($tz) or return $self->_error('Failed to set timezone');
}

sub remap{
      my $self = shift;
      my $class = shift;

      return $self->_error('class must be specified') unless $class;

      $self->{globalclass} = $class;

      return 1;
}

sub unmap{ undef $_[0]->{globalclass}; return 1 }
sub flush_handles{ DBR::Config::Instance->flush_all_handles }
sub DESTROY{ $_[0]->flush_handles }

1;

=pod

=head1 NAME

DBR - Database Repository ORM (object-relational mapper).

=head1 MANUAL

See L<DBR::Manual>

=cut

