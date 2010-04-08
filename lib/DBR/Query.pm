# the contents of this file are Copyright (c) 2004-2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query;

use strict;
use Carp;

sub new {
      my( $package, %params ) = @_;

      croak "Can't create a query object directly, must create a subclass for the given query type"
	if ref($self) eq __PACKAGE__;

      $self->{instance} || croak "instance is required";
      $self->{session}  || croak "session is required";

      for (qw'tables fields set where limit lock quiet_error'){
	    $self->$_($params{$_}) if exists $params{$_};
      }

      return( $self );
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

      $self->{tables}   = [@$tables]; # shallow clone
      $self->{aliasmap} = \%aliasmap;

      return $self;
}


sub where{
      my $self = shift;
      exists( $_[0] )  or return $self->{where} || undef;
      my $part = shift || undef;

      !$part || ref($part) =~ /^DBR::Query::Part::(And|Or|Compare|Subquery|Join)$/ ||
	croak('param must be an AND/OR/COMPARE/SUBQUERY/JOIN object');

      $self->{where} = $part;

      return $self;
}

sub limit{
  my $self = shift;
  exists( $_[0] ) or return $self->{limit} || undef;
  $self->{limit} = shift || undef;

  return $self;
}

sub lock{
  my $self = shift;
  exists( $_[0] ) or return $self->{lock} || undef;
  $self->{lock} = shift() ? 1 : 0;

  return $self;
}

sub quiet_error{
  my $self = shift;
  exists( $_[0] ) or return $self->{quiet_error} || undef;
  $self->{quiet_error} = shift() ? 1 : 0;

  return $self;
}

sub clone{
      my $self = shift;
      return bless({%$self},$self);
}

sub instance { $_[0]{instance} }
sub _session { $_[0]{session} }
sub session  { $_[0]{session} }
sub scope    { $_[0]{scope} }

sub can_be_subquery { 0 }
sub validate{ 0 }         # Base class is never valid

1;
