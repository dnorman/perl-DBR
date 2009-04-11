# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::BuildSql;

use strict;
use base 'DBR::Common';
our $AUTOLOAD;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  dbh      => $params{dbh},
		  logger   => $params{logger},
		 };

      return $self->_error('dbh object is required') unless $self->{dbh};
      bless( $self, $package );

      return( $self );
}

#Usage:
#specify dbh handle and field => value pairs. use scalarrefs to values to prevent their being escaped.
#$dbrh->_buildWhere('textfield' => 'value1', 'numfield_with_trusted_source' => \'2222','untrusted_numfield' => ['! > < d <> in !in',2222]);
sub buildWhere{
    my $self = shift;
    my $param = shift;
    my $flag = shift;
    my $aliasmap = shift;

    $param = [%{$param}] if (ref($param) eq 'HASH');
    $param = [] unless (ref($param) eq 'ARRAY');

    my $where;

    while (@{$param}) {
	my $key = shift @{$param};

	# is it an OR? (single element)
	if (ref($key) eq 'ARRAY') {
	      my $or;
	      foreach my $element(@{$key}){
		    if(ref($element)){
			  $or .= ' OR' if $or;
			  $or .= $self->buildWhere($element,'sub',$aliasmap);
		    }
	      }
	      $where .= ' AND' if $where;
	      $where .= " ($or)";
	} else {

	      my $value = shift @{$param};

	      my $operator;
	      my $fvalue;

	      if (ref($value) eq 'HASH') {
		    if($value->{-table} && ($value->{-field} || $value->{-fields})){#is it a subquery?
			  $operator = 'IN';
			  return $self->_error('failed to build subquery sql') unless
			    my $sql = $self->buildSelect(%{$value});
			  $fvalue = "($sql)";

		    }elsif($aliasmap){ #not a subquery... are we doing a join?
			  my $alias = $key;
			  return $self->_error("invalid table alias '$alias' in -fields") unless $aliasmap->{$alias};

			  if(%{$value}){
				my %afields;
				foreach my $k (keys %{$value}) {
				      $afields{"$alias.$k"} = $value->{$k};
				}

				return $self->_error('where part failed') unless
				  my $wherepart = $self->buildWhere(\%afields,'sub',$aliasmap);

				$where .= ' AND' if $where;
				$where .= $wherepart;
			  }

			  next;	# get out of this loop... we are recursing instead

		    }else{
			  return $self->_error("invalid use of a hashref for key $key in -fields");
		    }

	      } else {
		    my $flags;
		    $flags = lc($value->[0]) if (ref($value) eq 'ARRAY');
		    my $blist = 0;


		    ########### #######QUOTING WAS HERE


		    #//////////////////////////////////////////////////

		    if ($blist) {
			  $fvalue = '(' . join(',',@fvalues) . ')';
		    } else {
			  $fvalue = $fvalues[0];
		    }
	      }

	      $operator = 'IS' if (($fvalue eq 'NULL') && ($operator eq '='));
	      $operator = 'IS NOT' if (($fvalue eq 'NULL') && ($operator eq '!='));

	      $where .= ' AND' if $where;
	      $where .= " $key $operator $fvalue";
	}
  }

    return '' unless $where;
    if($flag eq 'sub'){
	  return $where;
    }else{
	  return " WHERE$where";
    }
}


