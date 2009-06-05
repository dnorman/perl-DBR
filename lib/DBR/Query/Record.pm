# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Record;
use strict;
use Carp;

###################
#
# This package serves as a base class for all dynamically created record objects
#
###################


# This version of get is less efficient for fields that aren't prefetched, but much faster overall I think
sub get{
      my $self = shift;
      wantarray?(map { $self->$_ } map { split(/\s+/,$_) } @_) : [ map { $self->$_ } map { split(/\s+/,$_) } @_ ];
}

sub gethash{
      my $self = shift;
      my @fields = map { split(/\s+/,$_) } @_;

      my %ret;
      @ret{@fields} =  map { ($self->$_) } @fields;
      wantarray?( %ret ) : \%ret;
}

# sub set {
#       # helper     $self, args
#       $_[0][1]->set($_[0],@_);
# }

sub next { croak "Can not call next on a record" }

#sub DESTROY { print STDERR "RECORD DESTROY $_[0]\n"}
1;
