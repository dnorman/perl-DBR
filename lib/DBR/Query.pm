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
		  dbrh      => $params{dbrh},
		  logger   => $params{logger},
		 };

      return $self->_error('dbrh object is required') unless $self->{dbrh};
      bless( $self, $package );

      my $type = $params{type} || return $self->_error('type is required');

      $self->{flags} = {
			alias   => $params{alias}   ? 1:0,
			dealias => $params{dealias} ? 1:0,
		       };

      $self->_tables( $params{tables} ) or return $self->_error('failed to prepare tables');

      $self->{where_sql} = $self->_where ( $params{where} ) or return $self->_error('failed to prepare where');

      if($type eq 'select'){

	    $self->_select( $params{fields} ) or return $self->_error('failed to prepare select');

      }elsif($type eq 'insert'){
	    
      }elsif($type eq 'update'){
	    
      }elsif($type eq 'delete'){
	    
      }else{
	    return $self->_error("invalid query type '$type'");
      }
      $self->{type} = $type;

      return( $self );
}

sub sql{
      my $self = shift;
      my %params = @_;

      my $sql;

      my $tables = join(',',@{$self->{tparts}});
      my $type = $self->{type};

      if ($type eq 'select'){
	    $sql .= "SELECT $self->{main_sql} FROM $tables";
      }elsif($type eq 'insert'){
	    $sql .= "INSERT INTO $tables $self->{main_sql}";
      }elsif($type eq 'update'){
	    $sql .= "UPDATE $tables SET $self->{main_sql}";
      }elsif($type eq 'delete'){
	    $sql .= "DELETE FROM $tables";
      }

      $sql .= " WHERE $self->{where_sql}";

      if($params{-lock}){
	    $sql .= ' FOR UPDATE'
      }

      my $limit = $params{-limit};
      if($limit){
 	    return $self->_error('invalid limit') unless $limit =~ /^\d+$/;
 	    $sql .= " LIMIT $limit"
       }


      return $sql;
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

#Usage:
#specify dbh handle and field => value pairs. use scalarrefs to values to prevent their being escaped.
#$dbrh->_buildWhere('textfield' => 'value1', 'numfield_with_trusted_source' => \'2222','untrusted_numfield' => ['! > < d <> in !in',2222]);
sub _where{
      my $self = shift;
      my $param = shift;

      return $self->_error('param must be an AND/OR object') unless ref($param) =~ /^DBR::Query::Part::(AND|OR)$/;

      $param->validate($self) or return $self->_error('Where clause validation failed');

      my $where = $param->sql or return $self->_error('Failed to retrieve sql');

  #     my $where;

#       while (@{$param}) {
# 	    my $key = shift @{$param};
# 	    $where .= ' AND' if $where;

# 	    # is it an OR? (single element)
# 	    if (ref($key) eq 'ARRAY') {
# 		  my $or;
# 		  foreach my $element (@{$key}){
# 			if(ref($element)){
# 			      $or .= ' OR' if $or;
# 			      $or .= $self->_where($element);
# 			}
# 		  }

# 		  $where .= " ($or)";
# 	    } else {
# 		  my $value = shift @{$param};

# 		  my $operator;
# 		  my $fvalue;
# 		  if(ref($value) eq $QUERY_OBJECT){ #is it a subquery?
# 		              return $self->_error('Invalid subquery') unless $value->can_be_qubquery;

# 			      $operator = 'IN';
# 			      my $sql = $value->sql;
# 			      $fvalue = "($sql)";
# 			      $where .= " $key $operator $sql";

# 		  }elsif (ref($value) eq 'HASH') { # Ok, so it's part of a join

# 			$self->{aliasmap} or return $self->_error("invalid use of a hashref for key $key in fields");

# 			my $alias = $key;
# 			return $self->_error("invalid table alias '$alias' in fields") unless $self->{aliasmap}->{$alias};

# 			if(%{$value}){
# 			      my %afields;
# 			      foreach my $k (keys %{$value}) {
# 				    $afields{"$alias.$k"} = $value->{$k};
# 			      }

# 			      return $self->_error('where part failed') unless
# 				my $wherepart = $self->_where([%afields]);

# 			      $where .= $wherepart;
# 			}

# 		  } else {
# 			ref($value) eq $VALUE_OBJECT or return $self->_error('value must be a DBR::Query::Value object');

# 			$where .= " $key $operator " . $value->sql;
# 		  }

# 	    }
#       }

      return $where || '';
}


sub _select{
      my $self   = shift;
      my $fields = shift;

      my $sql;

      if( $self->{count_only} ){
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
			return $self->_error("table alias '$str' is invalid without a join") unless $self->{aliasmap};
			return $self->_error("invalid table alias '$str' in -fields")        unless $self->{aliasmap}->{$alias};

			if( $self->{flags}->{dealias} ){ # HERE
			      $outf = "$alias.$field AS $field";
			}elsif( $self->{flags}->{alias} ){ #HERE
			      $outf = "$alias.$field AS '$alias.$field'";
			}else{
			      $outf = "$alias.$field"; # HERE - might result in different behavior on different databases
			}
		  }else{
			$self->_error("invalid fieldname '$str' in -fields");
			next;
		  }

		  next unless $field =~ /^[A-Za-z][A-Za-z0-9_-]*$/; # should bomb out, but leave this cus of legacy code
		  push @fields, $outf;

		  $self->{flags}->{can_be_subquery} = 1 if scalar(@fields) == 1;

	    }
	    return $self->_error('No valid fields specified') unless @fields;
	    $sql .= join(',',@fields);

      } elsif ($fields eq '*') {
	    $sql .= '*';
      } else {
	    return $self->_error('No valid fields specified');
      }

      $self->{main_sql} = $sql;

      return 1;
}

