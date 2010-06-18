package DBR::ResultSet::DB;

use strict;
use base 'DBR::ResultSet';
use DBR::Record::Maker;
use Carp;
use Scalar::Util 'weaken';
use constant ({
	       f_next      => 0,
	       f_state     => 1,
	       f_rowcache  => 2,
	       f_sth       => 3,
	       f_count     => 4,
	       f_estimated => 5,
	       f_session   => 6,
	       f_query     => 7,

	       CLEAN  => 1,
	       ACTIVE => 2,
	       FIRST  => \&_first,
	       DUMMY  => bless([],'DBR::Misc::Dummy'),
	      });

# sub new {
#       my $package = shift;
#       my %params = @_;

#       return bless ([
# 		     FIRST, # next
# 		     CLEAN, # state
# 		     undef, # sth
# 		     undef, # real_count
# 		     undef, # rows_hint
# 		     \ [],  # rowcache. sacrificial arrayref. scalar ref stays
# 		     $params{session},
# 		     $params{query}
# 		    ], $package );

# }

# sub next { $_[0][f_next]->( $_[0] ) }

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  session  => $params{session},
		  query    => $params{query},
		 };

      bless( $self, $package );

      return $self->_error('query object must be specified' )   unless $self->{query};
      return $self->_error('session object must be specified')  unless $self->{session};

      #prime the pump
      $self->{next}     = FIRST;
      $self->{state}    = CLEAN;
      $self->{rowcache} = \ []; # Sacrificial arrayref. This arrayref is not preserved, but the scalarref is.

      return( $self );
}



sub next { $_[0]->{next}->( $_[0] ) }

sub count{
      my $self = shift;

      return $self->{real_count} if defined $self->{real_count};
      return $self->{rows_hint}  if defined $self->{rows_hint}; # If it's defined, we can trust it

      my $cquery = $self->{query}->transpose('Count') or croak "Failed to transpose query to a Count";

      return $self->{real_count} = $cquery->run;

      # Consider profiling min/max/avg rows returned for the scope in question
      # IF max / avg  is < 1000 just fetch all rows instead of executing another query

}

#HERE - This is total BS for now:
sub where {
       my $self = shift;
       my @where = @_;

       # No actual db ops until the last possible moment
       my $child_query = $self->[f_query]->child_query( \@where );

       return DBR::ResultSet::DB(
				 session => $self->[f_session],
				 query   => $child_query,
				 splitval => $self->['splitval'],
				);
}

###################################################
### Direct methods for DBRv1 ######################
###################################################

sub raw_arrayrefs{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref();

      $self->_end();

      return $ret;
}

sub raw_hashrefs{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_arrayref( {} );

      $self->_end();

      return $ret;

}

sub raw_keycol{
      my $self = shift;
      my $keycol = shift;

      $self->_execute or return $self->_error('failed to execute');

      my $ret = $self->{sth}->fetchall_hashref($keycol);

      $self->_end();

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

      if( $self->{state} != CLEAN ){ # already executed
	    return $self->_error('You must call reset before executing');
      }

      $self->{sth} ||= $self->{query}->run;# or confess "Failed to run query"; # only prepare once

      my $rv = $self->{sth}->execute();
      return $self->_error('failed to execute statement (' . $self->{sth}->errstr. ')') unless defined($rv);

      my $conn = $self->{query}->instance->connect('conn') or croak "Failed to fetch connection handle";
      if($conn->can_trust_execute_rowcount){
	    $self->{rows_hint} = $rv + 0;
	    $self->_logDebug3("ROWS: $self->{rows_hint}");
      }

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
      my $endsub = $self->_end_safe;

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
		   || return $endsub->()
		   ),
		    $buddy
		   ]
		  ),
		  $class
		 );
      };

      return 1;

}

# IMPORTANT NOTE: (circular reference hazard)
#
# We can't use $self->reset in the closure generated by _dbfetch_iterator
# due to the fact that it causes a circular reference to be created.
# Example:
# $self->{whatever} = sub { $self->foo }  #<--  FIRE BADDDD!
#
# So we weaken the $self reference using Scalar::Util::weaken, and make a wrapper for _end
#
sub _end_safe{
      my $self = shift;

      weaken ($self); # Weaken the refcount

      return sub {
	    defined($self) or return undef; # technically this could be out of scope because it's a weak ref
	    $self->_end;

	    return DUMMY; # evaluates to false
      }
}

sub _end{
      my $self = shift;
      $self->{real_count} ||= $self->{sth}->rows || 0; # Sqlite doesn't give any rowcount, so we have to use this as a fallback

      $self->reset;

      return undef;
}

sub reset{
      my $self = shift;

      $self->{sth}->finish();
      $self->{state} = CLEAN;
      $self->{next}  = \&_first;

      #$self->_logDebug3('DID RESET');

      return 1;
}

sub DESTROY{
      my $self = shift;
      # DON'T Purge my rowcache!, cus other objects might still have a copy of it

      #print STDERR "ResultSet::DB DESTROY  ($self,\t$self->{state}, \t$self->{sth})\n";
      $self->{state} == CLEAN || $self->{sth}->finish();

      return 1;
}

1;
