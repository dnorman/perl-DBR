# The contents of this file are Copyright (c) 2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::Insert;

use strict;
use base 'DBR::Query::Part';

sub new{
      my( $pkg ) = shift;
      scalar(@_) || croak('must provide at least one set');

      for (@_){
	  ref($_) eq 'DBR::Query::Part::Set' || croak('arguments must be Sets');XS
      }

      return bless( [@_], $pkg );
}

sub _validate_self{ 1 } # I don't exist unless I'm valid
sub children{ @{$_[0]} }

sub sql   {
    my $self = shift;
    my $conn = shift;

    my @fields;
    my @values;
    for ( $self->children ) {
	push @fields, $_->field->sql( $conn );
	push @values, $_->value->sql( $conn );
    }

    return '(' . join (', ', @fields) . ') values (' . join (', ', @values) . ')';
}

1;
