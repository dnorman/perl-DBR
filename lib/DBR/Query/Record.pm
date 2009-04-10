package DBR::Query::ResultSet;

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

sub next {
      my $self = shift;

      my $func = $self->{next};
      return $self->$func;
}

sub _first{
      my $self = shift;

      my $sth = $self->{sth};

      $self->{rowcount} = $sth->execute();
      return $self->_error('failed to execute statement') unless defined($self->{rowcount});
      $self->{finished} = 0;

      $self->_logDebug("ROWS: $self->{rowcount}");
      $self->{record_idx} = 0;
      if ($self->{rowcount} > 200) {
	    $self->{next} = '_fetch';

	    return $self->_fetch();
      }else{
	    $self->{rows} = $sth->fetchall_arrayref();
	    $self->{sth}->finish();
	    $self->{finished} = 1;
	    $self->{next} = '_nextmem';

	    return $self->_nextmem();
      }
}

sub _nextmem{
      my $self = shift;

      my $row = $self->{rows}->[ $self->{record_idx}++ ];

      $self->_logDebug('DID NEXTMEM');

      if ($self->{record_idx} >= $self->{rowcount}){
	    $self->{finished} = 1;
	    $self->{next} = '_reset';
      }

      return $row;
}


sub _fetch{
      my $self = shift;

      my $row  = $self->{sth}->fetchrow_arrayref();

      $self->{record_idx}++;

      $self->_logDebug('DID FETCH');
      if ($self->{record_idx} >= $self->{rowcount}){
	    $self->{finished} = 1;
	    $self->{next} = '_reset';
      }


      return $row;
}

sub _reset{
      my $self = shift;
      $self->_logDebug('DID RESET');
      $self->{record_idx} = 0;

      return undef;
}

sub DESTROY{
      my $self = shift;

      $self->{finished} || $self->{sth}->finish();

      return 1;
}

1;
