package DBR::Config::Trans::Enum;

use strict;
use base 'DBR::Common';
use Clone qw(clone);

my %FIELDMAP;

sub load{
      my( $package ) = shift;
      my %params = @_;

      my $self = { logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $instance  = $params{instance}    || return $self->_error('instance is required');

      my $field_ids = $params{field_id} || return $self->_error('field_id is required');
      $field_ids = [$field_ids] unless ref($field_ids) eq 'ARRAY';

      my $dbrh = $instance->connect || return $self->_error("Failed to connect to ${\$instance->name}");

      return $self->_error('Failed to select from enum_map') unless
	my $maps = $dbrh->select(
				 -table => 'enum_map',
				 -fields => 'field_id enum_id',
				 -where  => { field_id => ['d in',@$field_ids] },
				);

      my @enumids = $self->_uniq( map {  $_->{enum_id} } @$maps);

      return $self->_error('Failed to select from enum') unless
	my $values = $dbrh->select(
				   -table => 'enum',
				   -fields => 'enum_id handle name override_id',
				   -where  => { enum_id => ['d in',@enumids ] },
				  );

      my %VALUES_BY_ID;
      foreach my $value (@$values){
	    my $enum_id = $value->{enum_id};
	    my $id = $value->{override_id} or $enum_id;

	    $VALUES_BY_ID{ $enum_id } = [$id,$value->{handle},$value->{name}]; # 
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
      return bless( clone( $FIELDMAP{ $self->{field_id} }->[0]->{ $id }) , 'DBR::_ENUM');
}

sub backward{
      my $self = shift;
      my $handle = shift;
      return $FIELDMAP{ $self->{field_id} }->[1]->{ $handle }->[0]; # id
}

package DBR::_ENUM;
use Carp;
use overload 
'""' => sub { shift->[1] }, # same as handle, below
'nomethod' => sub {croak "Enum object: Invalid operation '$_[3]' The ways in which you can use an enum are restricted"}
;

sub id     {shift->[0]}
sub handle {shift->[1]}
sub name   {shift->[2]}

# Future thought, validate that all values being tested are legit enum handles
sub in{ 
      my $hand = shift->handle;

      for (map { split(/\s+/,$_) } @_){
	    return 1 if $hand eq $_;
      }
      return 0;
}

1;
