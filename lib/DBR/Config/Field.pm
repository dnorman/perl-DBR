# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Field;

use strict;
use base 'DBR::Config::Field::Common';
use Scalar::Util 'looks_like_number';
use DBR::Query::Part::Value;
use DBR::Config::Table;
use DBR::Config::Trans;
use Clone;
use Carp;

use constant ({
	       # This MUST match the select fomr dbr_fields verbatim
	       C_field_id    => 0,
	       C_table_id    => 1,
	       C_name        => 2,
	       C_data_type   => 3,

	       C_is_nullable => 4, # HERE - consider compressing these using bitmask
	       C_is_signed   => 5,
	       C_is_pkey     => 6,

	       C_trans_id    => 7,
	       C_max_value   => 8,

	       C_is_readonly => 9, # Not in table
	       C_testsub     => 10,

	       # Object fields
	       O_field_id    => 0,
	       O_session     => 1,
	       O_index       => 2,
	       O_table_alias => 3,
	       O_alias_flag  => 4,
	      });

my %VALCHECKS;
my %FIELDS_BY_ID;

#This is ugly... clean it up
my %datatypes = (
		 bigint    => { id => 1, numeric => 1, bits => 64},

		 int       => { id => 2, numeric => 1, bits => 32},
		 integer   => { id => 2, numeric => 1, bits => 32}, # duplicate

		 mediumint => { id => 3, numeric => 1, bits => 24},
		 smallint  => { id => 4, numeric => 1, bits => 16},
		 tinyint   => { id => 5, numeric => 1, bits => 8},
		 bool      => { id => 6, numeric => 1, bits => 1},
		 boolean   => { id => 6, numeric => 1, bits => 1},
		 float     => { id => 7, numeric => 1, bits => 'NA'},
		 double    => { id => 8, numeric => 1, bits => 'NA'},
		 varchar   => { id => 9 },
		 char      => { id => 10 },
		 text      => { id => 11 },
		 mediumtext=> { id => 12 },
		 blob      => { id => 13 },
		 longblob  => { id => 14 },
		 mediumblob=> { id => 15 },
		 tinyblob  => { id => 16 },
		 enum      => { id => 17 }, # I loathe mysql enums
		);

my %datatype_lookup = map { $datatypes{$_}->{id} => {%{$datatypes{$_}}, handle => $_ }} keys %datatypes;

sub list_datatypes{
      return Clone::clone( [ sort { $a->{id} <=> $b->{id} } values %datatype_lookup ] );
}

sub get_type_id{
      my( $package ) = shift;
      my $type = shift;
      my $ref = $datatypes{lc($type)} || return undef;

      return $ref->{id};
}

sub load{
      my( $package ) = shift;
      my %params = @_;

      my $session  = $params{session} || return croak('session is required');
      my $instance = $params{instance} || return croak('instance is required');

      my $table_ids = $params{table_id} || return croak('table_id is required');
      $table_ids = [$table_ids] unless ref($table_ids) eq 'ARRAY';

      return 1 unless @$table_ids;

      my $dbrh = $instance->connect || return croak("Failed to connect to ${\$instance->name}");

      die('Failed to select fields') unless
	my $fields = $dbrh->select(
				   -table => 'dbr_fields',
				   # This MUST match constants above
				   -fields => 'field_id table_id name data_type is_nullable is_signed is_pkey trans_id max_value', 
				   -where  => { table_id => ['d in',@$table_ids] },
				   -arrayref => 1,
				  );


      my @trans_fids;
      foreach my $field (@$fields){
	    # Consider adding another config param: is_readonly

	    $field->[C_is_readonly] = 1 if $field->[C_is_pkey];

	    DBR::Config::Table->_register_field(
						table_id => $field->[C_table_id],
						name     => $field->[C_name],
						field_id => $field->[C_field_id],
						is_pkey  => $field->[C_is_pkey] ? 1 : 0,
					       ) or die('failed to register field');


	    $field->[C_testsub] = _gen_valcheck($field) or die('failed to generate value checking routine');

	    $FIELDS_BY_ID{ $field->[C_field_id] } = $field;
	    push @trans_fids, $field->[C_field_id] if $field->[C_trans_id];
      }

      if (@trans_fids){

	    DBR::Config::Trans->load(
				     session => $session,
				     instance => $instance,
				     field_id => \@trans_fids,
				    ) or return die('failed to load translators');

      }

      return 1;
}

