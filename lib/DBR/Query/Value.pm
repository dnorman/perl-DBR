# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Value;

use strict;
use base 'DBR::Common';

my %sql_ops = (
	       eq      => '=',
	       ne      => '!=',
	       ge      => '>=',
	       le      => '<=',
	       gt      => '>',
	       lt      => '<',
	       like    => 'LIKE',
	       notlike => 'NOT LIKE',

	       in      => 'IN',     # \
	       notin   => 'NOT IN', #  |  not directly accessable
	       is      => 'IS',     #  |
	       isnot   => 'IS NOT'  # /
	      );

my %str_operators = map {$_ => 1} qw'eq ne like notlike';
my %num_operators = map {$_ => 1} qw'eq ne ge le gt lt';


#### Constructors ###############################################

sub new{
      my( $package ) = shift;
      my %params = @_;

      my $field = $params{field}; # optional

      my $self = {
		  dbrh   => $params{dbrh},
		  logger => $params{logger}
		 };

      bless( $self, $package );

      $self->{dbrh} or return $self->_error('dbrh must be specified');
      $self->{dbh} = $self->{dbrh}->dbh or return $self->_error('failed to fetch dbh');

      my $value = $params{value};
      return $self->_error('value must be specified') unless $value;

      $self->{is_number}  = $params{is_number}? 1 : 0;
      my $operator;
      my $ref = ref($value);

      if ( $ref eq 'DBR::Operator' ) {
	    my $wrapper = $value;

	    $value    = $wrapper->value;
	    $operator = $wrapper->operator;
      } else {
	    $operator = $params{operator} || 'eq';
      }

      my $ref = ref($value);

      if(!$ref){
	    $value = [$value];
      }elsif ($ref ne 'ARRAY'){
	    return $self->_error('value must be a scalar or an arrayref');
      }

      if( $self->{is_number} ){
	    foreach my $val ( @{$value}) {
		  if ($val !~ /^-?\d*\.?\d+$/) {
			return $self->_error("value $val is not a legal number");
		  }
	    }
      }

      if ($self->{is_number}){
	    return $self->_error("invalid operator '$operator'") unless $num_operators{ $operator };
	    # check numeric range HERE
      }else{
	    return $self->_error("invalid operator '$operator'") unless $str_operators{ $operator };
      }

      if (scalar(@{$value}) > 1 ){
	    #grep {!$uniq{$_}++} @{ $self->{value} }
	    $operator = 'in'    if $operator eq 'eq';
	    $operator = 'notin' if $operator eq 'ne';
      }

      $self->{value}    = $value;
      $self->{operator} = $operator;

      # #Translation plugins go here
      if($field){
      }

      return $self;

}


1;

## Methods #################################################
sub is_number{ return $_[0]->{is_number}             }
sub count    { return scalar(  @{ $_[0]->{value} } ) }

sub sql {
      my $self = shift;

      my $sql;

      my $values = $self->quoted;

      my $op = $self->{operator};

      if (@$values > 1) {
	    $sql .= '(' . join(',',@{$values}) . ')';
      } else {
	    $sql = $values->[0];
	    $op = 'is'    if ($sql eq 'NULL' && $op eq 'eq');
	    $op = 'isnot' if ($sql eq 'NULL' && $op eq 'ne');
      }

      return $sql_ops{ $op } . ' ' . $sql;

}

sub quoted{
      my $self = shift;

      if ($self->is_number){
	    return [ map { defined($_)?$_:'NULL' } @{$self->{value}} ];
      }else{
	    return [ map { defined($_)?$_:'NULL' } map { $self->{dbh}->quote($_) } @{$self->{value}} ];
      }

}




