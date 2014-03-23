package DBR::Config::Table::Common;

use strict;
use base 'DBR::Common';
use Carp;

sub alias{
      my $self = shift;
      my $set = shift;
      if($set){
	    croak "Cannot set the alias on a table object twice" if defined( $self->{alias} ); # I want this to fail obnoxiously
	    return $self->{alias} = $set;
      }

      return $self->{alias};

}

sub validate { 1 }

sub sql  {
      my $self = shift;
      my $conn = shift;
      my $name  = $self->name;
      my $alias = $self->alias;

      my $instance = $self->sql_instance or confess('failed to fetch instance');
      my $sql = $conn->can('qualify_table') ? $conn->qualify_table($instance, $name) : $conn->quote_identifier($name);
      $sql   .= ' AS ' . $conn->quote_identifier($alias) if $alias;

      return $sql;
}

1;
