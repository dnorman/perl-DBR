# The contents of this file are Copyright (c) 2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Update;

use strict;
use base 'DBR::Query';
use Carp;

sub _params    { qw (sets table where limit quiet_error) }
sub _reqparams { qw (sets table) }
sub _validate_self{ 1 } # If I exist, I'm valid

sub sets{
      my $self = shift;
      scalar(@_) || croak('must provide at least one set');

      for (@_){
	    ref($_) eq 'DBR::Query::Part::Set' || croak('arguments must be Sets');
      }

      $self->{sets} = [@_];

      return 1;
}

# do not run this until the last possible moment, and then only once
sub sql{
      my $self = shift;

      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');
      my $sql;
      my $tables = join(',', map { $_->sql( $conn ) } @{$self->{tables}} );
      my $sets   = join(',', map { $_->sql( $conn ) } @{$self->{sets}}   );

      $sql = "UPDATE $tables SET $sets";
      $sql .= ' WHERE ' . $self->{where}->sql($conn) if $self->{where};
      $sql .= ' FOR UPDATE'                          if $self->{lock};
      $sql .= ' LIMIT ' . $self->{limit}             if $self->{limit};

      $self->_logDebug2( $sql );
      return $sql;
}

sub run{
      my $self = shift;
      my $conn = $self->instance->connect('conn') or return $self->_error('failed to connect');

      $conn->quiet_next_error if $self->quiet_error;

      return $conn->do( $self->sql ) || 0;
}

1;
