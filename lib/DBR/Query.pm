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
	    $self->_insert($params{insert}) or return $self->_error('_insert failed');

      }elsif( $params{update} ){
	    $self->{type} = 'update';
	    $self->_update($params{update}) or return $self->_error('_update failed');

      }elsif( $params{delete} ){
	    $self->{type} = 'delete';
	    #Nada
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

      return $self->_error('param must be an AND/OR/COMPARE object') unless ref($param) =~ /^DBR::Query::Part::(And|Or|Compare)$/;

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


sub _update{
      my $self = shift;
      my $params = shift;

      return $self->_error('No set parameter specified') unless $params->{set};
      my $sets = $params->{set};
      $sets = [$sets] unless ref($sets) eq 'ARRAY';

      my @sql;
      foreach my $set (@$sets) {
	    ref($set) eq 'DBR::Query::Part::Set'
	      or return $self->_error('Set parameter must contain only set objects');

	    push @sql, $set->sql;
      }

      $self->{main_sql} = join (', ', @sql);
}

sub _insert{
  my $self = shift;
  my $params = shift;

  $self->_update($params) or return $self->_error('_update failed');

  if($params->{quiet_error}){
	$self->{quiet_error} = 1;
  }

  return 1;

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
	    $sql .= "INSERT INTO $tables SET $self->{main_sql}";
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

      $self->_logDebug2( $self->sql );

      my $dbh    = $self->{dbrh}->_dbh    or return $self->_error('failed to fetch dbh');
      my $driver = $self->{dbrh}->_driver or return $self->_error('failed to fetch driver');

      local $dbh->{PrintError}; # Localize here to ensure the same scope
      if(  $self->{quiet_error}  ){  $dbh->{PrintError} = 0 } # Eeeevil

      if($self->{type} eq 'select'){

	    return $self->_error('failed to prepare statement') unless
	      my $sth = $dbh->prepare($self->sql);

	    if($params{sth_only}){
		  return $sth;

	    }else{
		  my $resultset = DBR::Query::ResultSet->new(
							     logger => $self->{logger},
							     dbrh   => $self->{dbrh},
							     sth    => $sth,
							     query  => $self,
							     is_count => $self->{flags}->{is_count} || 0,
							    ) or return $self->_error('Failed to create resultset');

		  return $resultset;
	    }
      }elsif($self->{type} eq 'insert'){

	    $driver->prepSequence() or return $self->_error('Failed to prepare sequence');

	    my $rows = $dbh->do($self->sql);

	    my ($sequenceval) = $driver->getSequenceValue();

	    return $sequenceval;

	    #HERE HERE HERE return a record object?
      }elsif($self->{type} eq 'update'){

	    my $rows = $dbh->do($self->sql);

	    return $rows || 0;

      }elsif($self->{type} eq 'delete'){

	    my $rows = $dbh->do($self->sql);

	    return $rows || 0;

      }

      return $self->_error('unknown query type')
}

1;
