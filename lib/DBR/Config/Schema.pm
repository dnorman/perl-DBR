# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Schema;

use strict;
use base 'DBR::Common';

use DBR::Config::Table;
use Clone;

my %TABLES_BY_NAME;
my %SCHEMAS_BY_ID;
my %SCHEMAS_BY_HANDLE;

sub load{
      my( $package ) = shift;
      my %params = @_;

      my $self = { session => $params{session} };
      bless( $self, $package ); # Dummy object

      my $instance = $params{instance} || return $self->_error('instance is required');

      my $dbrh = $instance->connect || return $self->_error("Failed to connect to ${\$instance->name}");

      my $schema_ids = $params{schema_id} || return $self->_error('schema_id is required');
      $schema_ids = [$schema_ids] unless ref($schema_ids) eq 'ARRAY';

      return 1 unless @$schema_ids;

      return $self->_error('Failed to select instances') unless
	my $schemas = $dbrh->select(
				    -table => 'dbr_schemas',
				    -fields => 'schema_id handle display_name',
				    -where  => { schema_id => ['d in', @{$schema_ids}] },
				   );

      my @schema_ids; # track the schema ids from this request seperately from the global cache
      foreach my $schema (@$schemas){
	    $SCHEMAS_BY_ID{  $schema->{schema_id} } = $schema;
	    $SCHEMAS_BY_HANDLE{ $schema->{handle} } = $schema->{schema_id};

	    push @schema_ids, $schema->{schema_id};
      }

      DBR::Config::Table->load(
			       session => $self->{session},
			       instance => $instance,
			       schema_id => \@schema_ids,
			      ) or return $package->_error('failed to load tables');

      return 1;
}

sub list_schemas {
      return Clone::clone( [ sort { ($a->{display_name} || '') cmp ($b->{display_name} || '') } values %SCHEMAS_BY_ID ] );
}

sub _register_table{
      my $package = shift; # no dummy $self object here, for efficiency
      my %params = @_;

      my $schema_id = $params{schema_id} or return $package->_error('schema_id is required');
      $SCHEMAS_BY_ID{ $schema_id } or return $package->_error('invalid schema_id');

      my $name      = $params{name}      or return $package->_error('name is required');
      my $table_id  = $params{table_id}  or return $package->_error('table_id is required');

      $TABLES_BY_NAME{ $schema_id } -> { $name } = $table_id;

      return 1;
}

###################### BEGIN OBJECT ORIENTED CODE ######################

sub new {
  my( $package ) = shift;
  my %params = @_;
  my $self = {
	      session    => $params{session},
	     };

  bless( $self, $package );

  return $self->_error('session is required') unless $self->{session};

  if ($params{schema_id}){
	$self->{schema_id} = $params{schema_id};
  }elsif($params{handle}){
	$self->{schema_id} = $SCHEMAS_BY_HANDLE{ $params{handle} } or return $self->_error("handle $params{handle} is invalid");
  }else{
	return $self->_error('schema_id is required');
  }

  return $self->_error("schema_id $self->{schema_id} is not defined") unless $SCHEMAS_BY_ID{ $self->{schema_id} };

  return( $self );
}

sub get_table{
      my $self  = shift;
      my $tname = shift or return $self->_error('name is required');

      my $table_id = $TABLES_BY_NAME{ $self->{schema_id} } -> { $tname } || return $self->_error("table $tname does not exist");

      my $table = DBR::Config::Table->new(
					  session   => $self->{session},
					  table_id => $table_id,
					 ) or return $self->_error('failed to create table object');
      return $table;
}

sub tables{
      my $self  = shift;

      my @tables;

      foreach my $table_id (    values %{$TABLES_BY_NAME{ $self->{schema_id}} }   ) {

	    my $table = DBR::Config::Table->new(
						session   => $self->{session},
						table_id => $table_id,
					       ) or return $self->_error('failed to create table object');
	    push @tables, $table;
      }


      return \@tables;
}

sub schema_id {
      my $self = shift;
      return $self->{schema_id};
}

sub handle {
      my $self = shift;
      my $schema = $SCHEMAS_BY_ID{ $self->{schema_id} } or return $self->_error( 'lookup failed' );
      return $schema->{handle};
}

sub display_name {
      my $self = shift;
      my $schema = $SCHEMAS_BY_ID{ $self->{schema_id} } or return $self->_error( 'lookup failed' );
      return $schema->{display_name} || '';
}


# browse( %params )
#   with_ids => 1 ... includes schema, table and field ids

# slurp the data for a schema in to the following data structure.
# intended for transfer to heavy clients for real-time traversal.
# see bin/dbr-browse for an example of a simple terminal client.
# the objective here is not efficiency, but ease of use by author.

