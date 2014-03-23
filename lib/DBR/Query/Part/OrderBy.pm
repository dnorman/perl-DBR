# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::OrderBy;

use strict;
use base 'DBR::Query::Part';

sub new{
      my( $package ) = shift;
      my ($field) = @_;

      return $package->_error('field must be a Field object') unless ref($field) =~ /^DBR::Config::Field/; # Could be ::Anon

      my $self = [ $field ];

      bless( $self, $package );
      return $self;
}


sub field   { return $_[0]->[0] }
sub sql   { return $_[0]->field->sql($_[1]) }
sub _validate_self{ 1 }

sub validate{ 1 }

1;
