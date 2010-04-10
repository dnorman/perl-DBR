# The contents of this file are Copyright (c) 2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Select;

use strict;
use base 'DBR::Query';
use Carp;
use DBR::ResultSet::DB;

sub _params    { qw (fields table where limit lock quiet_error) }
sub _reqparams { qw (fields table) }
sub _validate_self{ 1 } # If I exist, I'm valid

sub fields{
      my $self = shift;
      scalar(@_) || croak('must provide at least one field');

      my $lastidx = -1;
      for (@_){
	    ref($_) =~ /^DBR::Config::Field/ || croak('must specify field as a DBR::Config::Field object'); # Could also be ::Anon
	    $_->index( ++$lastidx );
      }
      $self->{last_idx} = $lastidx;
      $self->{fields} = [ @_ ];

      return 1;
}


sub sql{
      my $self = shift;
      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');
      my $sql;

      my $tables = join(',', map { $_->sql($conn) } @{$self->{tables}} );
      my $fields = join(',', map { $_->sql($conn) } @{$self->{fields}} );

      $sql = "SELECT $fields FROM $tables";
      $sql .= ' WHERE ' . $self->{where}->sql($conn) if $self->{where};
      $sql .= ' FOR UPDATE'                          if $self->{lock};
      $sql .= ' LIMIT ' . $self->{limit}             if $self->{limit};

      $self->_logDebug2( $sql );
      return $sql;
}

sub run {
      my $self = shift;

      my $conn = $self->instance->connect('conn') or confess 'failed to connect';
      my $sth  = $conn->prepare( $self->sql ) or confess 'failed to prepare statement';

      return $sth;

}

sub lastidx  { $_[0]{last_idx} }
sub can_be_subquery { scalar( $_[0]->fields ) == 1 || 0 }; # Must have exactly one field
sub resultset{
      my $self = shift;

      return DBR::Query::ResultSet::DB->new(
					    session => $self->session,
					    query   => $self,
					   ) or croak('Failed to create resultset');
}


1;