sub buildSelect{
      my $self = shift;
      my %params = @_;

      my $sql;
      $sql .= 'SELECT ';


      ####################### table handling #################
      my $tables = $params{-table} || $params{-tables};
      unless (ref($tables)){
	    my @tmptbl = split(/\s+/,$tables);
	    $tables = \@tmptbl if @tmptbl > 1;
      }

      return $self->_error("No -table[s] parameter specified") unless $tables;

      my $aliasmap;
      my @tparts;
      if(ref($tables) eq 'ARRAY'){
	    $aliasmap = {};
	    my $ct = 0;
	    foreach my $table (@{$tables}){
		  return $self->_error("Invalid table name specified ($table)") unless
		    $table =~ /^[A-Za-z][A-Za-z0-9_-]*$/;
		  return $self->_error('No more than 26 tables allowed in a join') if $ct > 25;
		  my $alias = chr(97 + $ct++); # a-z
		  $aliasmap->{$alias} = $table;
		  push @tparts, "$table $alias";
	    }
      }elsif(ref($tables) eq 'HASH'){
	    $aliasmap = {};
	    foreach my $alias (keys %{$tables}){
		  return $self->_error("invalid table alias '$alias' in -table[s]") unless
		    $alias =~ /^[A-Za-z][A-Za-z0-9_-]*$/;
		  my $table = $tables->{$alias};
		  return $self->_error("Invalid table name specified ($table)") unless
		    $table =~ /^[A-Za-z][A-Za-z0-9_-]*$/;

		  $aliasmap->{$alias} = $table;
		  push @tparts, "$table $alias";
	    }
      }else{
	    return $self->_error("Invalid table name specified ($tables)") unless
	      $tables =~ /^[A-Za-z][A-Za-z0-9_-]*$/;

	    @tparts = $tables;
      }

      ################### field handling ######################


      my $fields = $params{-fields} || $params{-field};
      unless(ref($fields)){
	    $fields =~ s/^\s+|\s+$//g;
	    $fields = [split(/\s+/,$fields)];
      }

      if($params{-count}){
	  $sql .= 'count(*) ';
      }elsif (ref($fields) eq 'ARRAY') {
	    my @fields;
	    foreach my $str (@{$fields}) {
		  my @parts = split(/\./,$str);
		  my ($field,$alias);

		  my $outf;
		  if (@parts == 1){
			($field) = @parts;
			$outf = $field;
		  }elsif(@parts == 2){
			($alias,$field) = @parts;
			return $self->_error("table alias '$str' is invalid without a join") unless $aliasmap;
			return $self->_error("invalid table alias '$str' in -fields") unless $aliasmap->{$alias};

			if($params{-dealias}){
			      $outf = "$alias.$field as $field";
			}elsif($params{-alias}){
			      $outf = "$alias.$field as '$alias.$field'";
			}else{
			      $outf = "$alias.$field"; # HERE - might result in different behavior on different databases
			}
		  }else{
			$self->_error("invalid fieldname '$str' in -fields");
			next;
		  }

		  next unless $field =~ /^[A-Za-z][A-Za-z0-9_-]*$/; # should bomb out, but leave this cus of legacy code

		  push @fields, $outf;
	    }
	    return $self->_error('No valid fields specified') unless @fields;
	    $sql .= join(',',@fields) . ' ';

      } elsif ($fields eq '*') {
	    $sql .= '* ';
      } else {
	    return $self->_error('No valid fields specified');
      }

      # insert table parts
      $sql .= "FROM " . join(',',@tparts);

      my $where = $self->buildWhere($params{-where},undef,$aliasmap);
      return $self->_error("Failed to build where clause") unless defined($where);

      $sql .= $where;

      if($params{-lock}){
	    my $mode = lc($params{-lock});

	    if($mode eq 'update'){
		  $sql .= ' FOR UPDATE'
	    }
      }

      my $limit = $params{-limit};
      if($limit){
	    return $self->_error('invalid limit') unless $limit =~ /^\d+$/;
	    $sql .= " LIMIT $limit"
      }

      return $sql;
}

# -table -fields -where
sub quote{
  my $self = shift;
  my $inval = shift;
  my $aliasmap = shift;

  my @values;
  my @fvalues;
  my $flags;


  if (ref($inval) eq 'ARRAY'){
	($flags,@values) = @{$inval};
  }else{
	@values = ($inval);
  }

  foreach my $value (@values){
	my $fvalue;
	if (ref($value) eq 'SCALAR') { # raw values are passed in as scalarrefs cus its super easy to do so.
	      $fvalue=${$value};
	}elsif($flags =~ /j/){ # join
	      my @parts = split(/\./,$value);
	      my ($field,$alias);

	      if (@parts == 1){
		    ($field) = @parts;
	      }elsif(@parts == 2){
		    ($alias,$field) = @parts;
		    return $self->_error("table alias '$value' is invalid without a join") unless $aliasmap;
		    return $self->_error("invalid table alias '$value' in -fields") unless $aliasmap->{$alias};
	      }
	      return $self->_error("invalid fieldname '$value' in -fields") unless $field =~ /^[A-Za-z][A-Za-z0-9_-]*$/;
	      $fvalue = $value;

	}elsif ($flags =~ /d/) {	# numeric
	      if ($value =~ /^-?\d*\.?\d+$/) {
		    $fvalue = $value;
	      }else{
		    return $self->_error("value $value is not a legal number");
		    next;
	      }
	} else {	# string
	      $fvalue = $self->{dbh}->quote($value);
	}

	$fvalue = 'NULL' unless defined($fvalue);
	push @fvalues, $fvalue;
  }

  return @fvalues;
}

1;
