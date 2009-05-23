# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Util::Connection;

use strict;
use base 'DBR::Common';

sub required_config_fields { [qw(database hostname user password)] };

sub new {
      my( $package ) = shift;

      my %params = @_;
      my $self = {
		  logger  => $params{logger},
		  dbh     => $params{dbh},
		 };

      bless( $self, $package );

      return $self->_error('logger is required') unless $self->{logger};
      return $self->_error('dbh is required')    unless $self->{dbh};
      $self->{lastping} = time; # assume the setup of the connection as being a good ping

      return $self;
}

sub dbh     { $_[0]->{dbh} }
sub do      { my $self = shift;  return $self->_wrap($self->{dbh}->do(@_))       }
sub prepare { my $self = shift;  return $self->_wrap($self->{dbh}->prepare(@_))  }
sub execute { my $self = shift;  return $self->_wrap($self->{dbh}->execute(@_))  }
sub disconnect { my $self = shift; return $self->_wrap($self->{dbh}->disconnect(@_))  }
sub quote { my $self = shift;  return $self->{dbh}->quote(@_)  }

sub ping {
      my $self = shift;

      $self->_logDebug2('PING');
      return 1 if $self->{lastping} + 5 > time; # only ping every 5 seconds
      $self->{dbh}->ping or return undef;
      $self->{lastping} + 5 > time;
      return 1;
}

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

sub quiet_next_error{
      my $self = shift;

      $self->{dbh}->{PrintError} = 0;

      return 1;
}

sub _wrap{
      my $self = shift;

      #reset any variables now
      $self->{dbh}->{PrintError} = 1;

      return wantarray?@_:$_[0];
}
1;
