# the contents of this file are Copyright (c) 2004-2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Handle;

use strict;
use base 'DBR::Common';
use DBR::Query;
use DBR::Object;
use DBR::Interface::DBRv1;
our $AUTOLOAD;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  conn     => $params{conn},
		  logger   => $params{logger},
		  instance => $params{instance}
		 };

      bless( $self, $package );

      return $self->_error( 'conn object is required'         ) unless $self->{conn};
      return $self->_error( 'instance parameter is required'  ) unless $self->{instance};

      $self->{schema} = $self->{instance}->schema();
      return $self->_error( 'failed to retrieve schema' ) unless defined($self->{schema}); # schema is not required

      # Temporary solution to interfaces
      $self->{dbrv1} = DBR::Interface::DBRv1->new(
						  logger  => $self->{logger},
						  instance => $self->{instance},
						 ) or return $self->_error('failed to create DBRv1 interface object');

      return( $self );
}

#sub _conn   { $_[0]->{conn}    } # Connection object

sub select{ my $self = shift; return $self->{dbrv1}->select(@_) }
sub insert{ my $self = shift; return $self->{dbrv1}->insert(@_) }
sub update{ my $self = shift; return $self->{dbrv1}->update(@_) }
sub delete{ my $self = shift; return $self->{dbrv1}->delete(@_) }

sub AUTOLOAD {
      my $self = shift;
      my $method = $AUTOLOAD;

      my @params = @_;

      $method =~ s/.*:://;
      return unless $method =~ /[^A-Z]/; # skip DESTROY and all-cap methods
      return $self->_error("Cannot autoload '$method' when no schema is defined") unless $self->{schema};

      my $table = $self->{schema}->get_table( $method ) or return $self->_error("no such table '$method' exists in this schema");

      my $object = DBR::Object->new(
				    logger   => $self->{logger},
				    instance => $self->{instance},
				    table    => $table,
				   ) or return $self->_error('failed to create query object');

      return $object;
}

sub begin{
      my $self = shift;

      return $self->_error('Already transaction - cannot begin') if $self->{'_intran'};

      my $conn = $self->{conn};

      if ( $conn->b_intrans && !$conn->b_nestedTrans ){ # No nested transactions
	    $self->_logDebug('BEGIN - Fake');
	    $self->{'_faketran'} = $self->{'_intran'} = 1; #already in transaction, we are not doing a real begin
	    return 1;
      }

      $conn->begin or return $self->_error('Failed to begin transaction');

      $self->{'_intran'} = 1;
      return 1;

}
sub commit{
      my $self = shift;
      return $self->_error('Not in transaction - cannot commit') unless $self->{'_intran'};

      my $conn = $self->{conn};

      if($self->{'_faketran'}){
	    $self->_logDebug('COMMIT - Fake');
	    $self->{'_faketran'} = $self->{'_intran'} = 0;

	    return 1;
      }

      $conn->commit or return $self->_error('Failed to commit transaction');

      $self->{'_intran'} = 0;
      return 1;
}

sub rollback{
      my $self = shift;
      return $self->_error('Not in transaction - cannot rollback') unless $self->{'_intran'};

      my $conn = $self->{conn};
      if($self->{'_faketran'}){

	    $self->_logDebug('ROLLBACK - Fake');
	    $self->{'_faketran'} = $self->{'_intran'} = 0;

	    return 1;
      }

      $conn->rollback or return $self->_error('Failed to roll back transaction');

      $self->{'_intran'} = 0;
      return 1;
}

sub DESTROY{
    my $self = shift;

    $self->rollback() if $self->{'_intran'};

}

1;
