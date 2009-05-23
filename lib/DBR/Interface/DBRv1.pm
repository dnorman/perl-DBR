# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Interface::DBRv1;

use strict;
use base 'DBR::Common';
use DBR::Query;
use DBR::Config::Field::Anon;
use DBR::Query::Value;
use DBR::Query::Part;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  instance => $params{instance},
		  logger   => $params{logger},
		 };

      bless( $self, $package );
      return $self->_error('instance object is required') unless $self->{instance};

      return( $self );
}



sub select {
      my $self   = shift;
      my @params = @_;
      my %params;

      if(scalar(@params) == 1){
	    $params{-sql} = $params[0];
      }else{
	    %params = @params;
      }

      my $tables = $self->_split( $params{-table} || $params{-tables} ) or
	return $self->_error("No -table[s] parameter specified");

      my $fields = $self->_split( $params{-fields} || $params{-field}) or
	return $self->_error('No -field[s] parameter specified');

      my @Qfields;
      foreach my $field (@$fields){
	    my $Qfield = DBR::Config::Field::Anon->new(
						       logger => $self->{logger},
						       name   => $field
						      ) or return $self->_error('Failed to create field object');
	    push @Qfields, $Qfield;
      }

      my $where;
      if($params{-where}){
	    $where = $self->_where($params{-where}) or return $self->_error('failed to prep where');
      }

      #use Data::Dumper;
      #print STDERR Dumper($where);

      my $query = DBR::Query->new(
				  instance => $self->{instance},
				  logger   => $self->{logger},
				  select   => {
					     count  => $params{'-count'}?1:0, # takes precedence
					     fields => \@Qfields
					    },
				  tables => $tables,
				  where  => $where
				 ) or return $self->_error('failed to create query object');


      if ($params{-query}){

	    return $query;

      }elsif ($params{-rawsth}) {

	    my $sth = $query->execute( sth_only => 1 ) or return $self->_error('failed to execute');
	    $sth->execute() or return $self->_error('failed to execute sth');

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

sub insert {
      my $self = shift;
      my %params = @_;


      my $table = $params{-table} || $params{-insert};
      my $fields = $params{-fields};

      return $self->_error('No -table parameter specified') unless $table =~ /^[A-Za-z0-9_-]+$/;
      return $self->_error('No proper -fields parameter specified') unless ref($fields) eq 'HASH';

      my @sets;
      foreach my $field (keys %$fields){
	    my $value = $fields->{$field};

	    my $fieldobj = DBR::Config::Field::Anon->new(
							 logger => $self->{logger},
							 name   => $field
							) or return $self->_error('Failed to create field object');

	    my $valobj = $self->_value($value) or return $self->_error('_value failed');

	    my $set = DBR::Query::Part::Set->new($fieldobj,$valobj) or return $self->_error('failed to create set object');
	    push @sets, $set;
      }


      my $query = DBR::Query->new(
				  instance => $self->{instance},
				  logger   => $self->{logger},
				  insert   => {
					       set => \@sets,
					      },
				  quiet_error => $params{-quiet} ? 1:0,
				  tables => $table,
				 ) or return $self->_error('failed to create query object');

      return $query->execute();

}

sub update {
      my $self = shift;
      my %params = @_;


      my $table  = $params{-table} || $params{-update};
      my $fields = $params{-fields};

      return $self->_error('No -table parameter specified') unless $table =~ /^[A-Za-z0-9_-]+$/;
      return $self->_error('No proper -fields parameter specified') unless ref($fields) eq 'HASH';

      my $where;
      if($params{-where}){
	    $where = $self->_where($params{-where}) or return $self->_error('failed to prep where');
      }else{
	    return $self->_error('-where hashref/arrayref must be specified');
      }

      my @sets;
      foreach my $field (keys %$fields){
	    my $value = $fields->{$field};

	    my $fieldobj = DBR::Config::Field::Anon->new(
							 logger => $self->{logger},
							 name   => $field
							) or return $self->_error('Failed to create field object');

	    my $valobj = $self->_value($value) or return $self->_error('_value failed');

	    my $set = DBR::Query::Part::Set->new($fieldobj,$valobj) or return $self->_error('failed to create set object');

	    push @sets, $set;
      }


      my $query = DBR::Query->new(
				  instance => $self->{instance},
				  logger   => $self->{logger},
				  update   => {
					       set => \@sets,
					      },
				  quiet_error => $params{-quiet} ? 1:0,
				  tables => $table,
				  where  => $where
				 ) or return $self->_error('failed to create query object');

      return $query->execute();

}
sub delete {
      my $self = shift;
      my %params = @_;


      my $table  = $params{-table} || $params{-delete};

      return $self->_error('No -table parameter specified') unless $table =~ /^[A-Za-z0-9_-]+$/;

      my $where;
      if($params{-where}){
	    $where = $self->_where($params{-where}) or return $self->_error('failed to prep where');
      }else{
	    return $self->_error('-where hashref/arrayref must be specified');
      }

      my $query = DBR::Query->new(
				  instance => $self->{instance},
				  logger   => $self->{logger},
				  delete   => 1,
				  tables   => $table,
				  where    => $where,
				  quiet_error => $params{-quiet} ? 1:0
				 ) or return $self->_error('failed to create query object');

      return $query->execute();

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

		  push @out, DBR::Query::Part::Or->new( @or );

	    } else {
		  my $key   = $val1;
		  my $value = shift @{$param};

		  if (ref($value) eq 'HASH') {
			if($value->{-table} && ($value->{-field} || $value->{-fields})){ #does it smell like a subquery?

			      my $compat = DBR::Interface::DBRv1->new(
								      logger   => $self->{logger},
								      instance => $self->{instance},
								     ) or return $self->_error('failed to create Query object');

			      my $query = $compat->select(%{$value}, -query => 1) or return $self->_error('failed to create query object');
			      return $self->_error('invalid subquery') unless $query->can_be_subquery;

			      push @out, DBR::Query::Part::Subquery->new($key, $query);

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
	    return DBR::Query::Part::And->new(@out);
      }else{
	    return $out[0];
      }

}

sub _processfield{
      my $self    = shift;
      my $fieldname = shift;
      my $value   = shift;

      my $field = DBR::Config::Field::Anon->new(
						logger => $self->{logger},
						name   => $fieldname
					       ) or return $self->_error('Failed to create fromfield object');
      my $flags;

      if (ref($value) eq 'ARRAY'){
	    $flags = $value->[0];
      }

      if ($flags =~ /j/) {	# join

	    my $tofield = DBR::Config::Field::Anon->new(
							logger => $self->{logger},
							name   => $value->[1]
						       ) or return $self->_error('Failed to create tofield object');

	    my $join = DBR::Query::Part::Join->new($field,$tofield)
	      or return $self->_error('failed to create join object');

	    return $join;

      } else {
	    my $is_number = 0;
	    my $operator;

	    if ( $flags =~ /like/ ) {
		  $operator = 'like';# like
		  #return $self->_error('LIKE flag disabled without the allowquery flag') unless $self->{config}->{allowquery};
	    } elsif ( $flags =~ /!/    ) { $operator = 'ne'; # Not
	    } elsif ( $flags =~ /\<\>/ ) { $operator = 'ne'; $is_number = 1; # greater than less than
	    } elsif ( $flags =~ /\>=/  ) { $operator = 'ge'; $is_number = 1; # greater than eq
	    } elsif ( $flags =~ /\<=/  ) { $operator = 'le'; $is_number = 1; # less than eq
	    } elsif ( $flags =~ /\>/   ) { $operator = 'gt'; $is_number = 1; # greater than
	    } elsif ( $flags =~ /\</   ) { $operator = 'lt'; $is_number = 1; # less than
	    }

	    $operator ||= 'eq';

	    my $valobj = $self->_value($value,$is_number) or return $self->_error('_value failed');

	    my $compobj = DBR::Query::Part::Compare->new(
							 field    => $field,
							 operator => $operator,
							 value    => $valobj
							) or return $self->_error('failed to create compare object');

	    return $compobj;

      }

}

sub _value {
      my $self = shift;
      my $value = shift;
      my $is_number = shift || 0;

      my $flags;
      if (ref($value) eq 'ARRAY'){
	    $flags = shift @$value;
      }

      if($flags =~ /d/){  $is_number = 1 }

      my $valobj = DBR::Query::Value->new(
					  is_number => $is_number,
					  value     => $value,
					  logger    => $self->{logger}
					 ) or return $self->_error('failed to create value object');
      return $valobj;

}

1;
