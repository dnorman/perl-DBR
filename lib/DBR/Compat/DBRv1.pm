# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Compat::DBRv1;

use strict;
use base 'DBR::Common';
use DBR::Query;
use DBR::Query::Value;
use DBR::Query::Field;
use DBR::Query::Where;

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


      my @Qfields;
      foreach my $field (@$fields){
	    my $Qfield = DBR::Query::Field->new(
						logger => $self->{logger},
						name => $field
					       ) or return $self->_error('Failed to create query field object');
	    push @Qfields, $Qfield;
      }

      my $where;
      if($params{-where}){
	    $where = $self->_where($params{-where}) or return $self->_error('failed to prep where');
      }

      #use Data::Dumper;
      #print STDERR Dumper($where);

      my $query = DBR::Query->new(
				  dbrh   => $self->{dbrh},
				  logger => $self->{logger},
				  tables => $tables,
				  where  => $where
				 ) or return $self->_error('failed to create query object');


      $query->select(
		     count  => $params{'-count'}?1:0, # takes precedence
		     fields => \@Qfields
		    ) or return $self->_error('Failed to set up select');




      if ($params{-query}){

	    return $query;

      }elsif ($params{-rawsth}) {

	    my $sth = $query->execute( sth_only => 1) or return $self->_error('failed to execute');
	    return $sth;

      } else {
	    my $resultset = $query->execute() or return $self->_error('failed to execute');

	    if ($params{'-object'}) { # new way - hybrid
		  return $resultset;
	    } elsif ($params{-count}) {
		  return $resultset->count();
	    } elsif ($params{-arrayref}) {
		  return $resultset->arrayrefs;
	    } elsif ($params{-keycol}) {
		  return $resultset->map($params{-keycol})
	    } elsif ($params{-single}) {
		  my $ret = $resultset->hashrefs() or return undef;
		  return $ret->[0];
	    } else {
		  return $resultset->hashrefs;
	    }
      }

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

		  push @out, DBR::Query::Where::OR->new( @or );

	    } else {
		  my $key   = $val1;
		  my $value = shift @{$param};

		  if (ref($value) eq 'HASH') {
			if($value->{-table} && ($value->{-field} || $value->{-fields})){ #does it smell like a subquery?

			      my $compat = DBR::Query::Compat::DBRv1->new(
									  logger => $self->{logger},
									  dbrh    => $self->{dbrh},
									 ) or return $self->_error('failed to create Query object');

			      my $query = $compat->select(%{$value}, -query => 1) or return $self->_error('failed to create query object');
			      return $self->_error('invalid subquery') unless $query->can_be_subquery;

			      push @out, DBR::Query::Where::SUBQUERY->new($key, $query);

			}else{ #if( $self->{aliasmap} ){ #not a subquery... are we doing a join?
			      my $alias = $key;
			      #return $self->_error("invalid table alias '$alias' in -fields") unless $self->{aliasmap}->{$alias};

			      if(%{$value}){
				    foreach my $k (keys %{$value}) {
					  print STDERR "FOO: '$alias.$k'\n";
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
	    return DBR::Query::Where::AND->new(@out);
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
	    my ($tofield,$alias);

	    if (@parts == 1) {
		  ($tofield) = @parts;
		  return $self->_error("field $tofield cannot be referenced without a table alias");
	    } elsif (@parts == 2) {
		  ($alias,$tofield) = @parts;
		  #return $self->_error("table alias '$jointo' is invalid without a join") unless $aliasmap;
		  #return $self->_error("invalid table alias '$jointo' in -fields") unless $aliasmap->{$alias};

		  return $self->_error("invalid fieldname '$jointo' in -fields") unless $tofield =~ /^[A-Za-z][A-Za-z0-9_-]*$/;

		  my $join = DBR::Query::Where::JOIN->new($field,$jointo) or return $self->_error('failed to create join object');

		  return $join;
	    }

      } else {

	    my $outval =  $self->_value( $value) or return $self->_error('failed to create value object');

	    my $outfield = DBR::Query::Where::COMPARE->new($field, $outval) or return $self->_error('failed to create compare object');

	    return $outfield;
      }

}

sub _value {
      my( $self ) = shift;
      my $value = shift or return $self->_error('value must be specified');

      my $is_number = 0;
      my $operator;

      if(ref($value) eq 'ARRAY'){
	    my $flags = shift @{$value}; # Yes, we are altering the input array... deal with it.

	    if ($flags =~ /like/) { # like
		  #return $self->_error('LIKE flag disabled without the allowquery flag') unless $self->{config}->{allowquery};
		  $operator = 'like';

	    } elsif ($flags =~ /!/) { # Not
		  $operator = 'ne';

	    } elsif ($flags =~ /\<\>/) { # greater than less than
		  $operator = 'ne'; $is_number = 1;

	    } elsif ($flags =~ /\>=/) { # greater than eq
		  $operator = 'ge'; $is_number = 1;

	    } elsif ($flags =~ /\<=/) { # less than eq
		  $operator = 'le'; $is_number = 1;

	    } elsif ($flags =~ /\>/) { # greater than
		  $operator = 'gt'; $is_number = 1;

	    } elsif ($flags =~ /\</) { # less than
		  $operator = 'lt'; $is_number = 1;

	    }

	    if($flags =~ /d/){
		  $is_number = 1;
	    }

      }

      $operator ||= 'eq';

      my $valobj = DBR::Query::Value->new(
					  is_number => $is_number,
					  operator  => $operator,
					  value     => $value,
					  dbrh      => $self->{dbrh},
					  logger    => $self->{logger}
					 ) or return $self->_error('failed to create value object');


      return $valobj;
}


1;
