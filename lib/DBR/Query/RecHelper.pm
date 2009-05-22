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
		  scope    =>$params{scope},
		  lastidx => $params{lastidx},
		 };

      bless( $self, $package ); # BS object

      $self->{logger} or return $self->_error('logger is required');
      $self->{dbrh} or return $self->_error('dbrh is required');
      $self->{scope} or return $self->_error('scope is required');

      $self->{tablemap} or return $self->_error('tablemap is required');
      $self->{pkmap} or return $self->_error('pkmap is required');
      $self->{flookup} or return $self->_error('flookup is required');
      defined($self->{lastidx}) or return $self->_error('lastidx is required');

      #$self->{conn} = $self->{dbrh}->_conn;

      return $self;
}

sub set{
      my $self = shift;
      my $record = shift;
      my %params = @_;

      my %sets;
      foreach my $fieldname (keys %params){
	    my $field = $self->{flookup}->{$fieldname} or return $self->_error("$fieldname is not a valid field");
	    $field->is_readonly && return $self->_error("Field $fieldname is readonly");

	    my $setvalue = $field->makevalue($params{$fieldname}) or return $self->_error('failed to create setvalue object');
	    $setvalue->count == 1 or return $self->_error("Field ${\$field->name} allows only a single value");

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

# set a field REGARDLESS of whether it was prefetched or not
sub setfield{
      my $self = shift;
      my $record = shift;
      my $field = shift;
      my $value = shift;

      my $setvalue = $field->makevalue($value) or return $self->_error('failed to create value object');
      $setvalue->count == 1 or return $self->_error("Value of ${\$field->name} must have only a single value");

      my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');

      return $self->_set($record, $field->table_id, [$setobj]);
}

sub _set{
      my $self = shift;
      my $record = shift;
      my $table_id = shift;
      my $sets = shift;

      my ($outwhere,$tablename) = $self->_pk_where($record,$table_id) or return $self->_error('failed to create where tree');

       my $query = DBR::Query->new(
				   logger => $self->{logger},
				   dbrh   => $self->{dbrh},
				   tables => $tablename,
				   where  => $outwhere,
				   update => { set => $sets }
				  ) or return $self->_error('failed to create Query object');

      my $rv = $query->execute() or return $self->_error('failed to execute');

      foreach my $set (@$sets){
	    $self->_setlocalval($record, $set->field, $set->value->raw->[0]) or
	      return $self->_error('failed to _setlocalval');
      }

      return $rv;
}

# This version of get is less efficient for fields that aren't prefetched, but much faster overall I think
sub get{
      my $self = shift;
      my $record = shift;

      my @out;
      foreach (map { split(/\s+/,$_) } @_){
	    my $val = $record->$_;
	    print "VAL OF $_ is '$val'\n";
	    push @out, $val;
      }
      return @out;

      #return map { ($record->$_) } map { split(/\s+/,$_) } @_;
}

#Unfinished, heavy version of get, I'm not convinced that it's necessary
# sub get{
#       my $self = shift;
#       my $record = shift;
#       my @fieldnames = @_;
#
#       my %gets;
#       my @out;
#       my $oidx=0;
#       foreach my $fieldname (@fieldnames){
# 	    my $field = $self->{flookup}->{$fieldname} or return $self->_error("$fieldname is not a valid field");
# 	    my $idx = $field->index;
#
# 	    if (defined($idx) && exists($record->[$idx])){
# 		  $out[$oidx] = $record->[$idx];
# 	    }else{
# 	    }
#       }
#
#       return 1;
# }

# Fetch a field ONLY if it was not prefetched
sub getfield{
       my $self = shift;
       my $record = shift;
       my $field = shift;

       # Check to see if we've previously been assigned an index. if so, see if our record already has it fetched
       # This could happen if the field was not fetched in the master query, but was already fetched with getfield
       my $idx = $field->index;
       return $record->[$idx] if defined($idx) && exists($record->[$idx]);

       my $rv = $self->_get( $record, $field->table_id, [$field] ) or return $self->_error('Failed to _get');
       print STDERR "VAL: $rv->[0]\n";
       return $rv->[0];

}

sub _get{
      my $self = shift;
      my $record = shift;
      my $table_id = shift;
      my $fields = shift;

      my ($outwhere,$tablename)  = $self->_pk_where($record,$table_id) or return $self->_error('failed to create where tree');

      # Because we are doing a new select, which will set the indexes on its fields, we must
      # clone the fields provided by the original query and be able to match them up later
      my @old2new = map { [$_,$_->clone] } @$fields;

      my $query = DBR::Query->new(
				  logger => $self->{logger},
				  dbrh   => $self->{dbrh},
				  tables => $tablename,
				  where  => $outwhere,
				  select => { fields => [map { $_->[1] } @old2new] } # use the new cloned fields
				 ) or return $self->_error('failed to create Query object');

      my $sth = $query->execute(
				sth_only => 1 # Don't want to create another resultset object
			       ) or return $self->_error('failed to execute');

      $sth->execute() or return $self->_error('Failed to execute sth');
      my $row  = $sth->fetchrow_arrayref() or return $self->_error('Failed to fetchrow');


      my @out;
      foreach (@old2new){
	    my ($field,$newfield) = @{$_};
	    my $val = $row->[ $newfield->index ];

	    $self->_setlocalval($record,$field,$val) or return $self->_error('failed to _setlocalval');

	    if(my $trans = $field->translator){
		  push @out, $trans->forward($val);
	    }else{
		  push @out, $val;
	    }

	    $self->{scope}->addfield($field) or return $self->_error('Failed to add field to scope');
      }

      return \@out;

}

sub _pk_where{
      my $self = shift;
      my $record = shift;
      my $table_id = shift;

      my $table = $self->{tablemap}->{ $table_id } || return $self->_error('Missing table for table_id ' . $table_id );
      my $pk    = $self->{pkmap}->{ $table_id }    || return $self->_error('Missing primary key');

      my @and;
      foreach my $part (@{ $pk }){
	    my $value = $part->makevalue( $record->[ $part->index ] ) or return $self->_error('failed to create value object');
	    my $outfield = DBR::Query::Part::Compare->new( field => $part, value => $value ) or return $self->_error('failed to create compare object');

	    push @and, $outfield;
      }


      return (DBR::Query::Part::And->new(@and), $table->name);
}

sub _setlocalval{
      my $self   = shift;
      my $record = shift;
      my $field  = shift;
      my $val    = shift;

      my $idx = $field->index;
      # update the field object to give it an index if necessary
      if(!defined $idx){ #Could be 0
	    $idx = ++$self->{lastidx};
	    $field->index($idx); # so we'll have it for next time this gets accessed
      }

      # Update this record to reflect the new value
      $record->[$idx] = $val;

      return 1;
}

1;
