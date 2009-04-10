# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR;

use strict;
use DBR::DBRH;
use DBR::Config;
use base 'DBR::Common';

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {logger => $params{-logger}};

      bless( $self, $package );

      return $self->_error("Error: -conf must be specified") unless $params{-conf};

      return $self->_error("Failed to create DBR::Config object") unless
	$self->{config} =  DBR::Config->new( logger => $self->{logger} );

      $self->{config} -> load_file(
				   -dbr  => $self,
				   -file => $params{-conf}
				  ) or return $self->_error("Failed to load DBR conf file");

      $self->{CACHE} = {};
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

      my $instance = DBR::Config::Instance->lookup( handle => $name, class => $class) or
	return $self->_error("No config found for db '$name' class '$class'");

      return $self->_error('failed to get database handle') unless
	my $dbh = $self->_gethandle($instance);

      if (lc($flag) eq 'dbh') {
	    return $dbh;
      } else {

	    my $hclass = 'DBR::Handle::' . $instance->module;
	    return $self->_error("Failed to Load $hclass ($@)") unless eval "require $hclass";

	    return $self->_error("Failed to create $hclass object") unless
	      my $dbrh = $hclass->new(
				      dbh      => $dbh,
				      dbr      => $self,
				      logger   => $self->{logger},
				      instance => $instance
				     );
	    return $dbrh;
      }

}

sub remap{
      my $self = shift;
      my $class = shift;

      return $self->_error('class must be specified') unless $class;

      $self->{globalclass} = $class;

      return 1;
}

sub unmap{
      my $self = shift;
      undef $self->{globalclass};

      return 1;
}

sub flush_handles{
    my $self = shift;

    foreach my $dbname (keys %{$self->{CACHE}}){
	  foreach my $class (keys %{$self->{CACHE}->{$dbname}}){
		my $dbh = $self->{CACHE}->{$dbname}->{$class};
		$dbh->disconnect();
		delete $self->{CACHE}->{$dbname}->{class};
	  }
    }

    return undef;
}

sub _gethandle{
      my $self     = shift;
      my $instance = shift;
      my $dbh;

      #Ask the instance what it's handle and class are because it may have been gotten by an alias.
      my $realname  = $instance->handle;
      my $realclass = $instance->class;
      my $guid      = $instance->guid;

      $self->_logDebug2("Connecting to $realname, $realclass");

      $dbh = $self->{CACHE}->{ $guid };
      if ($dbh) {
	    if (  $dbh->do( "SELECT 1" )  ) {
		  $self->_logDebug2('Re-using existing connection');
	    } else {
		  $dbh->disconnect();
		  $dbh = $self->{CACHE}->{ $guid } = undef;
	    }
      }

      if (!$dbh) {
	    $self->_logDebug2('getting a new connection');
	    $dbh = $instance->new_connection() or return $self->_error("Failed to connect to $realname, $realclass");

	    $self->{CACHE}->{ $guid } = $dbh;
	    $self->_logDebug2('Connected');

      }

      return $dbh;
}

sub DESTROY{
    my $self = shift;

    $self->flush_handles();

}

1;
