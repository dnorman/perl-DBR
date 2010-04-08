# The contents of this file are Copyright (c) 2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Select;

use DBR::Query::ResultSet::DB;
use strict;
use Carp;

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

sub lastidx  { $_[0]{last_idx} }
sub can_be_subquery { scalar( $_[0]->fields ) == 1 || 0 }; # Must have exactly one field

sub check_table{
      my $self  = shift;
      my $alias = shift;

      return $self->{aliasmap}->{$alias} ? 1 : 0;
}

sub resultset{
      my $self = shift;

      return DBR::Query::ResultSet::DB->new(
					    session => $self->session,
					    query   => $self,
					   ) or croak('Failed to create resultset');
}


sub validate{
      my $self = shift;

      return 0 unless $self->_validate_self;

      if($self->{where}){
	    return 0 unless $self->{where}->validate( $self );
      }

      return 1;
}
sub sql{
      my $self = shift;
      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');
      my $sql;

      my $tables = join(',', map { $_->sql($conn) } @{$self->{tables}} );
      my $fields = join(',', map { $_->sql($conn) } @{$self->{fields}} );

      $sql = "SELECT $fields FROM $tables";
      $sql .= ' WHERE ' . $self->[v_where]->sql($conn) if $self->{where};
      $sql .= ' FOR UPDATE'                            if $self->{lock};
      $sql .= ' LIMIT ' . $self->[v_limit]             if $self->{limit};

      $self->_logDebug2( $sql );
      return $sql;
}

sub execute {
      my $self = shift;

      my $conn = $self->instance->connect('conn') or confess 'failed to connect';
      my $sth  = $conn->prepare( $self->sql ) or confess 'failed to prepare statement';

      return $sth;

}

# ????
# if ($field->table_alias) {
#       return $self->_error("table alias is invalid without a join") unless $self->{aliasmap};
#       return $self->_error('invalid table alias "' . $field->table_alias . '" in -fields')        unless $self->{aliasmap}->{ $field->table_alias };
# }


1;
