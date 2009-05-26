package DBR::Query::ResultSet;

use strict;
use base 'DBR::Common';
use DBR::Query::RecMaker;
use Carp;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger   => $params{logger},
		  instance => $params{instance},
		  sth      => $params{sth},
		  query    => $params{query},
		  is_count => $params{is_count},
		 };

      bless( $self, $package );

      return $self->_error('sth object must be specified'   )   unless $self->{sth};
      return $self->_error('query object must be specified' )   unless $self->{query};
      return $self->_error('logger object must be specified')   unless $self->{logger};
      return $self->_error('instance object must be specified') unless $self->{instance};

      #prime the pump
      $self->{next} = *_first;

      $self->{rowcache} = [];

      return( $self );
}



sub next { $_[0]->{next}->( $_[0] ) }
sub delete {croak "Mass delete is not allowed. No cookie for you!"}


sub set{
      my $self = shift;
      my %fields = @_;

      
   #    my $setvalue = $field->makevalue($value) or return $self->_error('failed to create setvalue object');
    #   my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');


};

sub count{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $count;
      if ($self->{is_count}){
	    ($count) = $self->{sth}->fetchrow_array();
	    $self->reset();
      }else{
	    return $self->{rowcount} || $self->{rows_hint}; # rowcount should be authoritative, but fail over to the hint
      }

      return $count;
}

sub hashrefs{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref( {} );

      $self->reset();

      return $ret;

}

sub arrayrefs{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref();

      $self->reset();

      return $ret;
}

sub map {
      my $self = shift;
      my @fields = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_hashref(@fields);

      $self->reset();

      return $ret;
}







###################################################
### Utility #######################################
###################################################

sub _execute{
      my $self = shift;

      if( $self->{active} ){ # already executed
	    return $self->_error('You must call reset before executing');
      }
      # else Undef row pointer means we haven't executed yet

      my $sth = $self->{sth};

      my $rv = $sth->execute();
      $self->{rows_hint} = $rv + 0;
      $self->_logDebug2("ROWS: $self->{rows_hint}");
      return $self->_error('failed to execute statement') unless $rv;
      $self->{finished} = 0;
      $self->{active} = 1;

      return 1;
}

sub _first{
      my $self = shift;

      if(!$self->{record}){
	    $self->_stopwatch();
	    my $record = DBR::Query::RecMaker->new(
						   instance => $self->{instance},
						   logger   => $self->{logger},
						   query    => $self->{query},
						   rowcache => $self->{rowcache}, # Would prefer to pass the resultset object itself, but that would cause a circular refrence
						  ) or return $self->_error('failed to create record class');

	    # need to keep this in scope, because it removes the dynamic class when DESTROY is called
	    $self->{record} = $record;

	    $self->_stopwatch('recmaker');
      }

      $self->_execute() or return $self->_error('failed to execute');

      $self->_iterator_prep;

      return $self->next;
}


sub _iterator_prep{
      my $self = shift;

      my $rows  = $self->{rowcache};
      my $class = $self->{record}->class;
      my $sth   = $self->{sth};

      # use a closure to reduce hash lookups
      # It's very important that this closure is fast.
      # This one routine has more of an effect on speed than anything else in the rest of the code
      $self->{next} = sub {
	    my $row = (
		       shift(@$rows) or # Shift from cache
		       shift( @{$rows = $sth->fetchall_arrayref(undef,1000) || [] } ) # if cache is empty, fetch more
		       or return $self->_end
		      );

	    return bless($row,$class);
      };

      return 1;

}

sub _end{
      my $self = shift;
      print STDERR "END\n";
      $self->reset;
      return undef;
}

sub reset{
      my $self = shift;
      $self->_logDebug3('DID RESET');

      $self->{sth}->finish();
      $self->{finished} = 1;
      $self->{active} = 0;

      $self->{next} = *_first;

      return 1;
}

sub DESTROY{
      my $self = shift;
      #print STDERR "RS DESTROY\n";
      $self->{finished} || $self->{sth}->finish();

      return 1;
}

1;
