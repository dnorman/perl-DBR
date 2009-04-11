# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Handle;

use strict;
use base 'DBR::Common';
use DBR::Query;
use DBR::BuildSql;
our $AUTOLOAD;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  dbh      => $params{dbh},
		  dbr      => $params{dbr},
		  logger   => $params{logger},
		  instance => $params{instance}
		 };

      bless( $self, $package );

      return $self->_error( 'dbh parameter is required'      ) unless $self->{dbh};
      return $self->_error( 'dbr parameter is required'      ) unless $self->{dbr};
      return $self->_error( 'instance parameter is required' ) unless $self->{instance};

      $self->{schema} = $self->{instance}->schema;
      return $self->_error( 'failed to retrieve schema' ) unless defined($self->{schema});

      $self->{sqlbuilder} = DBR::BuildSql->new(
					       logger => $self->{logger},
					       dbh    => $self->{dbh}
					      ) or return $self->_error('failed to create BuildSql object');

      return( $self );
}

# -table -fields -where
sub select{
    my $self = shift;
    my @params = @_;
    my %params;
    if(scalar(@params) == 1){
      $params{-sql} = $params[0];
    }else{
      %params = @params;
    }

    my $sql;
    if($params{-sql}){
	  $sql = $params{-sql};
    }else{
	  return $self->_error('failed to build select sql') unless
	    $sql = $self->{sqlbuilder}->buildSelect(%params);
    }

    #print STDERR "sql: $sql\n";
    $self->_logDebug($sql);
    return $self->_error('failed to prepare statement') unless
      my $sth = $self->{dbh}->prepare($sql);
      my $rowct = $sth->execute();

    return $self->_error('failed to execute statement') unless defined($rowct);


    my $count = 0;
    my $rows = [];
    if ($rows) {
	  if ($params{-rawsth}) {
		return $sth;
	  }elsif ($params{-count}) {
		($count) = $sth->fetchrow_array();
	  }elsif($params{-arrayref}){
		$rows = $sth->fetchall_arrayref();
	  }elsif ($params{-keycol}) {
		return $sth->fetchall_hashref($params{-keycol});
	  } else {
		while (my $row = $sth->fetchrow_hashref()) {
		      $count++;
		      push @{$rows}, $row;
		}
	  }
    }

    $sth->finish();

    if($rows){
	if($params{-count}){
	    return $count;
	}elsif($params{-single}){
	      return 0 unless @{$rows};
	      my $row = $rows->[0];
	      return $row;
	}else{
	      return $rows;
	}
    }

    return undef;

}


sub delete{
  my $self = shift;
  my %params = @_;

  return $self->_error('No valid -where parameter specified') unless ref($params{-where}) eq 'HASH';
  return $self->_error('No -table parameter specified') unless $params{-table} =~ /^[A-Za-z0-9_-]+$/;

  my $sql = "DELETE FROM $params{-table} ";

  if(ref($params{-where}) eq 'HASH'){
	return $self->_error('At least one where parameter must be provided') unless scalar(%{$params{-where}});
  }elsif(ref($params{-where}) eq 'ARRAY'){
	return $self->_error('At least one where parameter must be provided') unless scalar(@{$params{-where}});
  }else{
	return $self->_error('Invalid -where parameter');
  }

  my $where = $self->{sqlbuilder}->buildWhere($params{-where});
  return $self->_error("Failed to build where clause") unless defined($where);
  return $self->_error("Empty where clauses are not allowed") unless length($where);
  $sql .= $where;
  #print STDERR "sql: $sql\n";
  $self->_logDebug($sql);
  my $success = $self->{dbh}->do($sql);

  return 1 if $success;
  return undef;
}

