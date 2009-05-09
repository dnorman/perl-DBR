# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Compat;

use strict;
use base 'DBR::Common';
use DBR::Query;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  dbh      => $params{dbh},
		  logger   => $params{logger},
		 };

      return $self->_error('dbh object is required') unless $self->{dbh};
      bless( $self, $package );

      return( $self );
}



1;
