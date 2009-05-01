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
			alias   => $params{alias}   ? 1:0,
			dealias => $params{dealias} ? 1:0,
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


sub select{
      my $self   = shift;
      my %params = @_;

      my $sql;

      if( $params{count} ){
	  $sql .= 'count(*) ';
	  $self->{flags}->{is_count} = 1;

      }elsif($params{fields}){
	    my $fields = $params{fields};

	    if (ref($fields) eq 'ARRAY') {
		  my @fields;
		  foreach my $str (@{$fields}) {
			my @parts = split(/\./,$str);
			my ($field,$alias);

			my $outf;
			if (@parts == 1) {
			      ($field) = @parts;
			      $outf = $field;
			} elsif (@parts == 2) {
			      ($alias,$field) = @parts;
			      return $self->_error("table alias '$str' is invalid without a join") unless $self->{aliasmap};
			      return $self->_error("invalid table alias '$str' in -fields")        unless $self->{aliasmap}->{$alias};

			      if ( $self->{flags}->{dealias} ) { # HERE
				    $outf = "$alias.$field AS $field";
			      } elsif ( $self->{flags}->{alias} ) { #HERE
				    $outf = "$alias.$field AS '$alias.$field'";
			      } else {
				    $outf = "$alias.$field"; # HERE - might result in different behavior on different databases
			      }
			} else {
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
      }

      $self->{main_sql} = $sql;
      $self->{type} = 'select';

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
						      ) or return $self->_eror('Failed to create resultset');

	    return $resultset;
      }

}

1;
