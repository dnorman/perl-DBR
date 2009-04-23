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
	    /^DBR::Query::Part/ || return _PACKAGE_->_error('arguments must be logic objects')
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

      return _PACKAGE_->_error('key must be specified') unless $key;
      return _PACKAGE_->_error('value bust be a Value object') unless $value eq 'DBR::Query::Value';

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
      my ($key,$value) = @_;

      return _PACKAGE_->_error('key must be specified') unless $key;
      return _PACKAGE_->_error('value bust be a Value object') unless $value eq 'DBR::Query::Value';

      my $self = [ $key, $value ];

      bless( $self, $package );
      return $self;
}

sub type { return 'FIELD' };
sub children { return undef };

1;