# {
#   schema : {
#     id : <id>
#     handle : <schema-handle>
#     display : <display-name>
#     tables : [
#       {
#         id : <id>
#         name : <table-name>
#         fields : [
#           {
#             id : <id>
#             name : <db-name>
#             type : <type-name>
#             trans : <translator-name>
#             via : <name>
#             to : <table-path>     /* target table-name.field-name */
#             enums : [ <handle> ... ]
#             pkey : 1
#             ro : 1
#           }
#           ...   /* more fields */
#         ]
#         from : [
#           {
#             via : <name>
#             path : <field-path>   /* referring table-name.field-name */
#           }
#           ...   /* more froms */
#         ]
#       }
#       ...   /* more tables */
#     ]
#   }
#   type_lookup : {
#     <type-name> : {
#       ?
#     }
#     ...   /* more types */
#   }
#   trans_lookup : {
#     <translator-name> : {
#       ?
#     }
#     ...   /* more translators */
#   }
#   enum_lookup : {
#     <handle> : {
#       display : <display-value>
#       value : <enum-id>
#       override : <override-value>
#     }
#     ...   /* more enums */
#   }
# }

# client is expected to build needed lookups after receiving the data.
# if lookups are embedded in the data, they should follow the convention
# of using an underscore-prefixed name, so that utility functions can
# easily strip this data if needed (e.g. dumper, jsonify)

sub browse {
      my $self = shift;
      my %params = @_;

      my $translators = DBR::Config::Trans->list_translators;  # keys: id,name
      my %trans_map = map { $_->{id} => $_ } @{$translators};

      my $types = DBR::Config::Field->list_datatypes;  # keys: handle,id,[numeric],[bits]
      my %type_map = map { $_->{id} => $_ } @{$types};

      my $info = {};

      # schema
      $info->{schema} = {
                         handle  => $self->handle,
                         display => $self->display_name,
                        };
      $info->{schema}->{id} = $self->{schema_id} if $params{with_ids};

      # schema tables
      my $tables = $self->tables or return $self->_error( 'failed to get tables' );
      my $tmap = {};
      my $fmap = {};
      my %enums_seen = ();
      foreach my $table (@{$tables}) {
            my $table_id = $table->table_id;
            push @{$info->{schema}->{tables} ||= []},
              $tmap->{$table_id} = {
                                    name => $table->name,
                                   };
            $tmap->{$table_id}->{id} = $table_id if $params{with_ids};

            # table fields
            my $fields = $table->fields or return $self->_error( 'failed to get fields' );
            foreach my $field (@{$fields}) {
                  my $field_id = $field->field_id;
                  push @{$tmap->{$table_id}->{fields} ||= []},
                    $fmap->{$field_id} = {
                                          name  => $field->name,
                                          type  => $type_map{$field->datatype}->{handle},
                                         };
                  $fmap->{$field_id}->{id}   = $field_id if $params{with_ids};
                  $fmap->{$field_id}->{pkey} = 1 if $field->is_pkey;
                  $fmap->{$field_id}->{ro}   = 1 if $field->is_readonly;

                  if (my $trans = $field->translator) {
                        my $tname = $trans_map{$trans->trans_id}->{name};
                        $fmap->{$field_id}->{trans} = $tname;
                        if ($tname eq 'Enum') {
                              foreach my $opt (@{ $trans->options }) {
                                    $enums_seen{$opt->handle} = $opt->name;
                                    push @{ $fmap->{$field_id}->{enums} ||= [] }, $opt->handle;
                              }
                        }
                  }
                  # if enum...
            }
      }
      foreach my $table (@{$tables}) {
            my $table_id = $table->table_id;
            my $trec = $tmap->{$table_id} or return $self->_error( 'table lookup failed' );

            # table relations
            my $relations = $table->relations or return $self->_error( 'failed to get table relations' );
            foreach my $relation (@{$relations}) {
                  my $path = $relation->maptable->name . '.' . $relation->mapfield->name;
                  if ($relation->is_to_one) {
                        $fmap->{$relation->field_id}->{to}  = $path;
                        $fmap->{$relation->field_id}->{via} = $relation->name;
                        $fmap->{$relation->field_id}->{rel_id} = $relation->relation_id if $params{with_ids};
                  }
                  else {
                        my $rrec = {
                                    via  => $relation->name,
                                    path => $path,
                                   };
                        $rrec->{rel_id} = $relation->relation_id if $params{with_ids};
                        push @{$trec->{from} ||= []}, $rrec;
                  }
            }
      }

      # types
      $info->{type_lookup}  = { map { $_->{handle} => $_ } @{$types}       };

      # translators
      $info->{trans_lookup} = { map { $_->{name}   => $_ } @{$translators} };

      # enums
      $info->{enums} = \%enums_seen;

      return $info;
}

1;
