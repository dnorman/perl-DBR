package DBR::Query::Part::OrderBy;

use strict;
use base 'DBR::Query::Part';

sub new{
      my( $package ) = shift;
      my ($field, $direction) = @_;
      $direction ||= 'ASC';

      return $package->_error('field must be a Field object') unless ref($field) =~ /^DBR::Config::Field/; # Could be ::Anon
      return $package->_error('direction must be ASC or DESC') unless $direction =~ /^(?:ASC|DESC)\z/;

      my $self = [ $field, $direction ];

      bless( $self, $package );
      return $self;
}


sub field     { return $_[0]->[0] }
sub direction { return $_[0]->[1] }
sub sql   { return $_[0]->field->sql($_[1]) . ' ' . $_[0][1] }
sub _validate_self{ 1 }

sub validate{ 1 }

1;