sub can_be_subquery {
      my $self = shift;
      return $self->{flags}->{can_be_subquery} ? 1:0;
}

# -table -fields -where
# sub _insert{
#   my $self = shift;
#   my %params = @_;


#   #my $call = {params => \%params,fields => \%fields, tmp => {}};
#   my $fcount;
#   foreach my $field (keys %{$params{-fields}}){
#     next unless $field =~ /^[A-Za-z0-9_-]+$/;
#     ($fields{$field}) = $self->quote($params{-fields}->{$field});
#     return $self->_error("failed to quote value for field '$field'") unless defined($fields{$field});
#     $fcount++;
#   }
#   return $self->_error('No valid fields specified') unless $fcount;

#   my $sql;

#   my @fkeys = keys %fields;
#   if($params{-insert}){
# 	return $self->_error('Failed to prepare sequence') unless $self->_prepareSequence($call);

# 	$sql = "INSERT INTO $params{-table} ";
# 	$sql .= '(' . join (',',@fkeys) . ')';
# 	$sql .= ' VALUES ';
# 	$sql .= '(' . join (',',map {$fields{$_}} @fkeys) . ')';
#   }elsif($params{-where}){
#     $sql = "UPDATE $params{-table} SET ";
#     $sql .= join (', ',map {"$_ = $fields{$_}"} @fkeys);

#     if(ref($params{-where}) eq 'HASH'){
# 	  return $self->_error('At least one where parameter must be provided') unless scalar(%{$params{-where}});
#     }elsif(ref($params{-where}) eq 'ARRAY'){
# 	  return $self->_error('At least one where parameter must be provided') unless scalar(@{$params{-where}});
#     }else{
# 	  return $self->_error('Invalid -where parameter');
#     }

#     my $where = $self->{sqlbuilder}->buildWhere($params{-where});
#     return $self->_error("Failed to build where clause") unless $where;
#     $sql .= $where;
#   }else{
#       return $self->_error('-insert flag or -where hashref/arrayref (for updates) must be specified');
#   }
#   #print STDERR "sql: $sql\n";
#   $self->_logDebug($sql);

#   my $rows;
#   if($params{-quiet}){
# 	do {
# 	      local $self->{dbh}->{PrintError} = 0; # make DBI quiet
# 	      $rows = $self->{dbh}->do($sql);
# 	};
# 	return undef unless defined ($rows);
#   }else{
# 	$rows = $self->{dbh}->do($sql);
# 	return $self->_error('failed to execute statement') unless defined($rows);
#   }

#   if ($params{-insert}) {
# 	my ($sequenceval) = $self->_getSequenceValue($call);
# 	return $sequenceval;
#   } else {
# 	return $rows || 0;	# number of rows updated or 0
#   }



# }


# sub _modify{
#   my $self = shift;
#   my %params = @_;



#   $params{-table} ||= $params{-insert} || $params{-update};

#   return $self->_error('No proper -fields parameter specified') unless ref($params{-fields}) eq 'HASH';
#   return $self->_error('No -table parameter specified') unless $params{-table} =~ /^[A-Za-z0-9_-]+$/;

