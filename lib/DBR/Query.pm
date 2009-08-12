# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query;

use strict;
no strict 'subs';
use base 'DBR::Common';
use DBR::Query::ResultSet::DB;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  instance   => $params{instance},
		  session => $params{session},
		  scope  => $params{scope},
		 };

      bless( $self, $package );

      return $self->_error('instance object is required') unless $self->{instance};

      $self->{flags} = {
			lock    => $params{lock} ? 1:0,
		       };

      $self->{lastidx} = -1;

      $self->_tables( $params{tables} ) or return $self->_error('failed to prepare tables');

      if($params{where}){
	    $self->{where_tree} = $params{where};
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

sub get_field {
      my $self = shift;
      my $fieldname = shift;

      return $self->{fieldmap}->{ $fieldname } || undef;

}

sub scope { $_[0]->{scope} }
sub check_table{
      my $self  = shift;
      my $alias = shift;

      return $self->{aliasmap}->{$alias} ? 1 : 0;
}

sub _tables{
      my $self   = shift;
      my $tables = shift;

      $tables = [$tables] unless ref($tables) eq 'ARRAY';
      return $self->_error('At least one table must be specified') unless @$tables;

      my @tparts;
      my %aliasmap;
      foreach my $table (@$tables){
	    return $self->_error('must specify table as a DBR::Config::Table object') unless ref($table) =~ /^DBR::Config::Table/; # Could also be ::Anon

	    my $name  = $table->name or return $self->_error('failed to get table name');
	    my $alias = $table->alias;
	    $aliasmap{$alias} = $name if $alias;

	    push @tparts, $table->sql;
      }

      $self->{tparts}   = \@tparts;
      $self->{aliasmap} = \%aliasmap;

      return 1;
}

sub _where{
      my $self = shift;
      my $param = shift;

      return $self->_error('param must be an AND/OR/COMPARE/SUBQUERY/JOIN object') unless ref($param) =~ /^DBR::Query::Part::(And|Or|Compare|Subquery|Join)$/;

      $param->validate($self) or return $self->_error('Where clause validation failed');

      my $conn = $self->{instance}->connect('conn') or return $self->_error('failed to connect');

      my $where = $param->sql( $conn ) or return $self->_error('Failed to retrieve sql');

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

	    my $conn = $self->{instance}->connect('conn') or return $self->_error('failed to connect');
	    if (ref($fields) eq 'ARRAY') {
		  my @fieldsql;
		  foreach my $field (@{$fields}) {

			return $self->_error('must specify field as a DBR::Config::Field object') unless ref($field) =~ /^DBR::Config::Field/; # Could also be ::Anon

			if ($field->table_alias) {
			      return $self->_error("table alias is invalid without a join") unless $self->{aliasmap};
			      return $self->_error('invalid table alias "' . $field->table_alias . '" in -fields')        unless $self->{aliasmap}->{ $field->table_alias };
			}

			$self->{fieldmap}->{ $field->name } = $field;

			push @fieldsql, $field->sql( $conn );
			$field->index( ++$self->{lastidx} ) or return $self->_error('failed to set field index');

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

sub lastidx{ $_[0]->{lastidx} }

sub _update{
      my $self = shift;
      my $params = shift;

      return $self->_error('No set parameter specified') unless $params->{set};
      my $sets = $params->{set};
      $sets = [$sets] unless ref($sets) eq 'ARRAY';

      my $conn = $self->{instance}->connect('conn') or return $self->_error('failed to connect');

      my @sql;
      foreach my $set (@$sets) {
	    ref($set) eq 'DBR::Query::Part::Set'
	      or return $self->_error('Set parameter must contain only set objects');

	    push @sql, $set->sql( $conn );
      }

      $self->{main_sql} = join (', ', @sql);
}

sub _insert{
      my $self = shift;
      my $params = shift;

      return $self->_error('No set parameter specified') unless $params->{set};
      my $sets = $params->{set};
      $sets = [$sets] unless ref($sets) eq 'ARRAY';

      my $conn = $self->{instance}->connect('conn') or return $self->_error('failed to connect');

      my @fields;
      my @values;
      foreach my $set (@$sets) {
	    ref($set) eq 'DBR::Query::Part::Set'
	      or return $self->_error('Set parameter must contain only set objects');

	    push @fields, $set->field->sql( $conn );
	    push @values, $set->value->sql( $conn );
      }

      $self->{main_sql} = '(' . join (', ', @fields) . ') values (' . join (', ', @values) . ')';

      if($params->{quiet_error}){
	    $self->{quiet_error} = 1;
      }

  return 1;

}

sub sql{
      my $self = shift;

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

sub where_is_emptyset{
    my $self = shift;
    return 0 unless $self->{where_tree};
    return $self->{where_tree}->is_emptyset;
}

sub can_be_subquery {
      my $self = shift;
      return $self->{flags}->{can_be_subquery} ? 1:0;
}

sub fields{ $_[0]->{fields} }

sub prepare {
      my $self = shift;

      return $self->_error('can only call resultset on a select') unless $self->{type} eq 'select';

      my $conn   = $self->{instance}->connect('conn') or return $self->_error('failed to connect');

      my $sql = $self->sql;

      $self->_logDebug2( $sql );

      return $self->_error('failed to prepare statement') unless
	my $sth = $conn->prepare($sql);

      return $sth;

}


sub resultset{
      my $self = shift;

      return $self->_error('can only call resultset on a select') unless $self->{type} eq 'select';

      my $resultset = DBR::Query::ResultSet::DB->new(
						     session   => $self->{session},
						     query    => $self,
						     #instance => $self->{instance},
						    ) or return $self->_error('Failed to create resultset');

      return $resultset;

}

sub is_count{
      my $self = shift;
      return $self->{flags}->{is_count} || 0,
}

sub execute{
      my $self = shift;
      my %params = @_;

      $self->_logDebug2( $self->sql );

      my $conn   = $self->{instance}->connect('conn') or return $self->_error('failed to connect');

      $conn->quiet_next_error if $self->{quiet_error};

      if($self->{type} eq 'insert'){

	    $conn->prepSequence() or return $self->_error('Failed to prepare sequence');

	    my $rows = $conn->do($self->sql) or return $self->_error("Insert failed");

	    # Tiny optimization: if we are being executed in a void context, then we
	    # don't care about the sequence value. save the round trip and reduce latency.
	    return 1 if $params{void};

	    my ($sequenceval) = $conn->getSequenceValue();
	    return $sequenceval;

      }elsif($self->{type} eq 'update'){

	    my $rows = $conn->do($self->sql);

	    return $rows || 0;

      }elsif($self->{type} eq 'delete'){

	    my $rows = $conn->do($self->sql);

	    return $rows || 0;

      }elsif($self->{type} eq 'select'){
	    return $self->_error('cannot call execute on a select');
      }

      return $self->_error('unknown query type')
}

sub makerecord{
      my $self = shift;
      my %params = @_;
      return $self->_error('rowcache is required') unless $params{rowcache};

      $self->_stopwatch();

      my $handle = DBR::Query::RecMaker->new(
					     instance => $self->{instance},
					     session  => $self->{session},
					     query    => $self,
					     rowcache => $params{rowcache},
					    ) or return $self->_error('failed to create record class');

      # need to keep this in scope, because it removes the dynamic class when DESTROY is called
      $self->_stopwatch('recmaker');

      return $handle;

}


1;
