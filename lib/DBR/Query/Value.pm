# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Value;

use strict;
use base 'DBR::Common';

my %opflags = (
	       like => 'like',
	       '<>' => 'not',
	       '>=' => 'ge',
	       '<=' => 'le',
	       '>'  => 'gt',
	       '<'  => 'lt',
	       '!'  => 'not',
	      );


sub new{
      my( $package ) = shift;
      my %params = @_;

      # #Translation plugins go HERE

      my $self = {
		  number   => $params{number} || 0,
		  value    => $params{value}, # translate this
		  operator => $params{operator},
		 };

      return $self;

}

sub direct {
      my( $package ) = shift;
      my %params = @_;

      my $value = $params{value} or return $self->_error('value must be specified');

      my $numeric = 0;
      my $operator;

      if(ref($value) eq 'ARRAY'){
	    my $flags = shift @{$value}; # Yes, we are altering the input array... deal with it.

	    if ($flags =~ /like/) { # like
		  #return $self->_error('LIKE flag disabled without the allowquery flag') unless $self->{config}->{allowquery};
		  $operator = 'like';

	    } elsif ($flags =~ /!/) { # Not
		  $operator = 'not';

	    } elsif ($flags =~ /\<\>/) { # greater than less than
		  $operator = 'not'; $numeric = 1;

	    } elsif ($flags =~ /\>=/) { # greater than eq
		  $operator = 'ge'; $numeric = 1;

	    } elsif ($flags =~ /\<=/) { # less than eq
		  $operator = 'le'; $numeric = 1;

	    } elsif ($flags =~ /\>/) { # greater than
		  $operator = 'gt'; $numeric = 1;

	    } elsif ($flags =~ /\</) { # less than
		  $operator = 'lt'; $numeric = 1;

	    }
	    if($flags =~ /d/){
		  $numeric = 1;
	    }

      }

      $operator ||= 'eq';

      return $package->new(
			   number   => $number,
			   operator => $operator,
			   value    => $value,
			  );
}

1;
