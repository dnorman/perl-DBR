# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query;

use strict;
no strict 'subs';
use base 'DBR::Common';
my $VALUE_OBJECT = 'DBR::Query::Value';
my $QUERY_OBJECT = _PACKAGE_;
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

      $self->{flags} = {
			lock    => $params{lock} ? 1:0,
		       };

      $self->_tables( $params{tables} ) or return $self->_error('failed to prepare tables');

      if($params{where}){
	    $self->{where_sql} = $self->_where ( $params{where} ) or return $self->_error('failed to prepare where');
      }

      if ($params{limit}){
 	    return $self->_error('invalid limit') unless $params{limit} =~ /^\d+$/;
	    $self->{limit} = $params{limit};
      }

      if ( $params{select} ){

	    $self->_select($params{select}) or return $self->_error('_select failed');
	    $self->{type} = 'select';
      }elsif( $params{insert} ){
	    $self->{type} = 'insert';
      }elsif( $params{update} ){
	    $self->{type} = 'update';
      }elsif( $params{delete} ){
	    $self->{type} = 'delete';
      }else{
	    return $self->_error('must specify select, insert, update or delete');
      }


      return( $self );
}

sub _tables{
      my $self   = shift;
      my $tables = shift;

      return $self->_error("No -table[s] parameter specified") unless $tables;
      if(ref($tables) eq 'ARRAY' and @{$tables} == 1){
	    $tables = $tables->[0]
      }

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

      $self->{tparts}   = \@tparts;
      $self->{aliasmap} = $aliasmap;

      return 1;
}

sub check_table{
      my $self  = shift;
      my $alias = shift;

      return $self->{aliasmap}->{$alias} ? 1 : 0;
}

sub _where{
      my $self = shift;
      my $param = shift;

      return $self->_error('param must be an AND/OR/COMPARE object') unless ref($param) =~ /^DBR::Query::Where::(AND|OR|COMPARE)$/;

      $param->validate($self) or return $self->_error('Where clause validation failed');

      my $where = $param->sql or return $self->_error('Failed to retrieve sql');

      return $where || '';
}


sub _select{
      my $self   = shift;
      my $params = shift;

      my $sql;

      if( $params->{count} ){
	  $sql .= 'count(*) ';
	  $self->{flags}->{is_count} = 1;

      }elsif($params->{fields}){
	    my $fields = $params->{fields};

	    my $idx = -1;
	    if (ref($fields) eq 'ARRAY') {
		  my @fieldsql;
		  foreach my $field (@{$fields}) {

			return $self->_error('must specify field as a DBR::Config::Field object') unless ref($field) =~ /^DBR::Config::Field/; # Could also be ::Anon

			if ($field->table_alias) {
			      return $self->_error("table alias is invalid without a join") unless $self->{aliasmap};
			      return $self->_error('invalid table alias "' . $field->table_alias . '" in -fields')        unless $self->{aliasmap}->{ $field->table_alias };
			}

			push @fieldsql, $field->sql;
			$field->index(++$idx);

			$self->{flags}->{can_be_subquery} = 1 if scalar(@fieldsql) == 1;

		  }
		  return $self->_error('No valid fields specified') unless @fieldsql;
		  $sql .= join(', ',@fieldsql);

	    } else {
		  return $self->_error('No valid fields specified');
	    }

	    $self->{fields} = $fields;
      }

      $self->{main_sql} = $sql;

      return 1;
}


sub _modify{
  my $self = shift;
  my $params = shift;



  $params{-table} ||= $params{-insert} || $params{-update};

  return $self->_error('No proper -fields parameter specified') unless ref($params{-fields}) eq 'array';
  return $self->_error('No -table parameter specified') unless $params{-table} =~ /^[A-Za-z0-9_-]+$/;

  my %fields;
  my $call = {params => \%params,fields => \%fields, tmp => {}};
  my $fcount;
  foreach my $field (keys %{$params{-fields}}){
    next unless $field =~ /^[A-Za-z0-9_-]+$/;
    ($fields{$field}) = $self->quote($params{-fields}->{$field});
    return $self->_error("failed to quote value for field '$field'") unless defined($fields{$field});
    $fcount++;
  }
  return $self->_error('No valid fields specified') unless $fcount;

  my $sql;

  my @fkeys = keys %fields;
  if($params{-insert}){
	return $self->_error('Failed to prepare sequence') unless $self->_prepareSequence($call);

	$sql = "INSERT INTO $params{-table} ";
	$sql .= '(' . join (',',@fkeys) . ')';
	$sql .= ' VALUES ';
	$sql .= '(' . join (',',map {$fields{$_}} @fkeys) . ')';

 ### }elsif($params{-where}){
 ###   $sql = "UPDATE $params{-table} SET ";

	$sql .= join (', ',map {"$_ = $fields{$_}"} @fkeys);

  my $rows;
  if($params{-quiet}){
	do {
	      local $self->{dbh}->{PrintError} = 0; # make DBI quiet
	      $rows = $self->{dbh}->do($sql);
	};
	return undef unless defined ($rows);
  }else{
	$rows = $self->{dbh}->do($sql);
	return $self->_error('failed to execute statement') unless defined($rows);
  }

  if ($params{-insert}) {
	my ($sequenceval) = $self->_getSequenceValue($call);
	return $sequenceval;
  } else {
	return $rows || 0;	# number of rows updated or 0
  }



}

sub sql{
      my $self = shift;
      my %params = @_;

      return $self->{sql} if exists($self->{sql});

      my $sql;

      my $tables = join(',',@{$self->{tparts}});
      my $type = $self->{type};

      if ($type eq 'select'){
	    $sql .= "SELECT $self->{main_sql} FROM $tables";
	    $sql .= " WHERE $self->{where_sql}" if $self->{where_sql};
      }elsif($type eq 'insert'){
	    $sql .= "INSERT INTO $tables $self->{main_sql}";
      }elsif($type eq 'update'){
	    $sql .= "UPDATE $tables SET $self->{main_sql} WHERE $self->{where_sql}";
      }elsif($type eq 'delete'){
	    $sql .= "DELETE FROM $tables WHERE $self->{where_sql}";
      }

      $sql .= ' FOR UPDATE'           if $self->{flags}->{lock};
      $sql .= " LIMIT $self->{limit}" if $self->{limit};

      $self->{sql} = $sql;

      return $sql;
}


sub can_be_subquery {
      my $self = shift;
      return $self->{flags}->{can_be_subquery} ? 1:0;
}

sub fields{ $_[0]->{fields} }

sub execute{
      my $self = shift;
      my %params = @_;

      $self->_logDebug($self->sql);

      my $dbh = $self->{dbrh}->dbh or return $self->_error('failed to fetch dbh');

      return $self->_error('failed to prepare statement') unless
	my $sth = $dbh->prepare($self->sql);

      if($params{sth_only}){

	    return $sth;

      }else{
	    my $resultset = DBR::Query::ResultSet->new(
						       logger => $self->{logger},
						       sth    => $sth,
						       query  => $self,
						       is_count => $self->{flags}->{is_count} || 0,
						      ) or return $self->_error('Failed to create resultset');

	    return $resultset;
      }

}

1;
