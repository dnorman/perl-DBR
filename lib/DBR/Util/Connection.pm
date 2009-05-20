# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Util::Connection;

use strict;
use base 'DBR::Common';


sub new {
      my( $package ) = shift;

      my %params = @_;
      my $self = {
		  logger  => $params{logger},
		  dbh     => $params{dbh},
		 };

      bless( $self, $package );

      return $self->_error('logger is required') unless $self->{logger};
      return $self->_error('driver is required')    unless $self->{driver};
      return $self->_error('dbh is required')    unless $self->{dbh};

      return $self;
}

sub do      { shift;  return $_->{dbh}->do(@_) }
sub prepare { shift;  return $_->{dbh}->prepare(@_) }
sub execute { shift;  return $_->{dbh}->execute(@_) }

sub begin {
      my $self = shift;
      return $self->_error('Transaction is already open - cannot begin') if $self->{'_intran'};

      $self->_logDebug('BEGIN');
      $self->{dbh}->do('BEGIN') or return $self->_error('Failed to begin transaction');
      $self->{_intran} = 1;

      return 1;
}

sub commit{
      my $self = shift;
      return $self->_error('Transaction is not open - cannot commit') if !$self->{'_intran'};

      $self->_logDebug('COMMIT');
      $self->{dbh}->do('COMMIT') or return $self->_error('Failed to commit transaction');

      $self->{_intran} = 0;

      return 1;
}

sub rollback{
      my $self = shift;
      return $self->_error('Transaction is not open - cannot rollback') if !$self->{'_intran'};

      $self->_logDebug('ROLLBACK');
      $self->{dbh}->do('ROLLBACK') or return $self->_error('Failed to rollback transaction');

      $self->{_intran} = 0;

      return 1;
}


############ sequence stubs ###########
sub prepSequence{
      return 1;
}
sub getSequenceValue{
      return -1;
}
#######################################

sub b_intrans{ $_[0]->{_intran} ? 1:0 }
sub b_nestedTrans{ 0 }



1;
