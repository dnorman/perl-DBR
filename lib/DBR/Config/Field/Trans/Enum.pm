package DBR::Config::Field::Trans::Enum;

use strict;
use base 'DBR::Common';

my %FIELDMAP;

sub load{
      my( $package ) = shift;
      my %params = @_;

      my $self = { logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $instance  = $params{instance}    || return $self->_error('instance is required');

      my $field_ids = $params{field_id} || return $self->_error('field_id is required');
      $field_ids = [$field_ids] unless ref($field_ids) eq 'ARRAY';

      my $dbh = $instance->connect || return $self->_error("Failed to connect to ${\$instance->name}");

      return $self->_error('Failed to select from enum_map') unless
	my $maps = $dbh->select(
				-table => 'enum_map',
				-fields => 'field_id enum_id',
				-where  => { field_id => ['d in',@$field_ids] },
			       );

      my @enumids = $self->_uniq( map {  $_->{enum_id} } @$maps);

      return $self->_error('Failed to select from enum') unless
	my $values = $dbh->select(
				 -table => 'enum',
				 -fields => 'enum_id handle name override_id',
				 -where  => { enum_id => ['d in',@enumids ] },
				);

      my %VALUES_BY_ID;
      foreach my $value (@$values){
	    my $enum_id = $value->{enum_id};
	    my $id = $value->{override_id} or $enum_id;

	    $VALUES_BY_ID{ $enum_id } = [$id,$value->{handle},$value->{name}];
      }

      foreach my $map (@$maps){
	    my $enum_id = $map->{enum_id};
	    my $value = $VALUES_BY_ID{ $enum_id };

	    my $ref = $FIELDMAP{ $map->{field_id} } ||=[];

	    $ref->[0]->{ $value->[0] } = $value; # Forward
	    $ref->[1]->{ $value->[1] } = $value; # Backward

      }

      return 1;
}


sub new { die "Should not get here" }


sub forward{
      my $self = shift;
      my $id   = shift;
      return $FIELDMAP{ $self->{field_id} }->[0]->{ $id }->[1]; # handle
}

sub backward{
      my $self = shift;
      my $handle = shift;
      return $FIELDMAP{ $self->{field_id} }->[1]->{ $handle }->[0]; # id
}


sub _enum {
      my $self = shift;
      my $context = shift;
      my $field = shift;
      my $flag = shift;

      return $self->_error('must pass in context') unless $context;
      return $self->_error('must pass in field') unless $field;


      return $self->_error('_enumlist failed') unless
	my $enums = $self->_enumlist($context,$field);

      my $lookup = {};
      if($flag eq 'text'){
	    map {  $lookup->{$_->{value}} = $_->{name}  } @{$enums};
      }elsif($flag eq 'reverse'){
	    map {  $lookup->{$_->{value}} = $_->{handle}  } @{$enums};
      }else{
	    map {  $lookup->{$_->{handle}} = $_->{value}  } @{$enums};
      }

      bless $lookup, 'ESRPCommon::EnumHandler';
      return $lookup;
}


1;