#   my %fields;
#   my $call = {params => \%params,fields => \%fields, tmp => {}};
#   my $fcount;
#   foreach my $field (keys %{$params{-fields}}){
#     next unless $field =~ /^[A-Za-z0-9_-]+$/;
#     ($fields{$field}) = $self->{sqlbuilder}->quote($params{-fields}->{$field});
#     return $self->_error("failed to quote value for field '$field'") unless defined($fields{$field});
#     $fcount++;
#   }
#   return $self->_error('No valid fields specified') unless $fcount;

#   my $sql;

#   my @fkeys = keys %fields;
#   if($params{-insert}){
# 	return $self->_error('Failed to prepare sequence') unless $self->_prepareSequence($call);

# 	$sql = "INSERT INTO $params{-table} ";
# 	$sql .= '(' . join (',',@fkeys) . ')';
# 	$sql .= ' VALUES ';
# 	$sql .= '(' . join (',',map {$fields{$_}} @fkeys) . ')';
#   }elsif($params{-where}){
#     $sql = "UPDATE $params{-table} SET ";
#     $sql .= join (', ',map {"$_ = $fields{$_}"} @fkeys);

#     if(ref($params{-where}) eq 'HASH'){
# 	  return $self->_error('At least one where parameter must be provided') unless scalar(%{$params{-where}});
#     }elsif(ref($params{-where}) eq 'ARRAY'){
# 	  return $self->_error('At least one where parameter must be provided') unless scalar(@{$params{-where}});
#     }else{
# 	  return $self->_error('Invalid -where parameter');
#     }

#     my $where = $self->{sqlbuilder}->buildWhere($params{-where});
#     return $self->_error("Failed to build where clause") unless $where;
#     $sql .= $where;
#   }else{
#       return $self->_error('-insert flag or -where hashref/arrayref (for updates) must be specified');
#   }
#   #print STDERR "sql: $sql\n";
#   $self->_logDebug($sql);

#   my $rows;
#   if($params{-quiet}){
# 	do {
# 	      local $self->{dbh}->{PrintError} = 0; # make DBI quiet
# 	      $rows = $self->{dbh}->do($sql);
# 	};
# 	return undef unless defined ($rows);
#   }else{
# 	$rows = $self->{dbh}->do($sql);
# 	return $self->_error('failed to execute statement') unless defined($rows);
#   }

#   if ($params{-insert}) {
# 	my ($sequenceval) = $self->_getSequenceValue($call);
# 	return $sequenceval;
#   } else {
# 	return $rows || 0;	# number of rows updated or 0
#   }



# }
# sub _delete{
#   my $self = shift;
#   my %params = @_;

#   return $self->_error('No valid -where parameter specified') unless ref($params{-where}) eq 'HASH';
#   return $self->_error('No -table parameter specified') unless $params{-table} =~ /^[A-Za-z0-9_-]+$/;

#   my $sql = "DELETE FROM $params{-table} ";

#   if(ref($params{-where}) eq 'HASH'){
# 	return $self->_error('At least one where parameter must be provided') unless scalar(%{$params{-where}});
#   }elsif(ref($params{-where}) eq 'ARRAY'){
# 	return $self->_error('At least one where parameter must be provided') unless scalar(@{$params{-where}});
#   }else{
# 	return $self->_error('Invalid -where parameter');
#   }

#   my $where = $self->{sqlbuilder}->buildWhere($params{-where});
#   return $self->_error("Failed to build where clause") unless defined($where);
#   return $self->_error("Empty where clauses are not allowed") unless length($where);
#   $sql .= $where;
#   #print STDERR "sql: $sql\n";
#   $self->_logDebug($sql);
#   my $success = $self->{dbh}->do($sql);

#   return 1 if $success;
#   return undef;
# }



# sub getserial{
#       my $self = shift;
#       my $name = shift;
#       my $table = shift  || 'serials';
#       my $field1 = shift || 'name';
#       my $field2 = shift || 'serial';
#       return $self->_error('name must be specified') unless $name;

#       $self->begin();

#       my $row = $self->select(
# 			      -table => $table,
# 			      -field => $field2,
# 			      -where => {$field1 => $name},
# 			      -single => 1,
# 			      -lock => 'update',
# 			     );

#       return $self->_error('serial select failed') unless defined($row);
#       return $self->_error('serial is not primed') unless $row;

#       my $id = $row->{$field2};

#       return $self->_error('serial update failed') unless 
# 	$self->update(
# 		      -table => $table,
# 		      -fields => {$field2 => ['d',$id + 1]},
# 		      -where => {
# 				 $field1 => $name
# 				},
# 		     );

#       $self->commit();

#       return $id;
# }

1;
