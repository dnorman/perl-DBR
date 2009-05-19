# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Object;

use strict;
use base 'DBR::Common';
use DBR::Query::ResultSet;
use DBR::Query::Part;
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
					  conf_instance => $table->conf_instance,
					  extra_ident   => $table->name,
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
				  dbrh   => $self->{dbrh},
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



sub insert {
      my $self = shift;
      my %fields = @_;

      my $table = $self->{table};
      my @sets;
      foreach my $fieldname (keys %fields){

 	    my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");
 	    my $value = $field->makevalue( $fields{ $fieldname } ) or return $self->_error("failed to build value object for $fieldname");

	    my $set = DBR::Query::Part::Set->new($field,$value) or return $self->_error('failed to create set object');
	    push @sets, $set;
      }


      my $query = DBR::Query->new(
				  dbrh   => $self->{dbrh},
				  logger => $self->{logger},
				  insert => {
					     set => \@sets,
					    },
				  tables => $table->name,
				 ) or return $self->_error('failed to create query object');

      return $query->execute();

}


#Fetch by Primary key
sub get{
      my $self = shift;
      my $pkval = shift;

      my $table = $self->{table};
      my $pk = $table->primary_key or return $self->_error('Failed to fetch primary key');
      scalar(@$pk) == 1 or return $self->_error('the get method can only be used with a single field pkey');
      my $field = $pk->[0];

      my $scope = DBR::Config::Scope->new(
					  dbrh          => $self->{dbrh},
					  logger        => $self->{logger},
					  conf_instance => $table->conf_instance
					 ) or return $self->_error('Failed to get calling scope');

      my $prefields = $scope->fields or return $self->_error('Failed to determine fields to retrieve');

      my %uniq;
      my @fields = grep { !$uniq{ $_->field_id }++ } (@$pk, @$prefields);

      my $value = $field->makevalue( $pkval ) or return $self->_error("failed to build value object for ${\$field->name}");

      my $outwhere = DBR::Query::Part::Compare->new( field => $field, value => $value ) or return $self->_error('failed to create compare object');

      my $query = DBR::Query->new(
				  logger => $self->{logger},
				  dbrh   => $self->{dbrh},
				  select => { fields => \@fields },
				  tables => $table->name,
				  where  => $outwhere,
				  scope  => $scope,
				 ) or return $self->_error('failed to create Query object');

      my $resultset = $query->execute() or return $self->_error('failed to execute');

      return $resultset;

}

1;
