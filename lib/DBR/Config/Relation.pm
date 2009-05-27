# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Relation;

use strict;
use base 'DBR::Common';
use DBR::Query::Value;
use DBR::Config::Table;
use DBR::Config::Field;

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
				      -fields => 'relationship_id from_name from_table_id from_field_id to_name to_table_id to_field_id type',
				      -where  => { from_table_id => ['d in',@$table_ids] },
				     );

      my @rel_ids;
      foreach my $relation (@$relations){

	    DBR::Config::Table->_register_relation(
						   table_id    => $relation->{to_table_id},
						   name        => $relation->{from_name}, #yes, this is kinda confusing
						   relation_id => $relation->{relationship_id},
						  ) or return $self->_error('failed to register to relationship');

	    DBR::Config::Table->_register_relation(
						   table_id    => $relation->{from_table_id},
						   name        => $relation->{to_name}, #yes, this is kinda confusing
						   relation_id => $relation->{relationship_id},
						  ) or return $self->_error('failed to register from relationship');

	    $RELATIONS_BY_ID{ $relation->{relationship_id} } = $relation;
	    push @rel_ids, $relation->{relationship_id};
      }

      return 1;
}


sub new {
      my $package = shift;
      my %params = @_;
      my $self = {
		  logger      => $params{logger},
		  relation_id => $params{relation_id},
		  table_id    => $params{table_id},
		 };

      bless( $self, $package );

      return $self->_error('relation_id is required') unless $self->{relation_id};
      return $self->_error('table_id is required')    unless $self->{table_id};


      my $ref = $RELATIONS_BY_ID{ $self->{relation_id} } or return $self->_error('invalid relation_id');

      if($ref->{from_table_id} == $self->{table_id}){

	    $self->{forward} = 'from';
	    $self->{reverse} = 'to';

      }elsif($ref->{to_table_id} == $self->{table_id}){

	    $self->{forward} = 'to';
	    $self->{reverse} = 'from';

      }else{
	    return $self->_error("table_id $self->{table_id} is invalid for this relationship");
      }

      return( $self );
}

sub relation_id { $_[0]->{relation_id} }
sub name     { $RELATIONS_BY_ID{  $_[0]->{relation_id} }->{ $_[0]->{reverse}  . '_name' }    } # Name is always the opposite of everything else

sub field_id {
      my $self = shift;

      return $RELATIONS_BY_ID{  $self->{relation_id} }->{ $self->{forward}  . '_field_id' };
}

sub mapfield {
      my $self = shift;
      my $mapfield_id = $RELATIONS_BY_ID{  $self->{relation_id} }->{ $self->{reverse}  . '_field_id' };

      my $field = DBR::Config::Field->new(
					  logger   => $self->{logger},
					  field_id => $mapfield_id,
					 ) or return $self->_error('failed to create field object');

      return $field;
}
sub maptable {
      my $self = shift;

      return DBR::Config::Table->new(
				     logger   => $self->{logger},
				     table_id => $RELATIONS_BY_ID{  $self->{relation_id} }->{$self->{reverse} . '_table_id'}
				    );
}

1;
