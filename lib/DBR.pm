# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR;

use strict;
use DBR::Handle;
use DBR::Config;
use base 'DBR::Common';

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {logger => $params{-logger}};

      bless( $self, $package );

      return $self->_error("Error: -conf must be specified") unless $params{-conf};

      return $self->_error("Failed to create DBR::Config object") unless
	$self->{config} = DBR::Config->new( logger => $self->{logger} );

      $self->{config} -> load_file(
				   dbr  => $self,
				   file => $params{-conf}
				  ) or return $self->_error("Failed to load DBR conf file");

      return( $self );
}


sub setlogger {
      my $self = shift;
      $self->{logger} = shift;
}

sub connect {
      my $self = shift;
      my $name = shift;
      my $class = shift;
      my $flag;

      if ($class eq 'dbh') {	# legacy
	    $flag = 'dbh';
	    $class = undef;
      }

      my $instance = DBR::Config::Instance->lookup(
						   dbr    => $self,
						   logger => $self->{logger},
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

      if ($class eq 'dbh') {	# legacy
	    $flag = 'dbh';
	    $class = undef;
      }

      my $instance = DBR::Config::Instance->lookup(
						   dbr    => $self,
						   logger => $self->{logger},
						   handle => $name,
						   class  => $class
						  ) or return $self->_error("No config found for db '$name' class '$class'");
      return $instance;
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
