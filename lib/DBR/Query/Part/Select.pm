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
      scalar(@_) || croak('must provide at least one field');

      $lastidx = -1;
      for (@_){
	    ref($_) =~ /^DBR::Config::Field/ || croak('must specify field as a DBR::Config::Field object'); # Could also be ::Anon
	    $_->index( ++$lastidx );
      }

      return bless( [ [@_], $lastidx ], $pkg );
}

# if ($field->table_alias) {
#       return $self->_error("table alias is invalid without a join") unless $self->{aliasmap};
#       return $self->_error('invalid table alias "' . $field->table_alias . '" in -fields')        unless $self->{aliasmap}->{ $field->table_alias };
# }


sub _validate_self{ 1 } # I don't exist unless I'm valid

sub children { @{$ _[0][0] } }
sub lastidx  { $_[0][1] }
*fields = \&children;

sub sql {
    my ($self, $conn) = @_;
    return 'SELECT ' . join (', ', map { $_->sql( $conn ) } $self->children );
}

1;
