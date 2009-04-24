# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part;

use strict; use base 'DBR::Common';

sub new{
      my( $package ) = shift;

      map {
	    /^DBR::Query::Part/ || return $package->_error('arguments must be logic objects')
      } @_;

      my $self = [@_];

      bless( $self, $package );

      return $self;
}

sub children{ return @{$_[0]} }

1;

###########################################
package DBR::Query::Part::AND;
use strict; our @ISA = ('DBR::Query::Part');

sub type { return 'AND' };

1;

###########################################
package DBR::Query::Part::OR;
use strict; our @ISA = ('DBR::Query::Part');
sub type { return 'OR' };

1;

###########################################
package DBR::Query::Part::FIELD;
use strict; our @ISA = ('DBR::Query::Part');

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
sub children { return undef };

1;

###########################################

package DBR::Query::Part::JOIN;
use strict; our @ISA = ('DBR::Query::Part');

sub new{
      my( $package ) = shift;
      my ($from,$to) = @_;

      return $package->_error('from must be specified') unless $from;
      return $package->_error( 'to must be specified' ) unless  $to;

      my $self = [ $from, $to ];

      bless( $self, $package );
      return $self;
}

sub type { return 'JOIN' };
sub children { return undef };
sub from { return $_[0]->[0] }
sub to   { return $_[0]->[1] }

1;
