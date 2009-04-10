package DBR::Enum;

use strict;
use base 'DBR::Common';

sub new {
  my( $package ) = shift;
  my %params = @_;
  my $self = {
	      logger => $params{logger},
	      dbh    => $params{dbh},
	     };

  bless( $self, $package );

  return $self->_error('dbh object must be specified')   unless $self->{dbh};

  return( $self );
}



1;
