package DBR::Query::Record;

use strict;
use base 'DBR::Common';

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		  sth    => $params{sth},
		  query  => $params{query},
		 };

      bless( $self, $package );

      return $self->_error('sth object must be specified') unless $self->{sth};

      #prime the pump
      $self->{next} = '_first';

      return( $self );
}

sub set{

}

1;
