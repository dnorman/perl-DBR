# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Table;

use strict;
use base 'DBR::Common';

use DBR::Config::Field;


my %TABLES_BY_ID;
my %FIELDS_BY_NAME;

sub load{
      my( $package ) = shift;
      my %params = @_;

      my $self = { logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $dbr    = $params{dbr}    || return $self->_error('dbr is required');
      my $handle = $params{handle} || return $self->_error('handle is required');
      my $class  = $params{class}  || return $self->_error('class is required');

      my $schema_ids = $params{schema_id} || return $self->_error('schema_id is required');
      $schema_ids = [$schema_ids] unless ref($schema_ids) eq 'ARRAY';

      my $dbh = $dbr->connect($handle,$class) || return $self->_error("Failed to connect to '$handle','$class'");



      return $self->_error('Failed to select instances') unless
	my $tables = $dbh->select(
				  -table  => 'dbr_tables',
				  -fields => 'table_id schema_id name',
				  -where  => { schema_id => ['d in', @{$schema_ids}] },
				 );

      my @table_ids;
      foreach my $table (@$tables){

	    DBR::Config::Schema->_register_table(
							      schema_id => $table->{schema_id},
							      name      => $table->{name},
							      table_id  => $table->{table_id},
							     ) or return $self->_error('failed to register table');

	    $TABLES_BY_ID{ $table->{table_id} } = $table;
	    push @table_ids, $table->{table_id};
      }

      DBR::Config::Field->load(
					    logger => $self->{logger},
					    dbr    => $dbr,
					    handle => $handle,
					    class  => $class,
					    table_id => \@table_ids,
					   ) or return $self->_error('failed to load fields');

      return 1;
}

sub _register_field{
      my $package = shift; # no dummy $self object here, for efficiency
      my %params = @_;

      my $table_id = $params{table_id} or return $package->_error('table_id is required');
      $TABLES_BY_ID{ $table_id } or return $package->_error('invalid table_id');

      my $table_id = $params{table_id} or return $package->_error('table_id is required');
      my $name     = $params{name}     or return $package->_error('name is required');
      my $field_id = $params{field_id} or return $package->_error('field_id is required');

      $FIELDS_BY_NAME{ $table_id } -> { $name } = $field_id;

      return 1;
}

sub new {
  my( $package ) = shift;
  my %params = @_;
  my $self = {
	      logger   => $params{logger},
	      table_id => $params{table_id}
	     };

  bless( $self, $package );

  return $self->_error('table_id is required') unless $self->{table_id};

  $TABLES_BY_ID{ $self->{table_id} } or return $self->_error("table_id $self->{table_id} doesn't exist");

  return( $self );
}

sub name { $TABLES_BY_ID{  $_[0]->{table_id} }->{name} };

1;