sub modify{
  my $self = shift;
  my %params = @_;



  $params{-table} ||= $params{-insert} || $params{-update};

  return $self->_error('No proper -fields parameter specified') unless ref($params{-fields}) eq 'HASH';
  return $self->_error('No -table parameter specified') unless $params{-table} =~ /^[A-Za-z0-9_-]+$/;

  my %fields;
  my $call = {params => \%params,fields => \%fields, tmp => {}};
  my $fcount;
  foreach my $field (keys %{$params{-fields}}){
    next unless $field =~ /^[A-Za-z0-9_-]+$/;
    ($fields{$field}) = $self->{sqlbuilder}->quote($params{-fields}->{$field});
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
  }elsif($params{-where}){
    $sql = "UPDATE $params{-table} SET ";
    $sql .= join (', ',map {"$_ = $fields{$_}"} @fkeys);

    if(ref($params{-where}) eq 'HASH'){
	  return $self->_error('At least one where parameter must be provided') unless scalar(%{$params{-where}});
    }elsif(ref($params{-where}) eq 'ARRAY'){
	  return $self->_error('At least one where parameter must be provided') unless scalar(@{$params{-where}});
    }else{
	  return $self->_error('Invalid -where parameter');
    }

    my $where = $self->{sqlbuilder}->buildWhere($params{-where});
    return $self->_error("Failed to build where clause") unless $where;
    $sql .= $where;
  }else{
      return $self->_error('-insert flag or -where hashref/arrayref (for updates) must be specified');
  }
  #print STDERR "sql: $sql\n";
  $self->_logDebug($sql);

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

sub insert{
    my $self = shift;
    my %params = @_;
    return $self->_error('No -table parameter specified') unless $params{-table} =~ /^[A-Za-z0-9_-]+$/;

    return $self->modify(@_,-insert => 1);
}

sub update{
    my $self = shift;
    my %params = @_;
    return $self->_error('No -table parameter specified') unless $params{-table} =~ /^[A-Za-z0-9_-]+$/;
    return $self->modify(@_,-update => 1);
}

sub getserial{
      my $self = shift;
      my $name = shift;
      my $table = shift  || 'serials';
      my $field1 = shift || 'name';
      my $field2 = shift || 'serial';
      return $self->_error('name must be specified') unless $name;

      $self->begin();

      my $row = $self->select(
			      -table => $table,
			      -field => $field2,
			      -where => {$field1 => $name},
			      -single => 1,
			      -lock => 'update',
			     );

      return $self->_error('serial select failed') unless defined($row);
      return $self->_error('serial is not primed') unless $row;

      my $id = $row->{$field2};

      return $self->_error('serial update failed') unless 
	$self->update(
		      -table => $table,
		      -fields => {$field2 => ['d',$id + 1]},
		      -where => {
				 $field1 => $name
				},
		     );

      $self->commit();

      return $id;
}

############ sequence stubs ###########
#parameters: $self,$call
sub _prepareSequence{
      return 1;
}
sub _getSequenceValue{
      return -1;
}
#######################################

sub _disconnect{
      my $self = shift;

      return $self->_error('dbh not found!') unless
	my $dbh = $self->{dbr}->{CACHE}->{$self->{name}}->{$self->{class}};
      delete $self->{dbr}->{CACHE}->{$self->{name}}->{$self->{class}};

      $dbh->disconnect();


      return 1;
}

sub AUTOLOAD {
      my $self = shift;
      my $method = $AUTOLOAD;

      my @params = @_;

      $method =~ s/.*:://;
      return unless $method =~ /[^A-Z]/; # skip DESTROY and all-cap methods
      return $self->_error('Cannot autoload query object when no schema is defined') unless $self->{schema};

      my $table = $self->{schema}->fetch_table($method) or return $self->_error("no such table '$method' exists in this schema");

      my $query = DBR::Query->new(
				  logger => $self->{logger},
				  dbh    => $self->{dbh},
				  table  => $table,
				  sqlbuilder => $self->{sqlbuilder},
				 ) or return $self->_error('failed to create query object');

      return $query;
}

sub begin{
      my $self = shift;

      return $self->_error('Already transaction - cannot begin') if $self->{'_intran'};

      my $transcache = $self->{dbr}->{'_transcache'} ||= {};
      unless($self->{config}->{nestedtrans}){
	    if( $transcache->{$self->{name}} ){
		  #already in transaction bail out
		  $self->_logDebug('BEGIN - Fake');
		  $self->{'_faketran'} = 1;
		  $self->{'_intran'} = 1;
		  $transcache->{$self->{name}}++;
		  return 1;
	    }
      }

      $self->_logDebug('BEGIN');
      my $success = $self->{dbh}->do('BEGIN');
      return $self->_error('Failed to begin transaction') unless $success;
      $self->{'_intran'} = 1;
      $transcache->{$self->{name}}++;
      return 1;
}

sub commit{
      my $self = shift;

      my $transcache = $self->{dbr}->{'_transcache'} ||= {};
      if($self->{'_faketran'}){
	    $self->_logDebug('COMMIT - Fake');
	    $self->{'_faketran'} = 0;
	    $self->{'_intran'} = 0;
	    $transcache->{$self->{name}}--;
	    return 1;
      }

      return $self->_error('Not in transaction - cannot commit') unless $self->{'_intran'};
      $self->_logDebug('COMMIT');
      my $success = $self->{dbh}->do('COMMIT');
      return $self->_error('Failed to commit transaction') unless $success;
      $self->{'_intran'} = 0;
      $transcache->{$self->{name}}--;

      return 1;
}

sub rollback{
      my $self = shift;

      my $transcache = $self->{dbr}->{'_transcache'} ||= {};
      if($self->{'_faketran'}){
	    $self->_logDebug('ROLLBACK - Fake');
	    $self->{'_faketran'} = 0;
	    $self->{'_intran'} = 0;
	    $transcache->{$self->{name}}--;
	    #$self->{dbh}->{'AutoCommit'} = 1;
	    return 1;
      }

      return $self->_error('Not in transaction - cannot rollback') unless $self->{'_intran'};

      $self->_logDebug('ROLLBACK');
      my $success = $self->{dbh}->do('ROLLBACK');
      #$self->{dbh}->{'AutoCommit'} = 1;
      return $self->_error('Failed to roll back transaction') unless $success;
      $self->{'_intran'} = 0;
      $transcache->{$self->{name}}--;
      return 1;
}

sub DESTROY{
    my $self = shift;

    $self->rollback() if $self->{'_intran'};

}

1;
 
