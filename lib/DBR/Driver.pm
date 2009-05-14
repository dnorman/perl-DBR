package DBR::Driver;

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

      return $self->_error( 'logger parameter is required' ) unless $self->{logger};

      return( $self );
}

############ sequence stubs ###########
sub prepSequence{
      return 1;
}
sub getSequenceValue{
      return -1;
}
#######################################

1;
