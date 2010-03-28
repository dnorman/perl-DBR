# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query;

use strict;
use Carp;
use base 'DBR::Common';

use DBR::Query::ResultSet::DB;
my $idx = 0;
use constant ({
	       map {'v_' . $_ => $idx++}
	       qw(instance session scope action tables where limit lock aliasmap quiet_error)
	      });

sub new {
      my( $package, %params ) = @_;

      my $self = bless([ $params{instance}, $params{session}, $params{scope} ], $package );

      $self->[v_instance] || croak "instance is required";
      $self->[v_session]  || croak "session is required";

      for (qw'action tables where limit lock quiet_error'){
	    $self->$_($params{$_}) if exists $params{$_};
      }

      return( $self );
}

sub action{
  my $self = shift;
  exists( $_[0] ) or return $self->[v_action] || undef;
  my $action = shift;

  ref($action) =~ /^DBR::Query::Action::/ || croak "action must be a DBR::Query::Action:: object (" . ref($action) . ')';
  $self->[v_action] = $action;

}


sub tables{
      my $self   = shift;
      my $tables = shift;

      $tables = [$tables] unless ref($tables) eq 'ARRAY';
      scalar(@$tables) || croak "must provide at least one table";

      my @tparts;
      my %aliasmap;
      foreach my $table (@$tables){
	    croak('must specify table as a DBR::Config::Table object') unless ref($table) =~ /^DBR::Config::Table/; # Could also be ::Anon

	    my $name  = $table->name or return $self->_error('failed to get table name');
	    my $alias = $table->alias;
	    $aliasmap{$alias} = $name if $alias;
      }

      $self->[v_tables]   = [@$tables]; # shallow clone
      $self->[v_aliasmap] = \%aliasmap;

      return $self;
}


sub where{
      my $self = shift;
      exists( $_[0] )  or return $self->[v_where] || undef;
      my $part = shift || undef;

      !$part || ref($part) =~ /^DBR::Query::Part::(And|Or|Compare|Subquery|Join)$/ ||
	croak('param must be an AND/OR/COMPARE/SUBQUERY/JOIN object');

      $self->[v_where] = $part;

      return $self;
}

sub limit{
  my $self = shift;
  exists( $_[0] ) or return $self->[v_limit] || undef;
  $self->[v_limit] = shift || undef;

  return $self;
}

sub lock{
  my $self = shift;
  exists( $_[0] ) or return $self->[v_lock] || undef;
  $self->[v_lock] = shift() ? 1 : 0;

  return $self;
}

sub quiet_error{
  my $self = shift;
  exists( $_[0] ) or return $self->[v_quiet_error] || undef;
  $self->[v_quiet_error] = shift() ? 1 : 0;

  return $self;
}

sub clone{
      my $self = shift;
      return bless([@$self],$self);
}

sub instance { $_[0][v_instance] }
sub _session { $_[0][v_session] }
sub session  { $_[0][v_session] }
sub scope    { $_[0][v_scope] }

sub can_be_subquery {
      my $self = shift;
      my $select = $self->[v_select] || return 0;   # must be a select
      return scalar($select->fields) == 1 || 0; # and have exactly one field
}

sub validate{
      my $self = shift;

      my @parts = grep { defined } @$self{qw'select insert update delete'};
      unless (scalar(@parts) == 1){
	    $self->_error('Must specify one of: select, insert, update or delete');
	    return 0;
      }

      return 0 unless $parts[0]->validate( $self );

      if($self->[v_where]){
	    return 0 unless $self->[v_where]->validate( $self );
      }

      return 1;
}

sub check_table{
      my $self  = shift;
      my $alias = shift;

      return $self->[v_aliasmap]->{$alias} ? 1 : 0;
}

sub resultset{
      my $self = shift;

      return DBR::Query::ResultSet::DB->new(
					    session => $self->session,
					    query   => $self,
					   ) or croak('Failed to create resultset');
}

# do not run this until the last possible moment, and then only once
sub sql{
      my $self = shift;

      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');
      my $sql;
      my $tables = join(',', map {$_->sql} @{$self->[v_tables]} );

      if (    $self->[v_select] ){
	    $sql = "SELECT " . $self->[v_select]->sql($conn) . " FROM $tables";

      }elsif( $self->[v_insert] ){
	    $sql = "INSERT INTO $tables " . $self->[v_insert]->sql($conn);

      }elsif( $self->[v_update] ){
	    $sql = "UPDATE $tables SET "  . $self->[v_update]->sql($conn);

      }elsif( $self->[v_delete] ){
	    $sql = "DELETE FROM $tables";

      }

      $sql .= ' WHERE ' . $self->[v_where]->sql($conn) if $self->[v_where];
      $sql .= ' FOR UPDATE'                            if $self->[v_lock];
      $sql .= ' LIMIT ' . $self->[v_limit]             if $self->[v_limit];

      return $sql;
}

sub prepare {
      my $self = shift;

      croak('can only call prepare on a select') unless $self->[v_select];

      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');

      my $sql = $self->sql;

      $self->_logDebug2( $sql );

      return $self->_error('failed to prepare statement') unless
	my $sth = $conn->prepare($sql);

      return $sth;

}

sub execute{
      my $self = shift;
      my %params = @_;

      my $sql = $self->sql;
      $self->_logDebug2( $sql );

      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');

      $conn->quiet_next_error if $self->quiet_error;

      if($self->[v_insert]){

	    $conn->prepSequence() or return $self->_error('Failed to prepare sequence');

	    my $rows = $conn->do( $sql ) or return $self->_error("Insert failed");

	    # Tiny optimization: if we are being executed in a void context, then we
	    # don't care about the sequence value. save the round trip and reduce latency.
	    return 1 if $params{void};

	    my ($sequenceval) = $conn->getSequenceValue();
	    return $sequenceval;

      }elsif($self->[v_update] || $self->[v_delete] ){
	    return $conn->do( $sql ) || 0;

      }elsif($self->[v_select]){
	    return $self->_error('cannot call execute on a select');
      }

      return $self->_error('invalid query type')
}

1;
