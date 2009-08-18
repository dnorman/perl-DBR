#!/usr/bin/perl

# example usage:  perl -I../lib conf/dbr.conf car_dealer

use lib qw'../lib ../../lib';
use DBR::Util::Logger;
use DBR::Config::Trans;
use DBR::Config::Relation;

use DBR;
use strict;

my ($conffile, $schemaname, $tablename) = @ARGV;
my $confdb ||= 'dbrconf';

my $logger = new DBR::Util::Logger(-logpath => '/tmp/dbr_dumpspec.log', -logLevel => 'debug3');
my $dbr    = new DBR(
		     -logger => $logger,
		     -conf   => $conffile,
		    );


my $trans_defs = DBR::Config::Trans->list_translators or die 'Failed to get translator list';
my %trans_lookup; map {$trans_lookup{$_->{id}} = $_}  @$trans_defs;

my $relationtype_defs = DBR::Config::Relation->list_types or die 'Failed to get relationship type list';
my %relationtype_lookup; map {$relationtype_lookup{$_->{type_id}} = $_}  @$relationtype_defs;

my $dbrh = $dbr->connect($confdb) or die "No config found for confdb $confdb";


# Translators
# Relationships
# Enums

my $schema = $dbrh->select(
			   -table => 'dbr_schemas',
			   -fields => 'schema_id handle display_name',
			   -where  => { handle => $schemaname },
			   -single => 1,
			  ) or die('Schema not found');

my $table = $dbrh->select(
			  -table  => 'dbr_tables',
			  -fields => 'table_id schema_id name',
			  -where  => {
				      schema_id => ['d', $schema->{schema_id} ],
				      name      => $tablename
				     },
			  -single => 1,
			 ) or die('Table not found');

my $fields = $dbrh->select(
			   -table => 'dbr_fields',
			   -fields => 'field_id table_id name data_type is_nullable is_signed is_pkey trans_id max_value',
			   -where  => { table_id => ['d',$table->{table_id} ] },
			  ) or die('Failed to select fields');

die "No fields present" unless @$fields;

my @fieldids = map { $_->{field_id} } @$fields;

##### Enums


my $enum_maps = $dbrh->select(
			      -table => 'enum_map',
			      -fields => 'row_id field_id enum_id sortval',
			      -where  => { field_id => ['d in', @fieldids ] },
			     ) or die('Failed to select enum_maps');


my @enumids = uniq( map { $_->{enum_id} } @$enum_maps );

my %enum_map_lookup;
map {push @{  $enum_map_lookup{$_->{field_id}}  }, $_ } @$enum_maps;

my $enum_lookup;
if(@enumids){
      $enum_lookup = $dbrh->select(
				   -table => 'enum',
				   -fields => 'enum_id handle name override_id',
				   -where  => { enum_id => ['d in',  @enumids] },
				   -keycol => 'enum_id',
				  ) or die('Failed to select enums');
}


##### Relationships
my $relationships = $dbrh->select(
				  -table => 'dbr_relationships',
				  -fields => 'relationship_id from_name from_table_id from_field_id to_name to_table_id to_field_id type',
				  -where  => { from_field_id => ['d in', @fieldids ] },
				 ) or die('Failed to select relationships');

my %relation_map;
map {push @{    $relation_map{ $_->{from_field_id} }    }, $_ } @$relationships;

my @rfield_ids = uniq( map { $_->{to_field_id} } @$relationships );

my $rfield_lookup;
if(@rfield_ids){
      $rfield_lookup = $dbrh->select(
				     -table => 'dbr_fields',
				     -fields => 'field_id table_id name',
				     -where  => { field_id => ['d in', @rfield_ids] },
				     -keycol => 'field_id',
				    ) or die('Failed to select related tables');
}


my @rtableids = uniq( map { $_->{table_id} } values %$rfield_lookup );

my $rtable_lookup;
if(@rtableids){
      $rtable_lookup = $dbrh->select(
				     -table => 'dbr_tables',
				     -fields => 'table_id name',
				     -where  => { table_id => ['d in', @rtableids] },
				     -keycol => 'table_id',
				    ) or die('Failed to select related tables');
}


#schema table field directive value1 value2...


foreach my $field (@$fields){
      my @prefix = (
		    schema => $schemaname,
		    table  => $tablename,
		    field  => $field->{name}
		   );


      if($field->{trans_id}){
	    my $transtype = uc($trans_lookup{  $field->{trans_id}  }->{name} || "Unknown");
	    line(
		 @prefix,
		 cmd        => 'TRANSLATOR',
		 translator => $transtype
		);

	    if ($transtype eq 'ENUM'){
		  my $mappings = $enum_map_lookup{ $field->{field_id} };
		  foreach my $mapping ( sort { $a->{sortval} <=> $b->{sortval} } @$mappings) {
			my $enum = $enum_lookup->{ $mapping->{enum_id} };

			line(
			     @prefix,
			     cmd     => 'ENUMOPT',
			     handle  => $enum->{handle},
			     enum_id =>$enum->{enum_id},
			     override_id => $enum->{override_id} || 'NULL',
			     name    => $enum->{name},
			    );
		  }
	    }
      }

      my $relations = $relation_map{ $field->{field_id} };
      if($relations){
	    foreach my $relation (@$relations){
		  my $rfield  = $rfield_lookup->{ $relation->{to_field_id} };
		  my $rtable = $rtable_lookup->{ $rfield->{table_id} };
		  my $typename = uc($relationtype_lookup{ $relation->{type} }->{name} || 'Unknown');
		  line(
		       @prefix,
		       cmd      => 'RELATION',
		       reltable => $rtable->{name},
		       relfield => $rfield->{name},
		       relname  => $relation->{to_name},
		       revname  => $relation->{from_name},
		       type     => $typename,
		      );
	    }
      }

}


sub line{
      my @pairs;
      while (@_){
	    my ($field,$value) = (shift,shift);
	    die "Illegal character in fieldname" if $field =~ /\t/;
	    die "Illegal character in value"     if $value =~ /\t/;
	    push @pairs, $field . '=' . $value;
      }
      print join("\t",@pairs) . "\n";
}


sub uniq{

      my %uniq;

      return grep {!$uniq{$_}++} @_;

}
