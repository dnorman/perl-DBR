# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Where;

use strict; use base 'DBR::Common';

sub new{
      my( $package ) = shift;

      return $package->_error('cannot call new on DBR::Query::Where') if $package eq 'DBR::Query::Where';

      for (@_){
	    ref($_) =~ /^DBR::Query::Where::/ || return $package->_error('arguments must be logic objects')
      };

      my $self = [@_];

      bless( $self, $package );

      return $self;
}

sub children{ return @{$_[0]} }

sub validate{
      my $self = shift;
      my $query = shift;
      return $self->_error('Query object is required') unless ref($query) =~/^DBR::Query$/;
      $self->_validate_self($query) or return $self->_error('Failed to validate ' . ref($self) );

      for ($self->children){;
	    return undef unless $_->validate($query)
      }

      return 1;
}

sub _validate_self{ return scalar($_[0]->children)?1:$_[0]->_error('Invalid object')  } # AND/OR are only valid if they have at least one child

sub sql { # Used by AND/OR
      my $self = shift;
      my $nested = shift;


      my $type = $self->type;
      $type =~ /^(AND|OR)$/ or return $self->_error('this sql function is only used for AND/OR');

      my $sql;
      $sql .= '(' if $nested;
      $sql .= join(' ' . $type . ' ', map { $_->sql(1) } $self->children );
      $sql .= ')' if $nested;

      return $sql;
}

sub logger { undef }

1;

###########################################
package DBR::Query::Where::AND;
use strict; our @ISA = ('DBR::Query::Where');

sub type { return 'AND' };

1;

###########################################
package DBR::Query::Where::OR;
use strict; our @ISA = ('DBR::Query::Where');

sub type { return 'OR' };

1;

###########################################
package DBR::Query::Where::FIELD;
use strict; our @ISA = ('DBR::Query::Where');

sub new{
      my( $package ) = shift;
      my ($key,$value) = @_;

      return $package->_error('key must be specified') unless $key;
      return $package->_error('value must be a Value object') unless ref($value) eq 'DBR::Query::Value';

      my $self = [ $key, $value ];

      bless( $self, $package );
      return $self;
}

sub type { return 'FIELD' };
sub children { return () };
sub key   { return $_[0]->[0] }
sub value { return $_[0]->[1] }
sub sql   { return $_[0]->key . ' ' . $_[0]->value->sql }
sub _validate_self{ 1 }


###########################################
package DBR::Query::Where::SUBQUERY;
use strict; our @ISA = ('DBR::Query::Where');

sub new{
      my( $package ) = shift;
      my ($field,$query) = @_;

      return $package->_error('key must be specified') unless $field;
      return $package->_error('value must be a Value object') unless ref($query) eq 'DBR::Query';

      my $self = [ $field, $query ];

      bless( $self, $package );
      return $self;
}

sub type { return 'SUBQUERY' };
sub children { return ( ) };
sub field   { return $_[0]->[0] }
sub query { return $_[0]->[1] }
sub sql   { return $_[0]->field . ' IN (' . $_[0]->query->sql . ')'}
sub _validate_self{ 1 }

1;

###########################################

package DBR::Query::Where::JOIN;
use strict; our @ISA = ('DBR::Query::Where');

sub new{
      my( $package ) = shift;
      my ($from,$to) = @_;

      return $package->_error('from must be specified') unless $from;
      return $package->_error( 'to must be specified' ) unless  $to;

      my @fromparts = split(/\./,$from);
      my @toparts   = split(/\./,$to);

      scalar(@fromparts) == 2 or return $package->_error("From field must be in the format table.field");
      scalar(@toparts)   == 2 or return $package->_error( "To field must be in the format table.field" );

      my $self = [ @fromparts, @toparts ];

      bless( $self, $package );
      return $self;
}

sub from_table { return $_[0]->[0] }
sub from_field { return $_[0]->[1] }
sub to_table   { return $_[0]->[2] }
sub to_field   { return $_[0]->[3] }

sub type { return 'JOIN' };
sub children { return () };


sub sql {
      my $self = shift;
      return $self->from_table . '.' . $self->from_field .
	' = ' . $self->to_table .'.' . $self->to_field;
}
sub _validate_self{
      my $self = shift;
      my $query = shift;

      $query->check_table( $self->from_table ) or return $self->_error('Invalid join-from table ' . $self->from_table);
      $query->check_table(  $self->to_table  ) or return $self->_error('Invalid join-to table '   . $self->to_table);

      return 1;
}


1;
