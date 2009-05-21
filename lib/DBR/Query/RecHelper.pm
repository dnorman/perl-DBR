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
		  flookup  => $params{flookup},
		  pkmap    => $params{pkmap},
		  scope    =>$params{scope}
		 };

      bless( $self, $package ); # BS object

      $self->{logger} or return $self->_error('logger is required');
      $self->{dbrh} or return $self->_error('dbrh is required');
      $self->{scope} or return $self->_error('scope is required');

      $self->{tablemap} or return $self->_error('tablemap is required');
      $self->{pkmap} or return $self->_error('pkmap is required');
      $self->{flookup} or return $self->_error('flookup is required');

      #$self->{conn} = $self->{dbrh}->_conn;

      return $self;
}

sub set{
      my $self = shift;
      my $record = shift;
      my %params = @_;
      use Data::Dumper;
      print Dumper($record,\%params);
      my %sets;

      foreach my $fieldname (keys %params){
	    my $field = $self->{flookup}->{$fieldname} or return $self->_error("$fieldname is not a valid field");

	    my $setvalue = $field->makevalue($params{$fieldname}) or return $self->_error('failed to create setvalue object');
	    my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');

	    push @{$sets{$field->table_id}}, $setobj;
      }
      my $ct = scalar(keys %sets);

      #HERE HERE HERE instance->connect

      #$self->{dbrh}->begin if $ct > 1;

      foreach my $table_id (keys %sets){
	    $self->_set($record, $table_id, $sets{$table_id}) or return $self->_error('failed to set');
      }

      #$self->{dbrh}->commit if $ct > 1;

      return 1;
}

sub setfield{
      my $self = shift;
      my $record = shift;
      my $field = shift;
      my $value = shift;

      my $setvalue = $field->makevalue($value) or return $self->_error('failed to create value object');
      my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');

      return $self->_set($record, $field->table_id, $setobj);
}

sub _set{
      my $self = shift;
      my $record = shift;
      my $table_id = shift;
      my $sets = shift;

      # DO THIS ONCE PER TABLE
      my $table = $self->{tablemap}->{ $table_id } || return $self->_error('Missing table for table_id ' . $table_id );
      my $pk    = $self->{pkmap}->{ $table_id    } || return $self->_error('Missing primary key');

       ##### Where ###########
       my @and;
       foreach my $part (@{ $pk }){
	     my $value = $part->makevalue( $record->[ $part->index ] ) or return $self->_error('failed to create value object');
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
				   update => { set => $sets }
				  ) or return $self->_error('failed to create Query object');

       return $query->execute() or return $self->_error('failed to execute');


}
sub getfield{
       my $self = shift;
       my $record = shift;
       my $field = shift;

       # DO THIS ONCE PER TABLE
       my $table = $self->{tablemap}->{ $field->table_id } || return $self->_error('Missing table for table_id ' . $field->table_id );
       my $pk    = $self->{pkmap}->{ $field->table_id }    || return $self->_error('Missing primary key');

       ##### Where ###########
       my @and;
       foreach my $part (@{ $pk }){
	     my $value = $part->makevalue( $record->[ $part->index ] ) or return $self->_error('failed to create value object');
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
