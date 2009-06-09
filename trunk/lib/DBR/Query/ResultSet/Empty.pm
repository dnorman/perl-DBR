package DBR::Query::ResultSet::Empty;

use strict;
use base 'DBR::Common';
use Carp;

sub new {
      my( $package ) = shift;
      my $foo = '';
      my $self = \$foo; # Minimal reference

      bless( $self, $package );
      return( $self );
}

sub next     { undef }
sub count    { 0     }
sub hashrefs { []    }

sub raw_hashrefs  { [] }
sub raw_arrayrefs { [] }
sub raw_keycol    { {} }

1;
