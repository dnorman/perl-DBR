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



sub convertvals{
      my $self = shift;
      my $where = shift;

      $param = [%{$param}] if (ref($param) eq 'HASH');
      $param = [] unless (ref($param) eq 'ARRAY');

      my $where;

      my @out;
      while (@{$param}) {
	    my $key = shift @{$param};

	    # is it an OR? (single element)
	    if (ref($key) eq 'ARRAY') {
		  my @or;
		  foreach my $element (@{$key}){
			push @or, $self->convertvals($element) or $self->_error('convertvals failed');
		  }
		  push @out, \@or;

	    } else {

		  my $value = shift @{$param};

		  if (ref($value) eq 'HASH') {
			if($value->{-table} && ($value->{-field} || $value->{-fields})){ #is it a subquery?
			      my $subqval = $self->convertvals($value) or $self->_error('convertvals failed');

			      $outval = { %${value}, -where => $subqval };

			}elsif($self->{aliasmap}){ #not a subquery... are we doing a join?
			      my $alias = $key;
			      return $self->_error("invalid table alias '$alias' in -fields") unless $self->{aliasmap}->{$alias};

			      if(%{$value}){
				    my %ofields;
				    foreach my $k (keys %{$value}) {
					  $ofields{$k} = DBR::Query::Value->direct( value  => $value->{$k} )
					    or return $self->_error('failed to create value object');
				    }
			      }

			}else{
			      return $self->_error("invalid use of a hashref for key $key in -fields");
			}

		  } else {
			$outval = $value; # testing only - should be identical
			$outval =  DBR::Query::Value->direct( value  => $value ) or return $self->_error('failed to create value object');
		  }

		  push @out, $key, $outval;

	    }
      }

      return $where || '';
}


1;
