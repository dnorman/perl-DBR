# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Record;
use strict;

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

1;
