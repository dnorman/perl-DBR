package DBR::Query::ResultSet::DB;

use strict;
use base 'DBR::Query::ResultSet';
use DBR::Query::RecMaker;
use Carp;
use constant { CLEAN => 1, ACTIVE => 2  };

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  session   => $params{session},
		  query    => $params{query},
		 };

      bless( $self, $package );

      return $self->_error('query object must be specified' )   unless $self->{query};
      return $self->_error('session object must be specified')   unless $self->{session};

      #prime the pump
      $self->{next} = \&_first;

      my $cache = []; # Sacrificial arrayref. This arrayref is not preserved, but the scalarref is.
      $self->{rowcache} = \$cache; #Use the scalarref to $cache to be able to access this remotely

      $self->{state} = CLEAN;

      return( $self );
}



sub next { $_[0]->{next}->( $_[0] ) }

sub count{
      my $self = shift;

      return $self->{real_count} if $self->{real_count};

      my $count;
      if ($self->{query}->is_count){
	    $self->_execute or return $self->_error('failed to execute');
	    ($count) = $self->{sth}->fetchrow_array();
	    $self->{real_count} = $count;

	    $self->reset();
      }else{
	    return $self->{rows_hint}; #If we've gotten here, all we have is the rows_hint
      }

      return $count;
}


sub groupby{
      my $self = shift;
      $self->{query};
}


###################################################
### Direct methods for DBRv1 ######################
###################################################

sub raw_arrayrefs{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref();

      $self->reset();

      return $ret;
}

sub raw_hashrefs{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref( {} );

      $self->reset();

      return $ret;

}

sub raw_keycol{
      my $self = shift;
      my $keycol = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_hashref($keycol);

      $self->reset();

      return $ret;
}

###################################################
### Utility #######################################
###################################################

sub _fetch_all{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      $self->_makerecord or return $self->_error('_makerecord failed');

      ${$self->{rowcache}} = $self->{sth}->fetchall_arrayref();

      $self->_end();
      $self->_mem_iterator(); # everything is in memory now, so use _mem_iterator

      return ${$self->{rowcache}};
}

sub _execute{
      my $self = shift;

      if( $self->{state} != CLEAN){ # already executed
	    return $self->_error('You must call reset before executing');
      }
      # else Undef row pointer means we haven't executed yet

      $self->{sth} ||= $self->{query}->prepare or croak "Failed to prepare query"; # only prepare once

      my $rv = $self->{sth}->execute();
      $self->{rows_hint} = $rv + 0;
      $self->_logDebug2("ROWS: $self->{rows_hint}");
      return $self->_error('failed to execute statement') unless $rv;
      $self->{state} = ACTIVE;

      return 1;
}

sub _first{
      my $self = shift;

      $self->_execute() or return $self->_error('failed to execute');

      $self->_dbfetch_iterator;

      return $self->next;
}


sub _dbfetch_iterator{
      my $self = shift;

      $self->_makerecord or return $self->_error('_makerecord failed');
      my $ref   = $self->{rowcache};
      my $class = $self->{record}->class;
      my $buddy = $self->{buddy} or confess "No buddy object present";
      my $rows  = $$ref;
      my $sth   = $self->{sth};

      # use a closure to reduce hash lookups
      # It's very important that this closure is fast.
      # This one routine has more of an effect on speed than anything else in the rest of the code
      $self->{next} = sub {
	    bless(
		  (
		   [
		   (
		    shift(@$rows)# Shift from cache
		   || shift( @{$rows = $$ref = $sth->fetchall_arrayref(undef,1000) || [] } ) # if cache is empty, fetch more
		   || return $self->_end
		   ),
		    $buddy
		   ]
		  ),
		  $class
		 );
      };
      #    return bless ( [ fetchrow() ,$payload ], $class)

      return 1;

}

sub _end{
      my $self = shift;
      $self->{real_count} ||= $self->{sth}->rows; # Sqlite doesn't give any rowcount, so we have to use this as a fallback
      $self->reset;
      #print STDERR "END\n";
      return undef;
}



sub reset{
      my $self = shift;
      $self->_logDebug3('DID RESET');

      $self->{sth}->finish();
      $self->{state} = CLEAN;

      $self->{next} = *_first;

      return 1;
}

sub DESTROY{
      my $self = shift;
      #print STDERR "ResultSet::DB DESTROY ($self->{state})\n";

      $self->{state} == CLEAN || $self->{sth}->finish();

      return $self->SUPER::DESTROY();
}

1;
