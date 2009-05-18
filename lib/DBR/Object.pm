# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Object;

use strict;
use base 'DBR::Common';
use DBR::Query::ResultSet;
use DBR::Query::Part;
use DBR::Operators;
use DBR::Config::Scope;


sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		  dbrh   => $params{dbrh},
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

      my $table = $self->{table};
      my $scope = DBR::Config::Scope->new(
					  dbrh          => $self->{dbrh},
					  logger        => $self->{logger},
					  offset        => 1,
					  conf_instance => $table->conf_instance
					 ) or return $self->_error('Failed to get calling scope');



      my $pk = $table->primary_key or return $self->_error('Failed to fetch primary key');
      my $prefields = $scope->fields or return $self->_error('Failed to determine fields to retrieve');

      my %uniq;
      my @fields = grep { !$uniq{ $_->field_id }++ } (@$pk, @$prefields);

      my @and;
      foreach my $fieldname (keys %inwhere){

 	    my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");

 	    my $value = $field->makevalue( $inwhere{ $fieldname } ) or return $self->_error("failed to build value object for $fieldname");

	    my $outfield = DBR::Query::Part::Compare->new(
							  field => $field,
							  value => $value
							 ) or return $self->_error('failed to create compare object');

	    push @and, $outfield;
      }

      my $outwhere = DBR::Query::Part::And->new(@and);

      my $query = DBR::Query->new(
				  logger => $self->{logger},
				  dbrh    => $self->{dbrh},
				  select => {
					     fields => \@fields
					    },
				  tables => $table->name,
				  where  => $outwhere,
				  scope  => $scope,
				 ) or return $self->_error('failed to create Query object');

      my $resultset = $query->execute() or return $self->_error('failed to execute');

      return $resultset;
}

#Fetch by Primary key
sub fetch{
      
}

1;
