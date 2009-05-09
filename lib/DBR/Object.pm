# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Object;

use strict;
use base 'DBR::Common';
use DBR::Query::ResultSet;
use DBR::Operators;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		  dbrh    => $params{dbrh},
		  table  => $params{table},
		 };

      bless( $self, $package );

      return $self->_error('table object must be specified') unless ref($self->{table}) eq 'DBR::Config::Table';
      return $self->_error('dbrh object must be specified')   unless $self->{dbrh};

      return( $self );
}


sub where{
      my $self = shift;
      my %inwhere = @_;

      # Use caller information to determine selected fields
      my ( $package, $filename, $line, $method) = caller(1);

      # LOOKUP FIELDS HERE


      my $table = $self->{table};
      my @and;
      foreach my $fieldname (keys %inwhere){

 	    my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");

 	    my $value = $field->makevalue( $inwhere{ $fieldname } ) or return $self->_error("failed to build value object for $fieldname");

	    my $outfield = DBR::Query::Where::COMPARE->new($field->name, $value) or return $self->_error('failed to create compare object');

	    push @and, $outfield;
      }

      my $outwhere = DBR::Query::Where::AND->new(@and);

      my $query = DBR::Query->new(
				  logger => $self->{logger},
				  dbrh    => $self->{dbrh},
				  tables => $table->name,
				  where  => $outwhere,
				 ) or return $self->_error('failed to create Query object');
      $query->select(
		     fields => scalar($table->fields)
		    ) or return $self->_error('Failed to set up select');

      my $resultset = $query->execute() or return $self->_error('failed to execute');

      return $resultset;
}

#Fetch by Primary key
sub fetch{
}

1;
