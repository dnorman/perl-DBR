# The contents of this file are Copyright (c) 2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::Insert;

use strict;
use base 'DBR::Query::Part';

sub sets{
      my $self = shift;
      scalar(@_) || croak('must provide at least one set');

      for (@_){
	    ref($_) eq 'DBR::Query::Part::Set' || croak('arguments must be Sets');
      }

      $self->{sets} = [@_];

      return 1;
}

sub sql{
      my $self = shift;

      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');
      my $sql;
      my $tables = join(',', map {$_->sql} @{$self->{tables}} );

      my @fields;
      my @values;
      for ( $self->{sets} ) {
	    push @fields, $_->field->sql( $conn );
	    push @values, $_->value->sql( $conn );
      }

      $sql = "INSERT INTO $tables (" . join (', ', @fields) . ') values (' . join (', ', @values) . ')';

      $sql .= ' WHERE ' . $self->{where}->sql( $conn ) if $self->[v_where];
      $sql .= ' FOR UPDATE'                            if $self->[v_lock];
      $sql .= ' LIMIT ' . $self->{limit}               if $self->[v_limit];

      $self->_logDebug2( $sql );
      return $sql;
}

sub execute{
      my $self = shift;
      my %params = @_;

      my $conn = $self->instance->connect('conn') or return $self->_error('failed to connect');

      $conn->quiet_next_error if $self->quiet_error;
      $conn->prepSequence() or confess 'Failed to prepare sequence';

      my $rows = $conn->do( $self->sql ) or return $self->_error("Insert failed");

      # Tiny optimization: if we are being executed in a void context, then we
      # don't care about the sequence value. save the round trip and reduce latency.
      return 1 if $params{void};

      my ($sequenceval) = $conn->getSequenceValue();

      return $sequenceval;

}

1;
