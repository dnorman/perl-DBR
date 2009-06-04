# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Trans;


use strict;
use base 'DBR::Common';

use DBR::Config::Trans::Enum;
use DBR::Config::Trans::Dollars;
use DBR::Config::Trans::UnixTime;



my %MODULES = (
	       1 => 'Enum',
	       2 => 'Dollars',
	       3 => 'UnixTime',
	      );

sub list_translators{
      return [ map { {id => $_, name => $MODULES{$_} } }  keys %MODULES ];
}

sub load{
      my( $package ) = shift;
      my %params = @_;

      my $self = { session => $params{session} };
      bless( $self, $package ); # Dummy object

      my $instance = $params{instance} || return $self->_error('instance is required');

      my $field_ids = $params{field_id} || return $self->_error('field_id is required');
      $field_ids = [$field_ids] unless ref($field_ids) eq 'ARRAY';

      foreach my $trans_id (keys %MODULES){

	    my $module = $MODULES{$trans_id} or $self->_error('invalid module') or next;

	    my $pkg = 'DBR::Config::Trans::' . $module;
	    #eval "require $pkg" or $self->_error('failed to load package ' . $pkg) or next;

	    $pkg->moduleload(
			     session => $self->{session},
			     instance => $instance,
			     field_id => $field_ids,
			    ) or return $self->_error('failed to load translator' . $module);

      }


      return 1;
}

sub moduleload{ 1 } # Stub

sub module { $_[0]->{module} }
sub new {
      my $package = shift;
      my %params = @_;
      my $self = {
		  session   => $params{session},
		  trans_id => $params{trans_id},
		  field_id => $params{field_id},
		 };

      return $package->_error('trans_id must be specified') unless $self->{trans_id};

      my $module = $MODULES{ $self->{trans_id} } or $self->_error('invalid module');
      $self->{module} = $module;

      bless( $self, $package . '::' . $module );
      return $self->_error('field_id is required')            unless $self->{field_id};

      return( $self );
}

1;
