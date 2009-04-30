# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Field;

use strict;
use base 'DBR::Common';

sub new{
      my( $package ) = shift;
      my %params = @_;

      my $field;

      my $table = $params{table};
      my $name = $params{field} or return $self->_error('field is required');

      my @parts = split(/\./,$name);
      if(scalar(@parts) == 1){
	    ($field) = @parts;
      }elsif(scalar(@parts) == 2){
	    return $self->_error("illegal use of table parameter with table.field notation") if length($table);
	    ($table,$field) = @parts;
      }else{
	    return $self->_error('Invalid name');
      }

      my $translate = $params{translate};
      if(defined($translate)){
	    return $self->_error('translate flag must be a coderef') unless ref($translate) eq 'CODE';
      }

      my $sql = $table;
      $sql .= '.' if $sql;
      $sql .= $field;


      my $self = [$table,$field,$sql,$translate];

      bless( $self, $package );

      return $self;
}

sub table{ $_[0]->[0] }
sub field{ $_[0]->[1] }
sub sql  { $_[0]->[2] }

sub validate { 1 }
