package DBR::Query::Part;

use strict;
use base 'DBR::Common';
use DBR::Query::Part::AndOr;
use DBR::Query::Part::Compare;
use DBR::Query::Part::Join;
use DBR::Query::Part::Set;
use DBR::Query::Part::Subquery;
use DBR::Query::Part::OrderBy;
use Carp;

sub validate{
      my $self = shift;
      my $query = shift;

      croak('Query object is required') unless ref($query) =~/^DBR::Query::/;

      $self->_validate_self($query) or return $self->_error('Failed to validate ' . ref($self) );

      for ($self->children){
	    return undef unless $_->validate($query)
      }

      return 1;
}

sub _session { undef }
sub _validate_self{ 0 } # I'm not valid unless I'm overridden

sub children{ return () }


1;
