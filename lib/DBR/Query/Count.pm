package DBR::Query::Part::Count;

use strict;
use base 'DBR::Query::Part';

sub new{
      my( $package ) = shift;
      return bless( [], $package );
}

sub children { return ()  };
sub sql      { 'count(*)' }
sub _validate_self{ 1 }
