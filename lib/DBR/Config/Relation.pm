# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Relation;

use strict;
use base 'DBR::Common';
use DBR::Query::Value;
use DBR::Config::Table;

my %TYPES = (
	     1 => {name => 'parent', opposite => 'child'},
	     2 => {name => 'child',  opposite => 'parent'},
	     3 => {name => 'assoc'},
	     4 => {name => 'other'},
	    );
my %RELATIONS_BY_ID;
sub load{
      my( $package ) = shift;
      my %params = @_;

      my $self = { logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $instance = $params{instance} || return $self->_error('instance is required');

      my $table_ids = $params{table_id} || return $self->_error('table_id is required');
      $table_ids = [$table_ids] unless ref($table_ids) eq 'ARRAY';

      return 1 unless @$table_ids;

      my $dbrh = $instance->connect || return $self->_error("Failed to connect to ${\$instance->name}");

      return $self->_error('Failed to select from dbr_relationships') unless
	my $relations = $dbrh->select(
				      -table => 'dbr_relationships',
				      -fields => 'relationship_id to_name from_name from_table_id to_table_id type',
				      -where  => { from_table_id => ['d in',@$table_ids] },
				     );

      my @rel_ids;
      foreach my $relation (@$relations){

	    DBR::Config::Table->_register_relation(
						   table_id    => $relation->{to_table_id},
						   name        => $relation->{to_name},
						   relation_id => $relation->{relationship_id},
						  ) or return $self->_error('failed to register to relationship');

	    DBR::Config::Table->_register_relation(
						   table_id    => $relation->{from_table_id},
						   name        => $relation->{from_name},
						   relation_id => $relation->{relationship_id},
						  ) or return $self->_error('failed to register from relationship');

	    $RELATIONS_BY_ID{ $relation->{relationship_id} } = $relation;
	    push @rel_ids, $relation->{relationship_id};
      }

      if(@rel_ids){
	    return $self->_error('Failed to select from dbr_field_map') unless
	      my $maps = $dbrh->select(
				       -table => 'dbr_field_map',
				       -fields => 'map_id relationship_id from_field_id to_field_id',
				       -where  => { table_id => ['d in',@$table_ids] },
				      );
	    foreach my $map (@{$maps}){
		  my $ref = $RELATIONS_BY_ID{ $map->{relationship_id} }->{maps} ||=[];
		  push @$ref, $map;
	    }
      }

      return 1;
}


sub new {
      my $package = shift;
      my %params = @_;
      my $self = {
		  logger      => $params{logger},
		  relation_id => $params{relation_id},
		 };

      bless( $self, $package );

      return $self->_error('relation_id is required') unless $self->{relation_id};

      $RELATIONS_BY_ID{ $self->{relation_id} } or return $self->_error('invalid relation_id');

      return( $self );
}

sub relation_id { $_[0]->{relation_id} }
#sub table_id { $FIELDS_BY_ID{  $_[0]->{field_id} }->{table_id}    }
#sub name     { $FIELDS_BY_ID{  $_[0]->{field_id} }->{name}    }


1;
