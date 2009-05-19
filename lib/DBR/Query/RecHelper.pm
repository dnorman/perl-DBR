package DBR::Query::RecHelper;

use strict;
use base 'DBR::Common';
use DBR::Query::Part;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger   => $params{logger},
		  dbrh     => $params{dbrh},
		  tablemap => $params{tablemap},
		  pkmap    => $params{pkmap},
		  scope    =>$params{scope}
		 };

      bless( $self, $package ); # BS object

      $self->{logger} or return $self->_error('logger is required');
      $self->{dbrh} or return $self->_error('dbrh is required');
      $self->{scope} or return $self->_error('scope is required');

      $self->{tablemap} or return $self->_error('tablemap is required');
      $self->{pkmap} or return $self->_error('pkmap is required');

      return $self;
}

sub set{
       my $self = shift;
       my $record = shift;
       my $field = shift;
       my $value = shift;

       # DO THIS ONCE PER TABLE
       my $table = $self->{tablemap}->{ $field->table_id } || return $self->_error('Missing table for table_id ' . $field->table_id );
       my $pk    = $self->{pkmap}->{ $field->table_id }    || return $self->_error('Missing primary key');

       my $setvalue = $field->makevalue($value) or return $self->_error('failed to create setvalue object');
       my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');

       ##### Where ###########
       my @and;
       foreach my $part (@{ $pk }){
	     my $value = $part->makevalue( $record->[0][ $part->index ] ) or return $self->_error('failed to create value object');
	     my $outfield = DBR::Query::Part::Compare->new( field => $part, value => $value ) or return $self->_error('failed to create compare object');

	     push @and, $outfield;
       }


       my $outwhere = DBR::Query::Part::And->new(@and);
       #######################

       my $query = DBR::Query->new(
				   logger => $self->{logger},
				   dbrh   => $self->{dbrh},
				   tables => $table->name,
				   where  => $outwhere,
				   update => { set => $setobj }
				  ) or return $self->_error('failed to create Query object');

       return $query->execute() or return $self->_error('failed to execute');


}
sub get{
       my $self = shift;
       my $record = shift;
       my $field = shift;

       # DO THIS ONCE PER TABLE
       my $table = $self->{tablemap}->{ $field->table_id } || return $self->_error('Missing table for table_id ' . $field->table_id );
       my $pk    = $self->{pkmap}->{ $field->table_id }    || return $self->_error('Missing primary key');

       ##### Where ###########
       my @and;
       foreach my $part (@{ $pk }){
	     my $value = $part->makevalue( $record->[0][ $part->index ] ) or return $self->_error('failed to create value object');
	     my $outfield = DBR::Query::Part::Compare->new( field => $part, value => $value ) or return $self->_error('failed to create compare object');

	     push @and, $outfield;
       }


       my $outwhere = DBR::Query::Part::And->new(@and);
       #######################

       my $query = DBR::Query->new(
				   logger => $self->{logger},
				   dbrh   => $self->{dbrh},
				   tables => $table->name,
				   where  => $outwhere,
				   select => { fields => [$field] }
				  ) or return $self->_error('failed to create Query object');

       my $sth = $query->execute(
				 sth_only => 1 # Don't want to create another resultset
				) or return $self->_error('failed to execute');

       $sth->execute() or return $self->_error('Failed to execute sth');
       my $row  = $sth->fetchrow_arrayref() or return $self->_error('Failed to fetchrow');

       #HERE HERE HERE cache this, and update the accessor?
       $self->{scope}->addfield($field) or return $self->_error('Failed to add field to scope');

       return $row->[0];
}

1;
