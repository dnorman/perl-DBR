# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Compat::DBRv1;

use strict;
use base 'DBR::Common';
use DBR::Query;
use DBR::Query::Value;
use DBR::Query::Part;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  dbrh     => $params{dbrh},
		  logger   => $params{logger},
		 };

      bless( $self, $package );
      return $self->_error('dbrh object is required') unless $self->{dbrh};

      return( $self );
}

sub select {
      my $self   = shift;
      my %params = @_;

      my $tables = $self->_split( $params{-table} || $params{-tables} ) or
	return $self->_error("No -table[s] parameter specified");

      my $fields = $self->_split( $params{-fields} || $params{-field}) or
	return $self->_error('No -field[s] parameter specified');

      my $where = $self->_where($params{-where}) or return $self->_error('failed to prep where');

      my $query = DBR::Query->new(
				  dbrh   => $self->{dbrh},
				  logger => $self->{logger},
				  type   => 'select',
				  tables => $tables,
				  fields => $fields,
				  where  => $where
				 ) or return $self->_error('failed to create query object');

      return $query;
}

sub _where {
      my $self = shift;
      my $param = shift;

      $param = [%{$param}] if (ref($param) eq 'HASH');
      $param = [] unless (ref($param) eq 'ARRAY');


      #use Data::Dumper;
      #print Dumper ({v1request => $param});

      my $where;

      my @out;
      while (@{$param}) {
	    my $val1 = shift @{$param};

	    # is it an OR? (single element)
	    if (ref($val1) eq 'ARRAY') {
		  my @or;
		  foreach my $element (@{ $val1 }){
			push @or, $self->_where($element) or $self->_error('convertvals failed');
		  }

		  push @out, DBR::Query::Part::OR->new( @or );

	    } else {
		  my $key   = $val1;
		  my $value = shift @{$param};

		  if (ref($value) eq 'HASH') {
			if($value->{-table} && ($value->{-field} || $value->{-fields})){ #is it a subquery?

			      my $compat = DBR::Query::Compat::DBRv1->new(
									  logger => $self->{logger},
									  dbrh    => $self->{dbrh},
									 ) or return $self->_error('failed to create Query object');

			      my $query = $compat->select(%{$value});
			      return $self->_error('invalid subquery') unless $query->can_be_subquery;

			      push @out, DBR::Query::Part::FIELD->new($key, $query);

			}else{ #if( $self->{aliasmap} ){ #not a subquery... are we doing a join?
			      my $alias = $key;
			      #return $self->_error("invalid table alias '$alias' in -fields") unless $self->{aliasmap}->{$alias};

			      if(%{$value}){
				    foreach my $k (keys %{$value}) {
					  my $ret = $self->_processfield("$alias.$k", $value->{$k}) or return $self->_error('failed to process field object');
					  push @out, $ret
				    }
			      }

			}#else{
			 #     return $self->_error("invalid use of a hashref for key $key in -fields");
			#}

		  } else {

			my $ret = $self->_processfield($key,$value) or return $self->_error('failed to process field object');

			push @out, $ret
		  }

	    }
      }

      if(@out > 1){
	    return DBR::Query::Part::AND->new(@out);
      }else{
	    return $out[0];
      }

}

sub _processfield{
      my $self  = shift;
      my $field   = shift;
      my $value   = shift;

      my $flags;

      if (ref($value) eq 'ARRAY'){
	    $flags = $value->[0];
      }

      if ($flags =~ /j/) {	# join
	    my $jointo = $value->[1];
	    my @parts = split(/\./,$jointo);
	    my ($field,$alias);

	    if (@parts == 1) {
		  ($field) = @parts;
		  return $self->_error("field $field cannot be referenced without a table alias");
	    } elsif (@parts == 2) {
		  ($alias,$field) = @parts;
		  #return $self->_error("table alias '$jointo' is invalid without a join") unless $aliasmap;
		  #return $self->_error("invalid table alias '$jointo' in -fields") unless $aliasmap->{$alias};

		  return $self->_error("invalid fieldname '$jointo' in -fields") unless $field =~ /^[A-Za-z][A-Za-z0-9_-]*$/;

		  my $join = DBR::Query::Part::JOIN->new($field,$jointo) or return $self->_error('failed to create join object');

		  return $join;
	    }

      } else {

	    my $outval =  DBR::Query::Value->direct(
						    value => $value,
						    dbrh  => $self->{dbrh},
						    logger => $self->{logger},
						   ) or return $self->_error('failed to create value object');

	    my $outfield = DBR::Query::Part::FIELD->new($field, $outval) or return $self->_error('failed to create field object');

	    return $outfield;
      }

}

1;