sub _gen_valcheck{
      my $fieldref = shift;
      my $dt = $datatype_lookup{ $fieldref->[C_data_type] };

      my @code;
      if($dt->{numeric}){
	    push @code, 'looks_like_number($v)';

	    if($dt->{bits} ne 'NA'){ # can't really range check floats and such things
		  my ($min,$max) = (0, 2 ** $dt->{bits});

		  if($fieldref->[C_is_signed]){  $max /= 2; $min = 0 - $max }
		  push @code, "\$v >= $min", '$v <= ' . ($max - 1);
	    }
      }else{
	    push @code, 'defined($v)' unless $fieldref->[C_is_nullable];
	    if ($fieldref->[C_max_value] =~ /^\d+$/){ # use regex to prevent code injection
		  my $max = $fieldref->[C_max_value];
		  push @code, "length(\$v)<= $max";
	    }

      }

      my $code = join(' && ', @code);
      $code = "!defined(\$v)||($code)" if $fieldref->[C_is_nullable];

      #print " $fieldref->[C_name] => $code \n" if $fieldref->[C_table_id] == 64;
      return $VALCHECKS{$code} ||= eval 'sub { my $v = shift ; ' . $code . ' }' || die "DBR::Config::Field::_get_valcheck: failed to gen sub '$@'";
}


####################################################################################################
####################################################################################################
####################################################################################################
####################################################################################################



sub new {
      my $package = shift;
      my %params = @_;

      # Order must match O_ constants
      my $self = [$params{field_id}, $params{session}];

      bless( $self, $package );

      return $self->_error('field_id is required') unless $self->[O_field_id];
      return $self->_error('session is required' ) unless $self->[O_session];

      $FIELDS_BY_ID{ $self->[O_field_id] } or return $self->_error('invalid field_id');

      return( $self );
}

sub clone{
      my $self = shift;
      my %params = @_;

      return bless(
		   [
		    $self->[O_field_id],
		    $self->[O_session],
		    $params{with_index} ? $self->[O_index]        : undef, # index
		    $params{with_alias} ? $self->[O_table_alias]  : undef, #alias
		   ],
		   ref($self),
		  );

}

sub makevalue{ # shortcut function?
      my $self = shift;
      my $value = shift;

      return DBR::Query::Part::Value->new(
					  session   => $self->[O_session],
					  value     => $value,
					  is_number => $self->is_numeric,
					  field     => $self,
					 );# or return $self->_error('failed to create value object');

}

sub field_id     { $_[0]->[O_field_id] }
sub table_id     { $FIELDS_BY_ID{  $_[0]->[O_field_id] }->[C_table_id]    }
sub name         { $FIELDS_BY_ID{  $_[0]->[O_field_id] }->[C_name]        }
sub is_pkey      { $FIELDS_BY_ID{  $_[0]->[O_field_id] }->[C_is_pkey]     }
sub is_readonly  { $FIELDS_BY_ID{  $_[0]->[O_field_id] }->[C_is_readonly] }
sub testsub      { $FIELDS_BY_ID{  $_[0]->[O_field_id] }->[C_testsub]     }

sub table    {
      return DBR::Config::Table->new(
				     session   => $_[0][O_session],
				     table_id => $FIELDS_BY_ID{  $_[0][O_field_id] }->[C_table_id]
				    );
}

sub is_numeric{
      my $field = $FIELDS_BY_ID{ $_[0]->[O_field_id] };
      return $datatype_lookup{ $field->[C_data_type] }->{numeric} ? 1:0;
}

sub translator{
      my $self = shift;

      my $trans_id = $FIELDS_BY_ID{ $self->[O_field_id] }->[C_trans_id] or return undef;

      return DBR::Config::Trans->new(
				     session  => $self->[O_session],
				     field_id => $self->[O_field_id],
				     trans_id => $trans_id,
				    );
}


### Admin functions

sub update_translator{
      my $self = shift;
      my $transname = shift;

      $self->[O_session]->is_admin or return $self->_error('Cannot update translator in non-admin mode');

      my $existing_trans_id = $FIELDS_BY_ID{ $self->[O_field_id] }->[C_trans_id];

      my $trans_defs = DBR::Config::Trans->list_translators or die 'Failed to get translator list';

      my %trans_lookup;
      map {$trans_lookup{ uc($_->{name}) } = $_}  @$trans_defs;
      my $new_trans = $trans_lookup{ uc ($transname) } or die "Invalid translator '$transname'";

      return 1 if $existing_trans_id && $new_trans->{id} == $existing_trans_id;


      my $instance = $self->table->conf_instance or die "Failed to retrieve conf instance";
      my $dbrh     = $instance->connect or die "Failed to connect to conf instance";

      $dbrh->update(
		    -table  => 'dbr_fields',
		    -fields => { trans_id => ['d', $new_trans->{id} ]},
		    -where  => { field_id => ['d', $self->field_id  ]}
		   ) or die "Failed to update dbr_fields";

      $FIELDS_BY_ID{ $self->[O_field_id] }->[C_trans_id] = $new_trans->{id}; # update local copy

      return 1;
}

1;
