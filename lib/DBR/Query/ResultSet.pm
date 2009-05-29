package DBR::Query::ResultSet;

use strict;
use base 'DBR::Query::ResultSet::Common';
use DBR::Query::RecMaker;
use Carp;
use DBR::Query::ResultSet::Lite;

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

      my $cache = []; # Sacrificial arrayref. This arrayref is not preserved, but the scalarref is.
      $self->{rowcache} = \$cache; #Use the scalarref to $cache to be able to access this remotely

      return( $self );
}



sub next { $_[0]->{next}->( $_[0] ) }

sub count{
      my $self = shift;

      my $count;
      if ($self->{is_count}){
	    return $self->{real_count} if $self->{real_count};

	    $self->_execute or return $self->_error('failed to execute');
	    ($count) = $self->{sth}->fetchrow_array();
	    $self->{real_count} = $count;

	    $self->reset();
      }else{
	    return $self->{rowcount} || $self->{rows_hint}; # rowcount should be authoritative, but fail over to the hint
      }

      return $count;
}

sub raw_hashrefs{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref( {} );

      $self->reset();

      return $ret;

}

sub split{
      my $self = shift;
      my $field = shift;


      my $idx = $field->index;
      return $self->_error('field object must provide an index') unless defined($idx);

      $self->_makerecord or return $self->_error('failed to make record class');

      my $rows = $self->_allrows or return $self->_error('_allrows failed');
      my $code = 'map { push @{$groupby{ $_->[' . $idx . '] }}, $_ } @{ $rows }';
      $self->_logDebug3($code);

      my %groupby;
      eval $code;

      my $class = ref($self) . '::Lite';
      foreach my $key (keys %groupby){
	    $groupby{$key} = DBR::Query::ResultSet::Lite->new(
							      logger  => $self->{logger},
							      rows    => $groupby{$key},
							      query   => $self->{query},
							      record  => $self->{record}, #keep RecMaker object in scope);
							     ) or return $self->_error('failed to create resultset lite object');
      }

      return \%groupby;
}




###################################################
### Utility #######################################
###################################################

sub _allrows{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref();

      $self->reset();

      return $ret;
}

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

      $self->_makerecord or return $self->_error('failed to make record class');

      $self->_execute() or return $self->_error('failed to execute');

      $self->_iterator_prep;

      return $self->next;
}


sub _iterator_prep{
      my $self = shift;

      my $ref  = $self->{rowcache};
      my $rows = $$ref;
      my $class = $self->{record}->class;
      my $sth   = $self->{sth};

      # use a closure to reduce hash lookups
      # It's very important that this closure is fast.
      # This one routine has more of an effect on speed than anything else in the rest of the code
      $self->{next} = sub {
	    bless(
		  (
		   shift(@$rows)# Shift from cache
		   || shift( @{$rows = $$ref = $sth->fetchall_arrayref(undef,1000) || [] } ) # if cache is empty, fetch more
		   || return $self->_end
		  ),
		  $class
		 );
      };

      return 1;

}

sub _end{
      my $self = shift;
      $self->{rowcount} ||= $self->{sth}->rows; # Sqlite doesn't give any rowcount, so we have to use this as a fallback
      $self->reset;
      return undef;
}


sub _makerecord{
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

      return 1;
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
