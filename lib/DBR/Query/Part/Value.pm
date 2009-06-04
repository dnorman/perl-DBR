# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Part::Value;

use strict;
use base 'DBR::Common';


#### Constructors ###############################################

sub new{
      my( $package ) = shift;
      my %params = @_;

      my $field = $params{field}; # optional


      my $self = {
		  session => $params{session},
		  field  => $field
		 };

      bless( $self, $package );


      if (defined $field){ #field object is optional
	    return $self->_error('invalid field object') unless ref($field) eq 'DBR::Config::Field';
      }

      return $self->_error('value must be specified') unless exists($params{value}); # undef and 0 are both legal, so cannot check for defined or truth
      my $value = $params{value};

      if ( ref($value) eq 'DBR::Util::Operator' ) {
	    my $wrapper = $value;

	    $value   = $wrapper->value;
	    $self->{op_hint} = $wrapper->operator;
      }

      my $ref = ref($value);

      if(!$ref){
	    $value = [$value];
      }elsif ($ref ne 'ARRAY'){
	    return $self->_error('value must be a scalar or an arrayref');
      }

      if(ref($field) eq 'DBR::Config::Field'){ # No Anon
	    $self->{is_number} = $field->is_numeric? 1 : 0;

	    my $trans = $field->translator;
	    if($trans){

		  my @translated;
		  foreach (@$value){
			my $tv = $trans->backward($_) or return $self->_error("invalid value '$_' for field " . $field->name );
			push @translated, $tv;
		  }
		  $value = \@translated;
	    }
      }else{
	    return $self->_error('is_number must be specified') unless defined($params{is_number});

	    $self->{is_number}  = $params{is_number}? 1 : 0;
      }

      if( $self->{is_number} ){
	    foreach my $val ( @{$value}) {
                  $val = '' unless defined $val;
		  if ($val !~ /^-?\d*\.?\d+$/) {
			return $self->_error("value '$val' is not a legal number");
		  }
	    }
      }

      $self->{value}    = $value;

      return $self;

}


1;

## Methods #################################################
sub op_hint  { return $_[0]->{op_hint}               }
sub is_number{ return $_[0]->{is_number}             }
sub count    { return scalar(  @{ $_[0]->{value} } ) }

sub sql {
      my $self = shift;
      my $conn = shift or return $self->_error('conn is required');

      my $sql;

      my $values = $self->quoted($conn);

      if (@$values > 1) {
	    $sql .= '(' . join(',',@{$values}) . ')';
      } elsif(@$values == 1){
	    $sql = $values->[0];
      }else{
	    $sql = 'NULL';
      }

      return $sql;

}

sub is_null{
      my $self = shift;

      return 0 if $self->count > 1;
      return 1 if !defined( $self->{value}->[0] );
      return 0;
}

sub quoted{
      my $self = shift;
      my $conn = shift or return $self->_error('conn is required');

      if ($self->is_number){
	    return [ map { defined($_)?$_:'NULL' } @{$self->{value}} ];
      }else{
	    return [ map { defined($_)?$_:'NULL' } map { $conn->quote($_) } @{$self->{value}} ];
      }

}

sub raw{ wantarray?@{ $_[0]->{value} } : $_[0]->{value} }

sub _session { $_[0]->{session} }


