# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Value;

use strict;
use base 'DBR::Common';


my %str_operators = map {$_ => 1} qw'like eq not';
my %num_operators = map {$_ => 1} qw'eq not ge le gt lt';

sub new{
      my( $package ) = shift;
      my %params = @_;

      my $field = $params{field}; # optional

      my $value = $params{value};
      return $self->_error('value must be specified') unless $value;

      my $is_number = $params{is_number}? 1 : 0;
      my $operator;

      if ( ref ($value) eq 'DBR::Operator' ) {
	    my $wrapper = $value;

	    $value    = $wrapper->value;
	    $operator = $wrapper->operator;
      } else {
	    $operator = $params{operator} || 'eq';
      }

      # #Translation plugins go here
      if($field){
      }


      if ($is_number){
	    return $self->_error("invalid operator '$operator'") unless $num_operators{ $operator };
	    # check numeric range HERE
      }else{
	    return $self->_error("invalid operator '$operator'") unless $str_operators{ $operator };
      }



      my $self = {
		  is_number => is_number,
		  value     => $values,
		  operator  => $operator,
		 };

      return $self;

}

sub direct {
      my( $package ) = shift;
      my %params = @_;

      my $value = $params{value} or return $self->_error('value must be specified');

      my $is_number = 0;
      my $operator;

      if(ref($value) eq 'ARRAY'){
	    my $flags = shift @{$value}; # Yes, we are altering the input array... deal with it.

	    if ($flags =~ /like/) { # like
		  #return $self->_error('LIKE flag disabled without the allowquery flag') unless $self->{config}->{allowquery};
		  $operator = 'like';

	    } elsif ($flags =~ /!/) { # Not
		  $operator = 'not';

	    } elsif ($flags =~ /\<\>/) { # greater than less than
		  $operator = 'not'; $is_number = 1;

	    } elsif ($flags =~ /\>=/) { # greater than eq
		  $operator = 'ge'; $is_number = 1;

	    } elsif ($flags =~ /\<=/) { # less than eq
		  $operator = 'le'; $is_number = 1;

	    } elsif ($flags =~ /\>/) { # greater than
		  $operator = 'gt'; $is_number = 1;

	    } elsif ($flags =~ /\</) { # less than
		  $operator = 'lt'; $is_number = 1;

	    }

	    if($flags =~ /d/){
		  $is_number = 1;
	    }

      }

      $operator ||= 'eq';

      return $package->new(
			   is_number   => $is_number,
			   operator => $operator,
			   value    => $value,
			  );
}

1;
