# the contents of this file are Copyright (c) 2004-2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query;
use base 'DBR::Common';
use strict;
use Carp;

sub new {
      my( $package, %params ) = @_;

      ref($package) ne __PACKAGE__ || croak "Can't create a query object directly, must create a subclass for the given query type";
      my $self = bless({},$package);

      $self->{instance} = $params{instance} || croak "instance is required";
      $self->{session}  = $params{session}  || croak "session is required";
      $self->{scope}    = $params{scope};

      my %req = map {$_ => 1} $self->_reqparams;
      for my $key ( $self->_params ){

	    if(  $params{$key} ){
		  $self->$key( $params{$key} );

	    }elsif($req{$key}){
		  croak "$key is required";
	    }
      }

      $self->validate() or croak "Object is not valid"; # HERE - not enough info as to why

      return $self;
}

sub tables{
      my $self   = shift;
      exists( $_[0] )  or return wantarray?( @$self->{tables} ) : $self->{tables} || undef;
      my @tables = $self->_arrayify(@_);

      scalar(@tables) || croak "must provide at least one table";

      my @tparts;
      my %aliasmap;
      foreach my $table (@tables){
	    croak('must specify table as a DBR::Config::Table object') unless ref($table) =~ /^DBR::Config::Table/; # Could also be ::Anon

	    my $name  = $table->name or return $self->_error('failed to get table name');
	    my $alias = $table->alias;
	    $aliasmap{$alias} = $name if $alias;
      }

      $self->{tables}   = \@tables;
      $self->{aliasmap} = \%aliasmap;

      return $self;
}

sub check_table{
      my $self  = shift;
      my $alias = shift;

      return $self->{aliasmap}->{$alias} ? 1 : 0;
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

sub validate{
      my $self = shift;

      return 0 unless $self->_validate_self; # make sure I'm sane

      # Now check my component objects
      if($self->{where}){
	    $self->{where}->validate( $self ) or croak "Invalid where clause";
      }

      return 1;
}

1;
