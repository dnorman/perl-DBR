# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Field::Anon;

use strict;
use base 'DBR::Config::Field::Common';

sub new{
      my( $package ) = shift;
      my %params = @_;

      my $field;

      my $self = {
		  logger => $params{logger},
		 };

      bless( $self, $package );

      my $table = $params{table};

      my $name = $params{name} or return $self->_error('name is required');

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

      $self->{table_alias} = $table;
      $self->{field} = $field;

      my $sql = $table;
      $sql .= '.' if $sql;
      $sql .= $field;

      $self->{sql} = $sql;


      return $self;
}

sub clone{
      my $self = shift;
      return bless(
		   {
		    logger      => $self->{logger},
		    field       => $self->{field},
		    table_alias => $self->{table_alias},
		    sql         => $self->{sql}
		   },
		   ref($self),
	   );
}

sub name { $_[0]->{field} }

1;
