package DBR::Query::ResultSet::DB;

use strict;
use base 'DBR::Query::ResultSet';
use DBR::Query::RecMaker;
use Carp;

use constant {
        LOGGER   => 0,
	QUERY    => 1,
	STH      => 2,
        CACHE    => 3,
	NEXT     => 4,
	RECORD   => 5,
	STATE    => 6,
	COUNT    => 7

	clean    => 1,
	active   => 2,
	finished => 3,
};
sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = [ (undef)x8 ];

      $self->[QUERY]  = $params{query}  or return $self->_error('query object must be specified' );
      $self->[LOGGER] = $params{logger} or return $self->_error('logger object must be specified');

      my $cache = []; # Sacrificial arrayref. This arrayref is not preserved, but the scalarref is.
      $self->[CACHE] = \$cache; #Use the scalarref to $cache to be able to access this remotely

      #prime the pump
      $self->[NEXT] = \&_first; # Arrgh... can't do a closure containing $self here. Would be a circular reference.

      $self->[STATE] = clean;
      bless( $self, $package );

      return( $self );
}

sub next    { $_[0][NEXT]->( $_[0] ) }
sub _logger {$_->[LOGGER]} # For DBR::Common

sub _first{
      my $self = shift;

      $self->_create_iterator or return $self->_error('_create_iterator failed');

      return $self->next;
}

sub count{
      my $self = shift;

      my $count;
      if ($self->_query->is_count){
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

      my $ret = $self->_sth->fetchall_arrayref( {} );

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

sub groupby{
      
}
###################################################
### Accessors #####################################
###################################################


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

      if( $self->[STATE] != clean ){ # already executed
	    return $self->_error('You must call reset before executing');
      }
      # else Undef row pointer means we haven't executed yet

      $self->[STH] ||= $self->_query->prepare;

      my $rv = $sth->execute();
      $self->{rows_hint} = $rv + 0;
      $self->_logDebug2("ROWS: $self->{rows_hint}");
      return $self->_error('failed to execute statement') unless $rv;

      $self->[STATE] = active;

      return 1;
}

sub _create_iterator{
      my $self = shift;

      $self->_execute() or return $self->_error('failed to execute');

      my $record = $self->_query->makerecord(rowcache => )
      my $class  = $self->_query;
      my $ref   = $self->_rowcache;
      my $rows  = $$ref;
      my $sth   = $self->_sth;

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
      $self->{rowcount} ||= $self->_sth->rows; # Sqlite doesn't give any rowcount, so we have to use this as a fallback
      $self->reset;
      return undef;
}

sub reset{
      my $self = shift;
      $self->_logDebug3('DID RESET');

      $self->[STH]->finish();
      $self->[STATE] = finished;

      $self->{next} = *_first;

      return 1;
}

sub DESTROY{
      my $self = shift;
      #print STDERR "RS DESTROY\n";
      $self->[STATE] == finished || $self->_sth->finish();

      return 1;
}

1;
