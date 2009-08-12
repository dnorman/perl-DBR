# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::Subquery;
use strict;
use base 'DBR::Query::Part';
use Carp;

sub new{
      my( $package ) = shift;
      my ($field,$query) = @_;

      croak('field must be a Field object') unless ref($field) =~ /^DBR::Config::Field/; # Could be ::Anon
      croak('value must be a Value object') unless ref($query) eq 'DBR::Query';

      my $self = [ $field, $query ];

      bless( $self, $package );
      return $self;
}

sub type { return 'SUBQUERY' };
sub field   { return $_[0]->[0] }
sub query { return $_[0]->[1] }
sub sql   { return $_[0]->field->sql($_[1]) . ' IN (' . $_[0]->query->sql($_[1]) . ')'}

sub _validate_self{ 1 }

sub is_emptyset { $_[0]->query->where_is_emptyset }
1;

###########################################


1;
