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

      my $self = {
		  logger => $params{logger},
		 };

      bless( $self, $package );

      my $table = $params{table};
      my $name = $params{name} or return $self->_error('field is required');

      my @parts = split(/\./,$name);
      if(scalar(@parts) == 1){
	    ($field) = @parts;
      }elsif(scalar(@parts) == 2){
	    return $self->_error("illegal use of table parameter with table.field notation") if length($table);
	    ($table,$field) = @parts;
      }else{
	    return $self->_error('Invalid name');
      }

      return $self->_error("invalid field name '$field'") unless $field =~ /^[A-Z][A-Z0-9_-]*$/i;

      if($table){
	    return $self->_error("invalid table name '$table'") unless $table =~ /^[A-Z][A-Z0-9_-]*$/i;
      }

      $self->{table} = $table;
      $self->{field} = $field;

      my $translate = $params{translate};
      if(defined($translate)){
	    return $self->_error('translate flag must be a coderef') unless ref($translate) eq 'CODE';
      }

      my $sql = $table;
      $sql .= '.' if $sql;
      $sql .= $field;

      if ( $params{dealias} ) {
	    $sql .= " AS $field";
      } elsif ( $params{alias} ) {
	    $sql .= " AS '$table.$field'";
      }
      $self->{sql} = $sql;


      return $self;
}

sub table{ $_[0]->{table} }
sub name{ $_[0]->{field} }
sub sql  { $_[0]->{sql} }
sub index{ $_[0]->{index} }
sub set_index{ $_[0]->{index} = $_[1] }
sub validate { 1 }

1;
