package DBR::ResultSet;

use strict;
use base 'DBR::Common';

use DBR::Misc::Dummy;
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

	       t_DIRECT => 1,
	       t_SPLIT  => 2,

	       CLEAN  => 1,
	       ACTIVE => 2,
	       FIRST  => \&_first,
	       DUMMY  => bless([],'DBR::Misc::Dummy'),
	      });


sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  state    => CLEAN,
		  type     => t_DIRECT,
		  session  => $params{session},
		  query    => $params{query},
		  #record   => $params{record}, HERE?
		  #buddy    => $params{buddy}, HERE ?
		 };

      bless( $self, $package );

      return $self->_error('query object must be specified' )   unless $self->{query};
      return $self->_error('session object must be specified')  unless $self->{session};
      #return $self->_error('record object must be specified') unless $self->{record}; HERE?

      #prime the pump
      $self->{next}     = FIRST;
      if(defined($params{splitvalue})){
	    $self->{splitval}   = $params{splitvalue}; # HERE HERE HERE this is not efficient
	    $self->{type}     = t_SPLIT;
	    #$self->_makerecord or return $self->_error('_makerecord failed'); HERE?

      }
      $self->{rowcache} = \ []; # Sacrificial arrayref. This arrayref is not preserved, but the scalarref is.

      return( $self );
}


sub next { $_[0]->{next}->( $_[0] ) }

sub _first{
      my $self = shift;

      $self->_execute() or return $self->_error('failed to execute');
      return $self->next;
}

sub _execute{
      my $self = shift;

      $self->_makerecord or confess '_makerecord failed';
      if($self->{type} == t_SPLIT){
	    $self->{query}->run;
	    my $rows = ${$self->{rowcache}} = $self->{query}->fetch_for($self->{splitval});

	    $self->_mem_iterator;
	    $self->{real_count} = @$rows;
      }else{
	    
	    $self->{state} == CLEAN or confess 'Sanity error: must call reset before executing';

	    $self->{sth} ||= $self->{query}->run;
	    defined( my $rv = $self->{sth}->execute ) or confess 'failed to execute statement (' . $self->{sth}->errstr. ')';

	    my $conn = $self->{query}->instance->getconn or croak "Failed to fetch connection handle";
	    if($conn->can_trust_execute_rowcount){
		  $self->{rows_hint} = $rv + 0;
		  $self->_logDebug3("ROWS: $self->{rows_hint}");
	    }

	    $self->{state} = ACTIVE;
	    $self->_db_iterator;

      }

      return 1;
}

sub _fetch_all{
      my $self = shift;

      $self->_execute or return $self->_error('failed to execute');

      if( $self->{type} == t_SPLIT ){
	    return ${$self->{rowcache}};
      }else{
	    # HERE HERE HERE - this needs some TLC
	    ${$self->{rowcache}} = $self->{sth}->fetchall_arrayref();

	    $self->_end();
	    $self->_mem_iterator(); # everything is in memory now, so use _mem_iterator

	    return ${$self->{rowcache}};
      }
}

sub _db_iterator{
      my $self = shift;

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
sub _mem_iterator{
      my $self = shift;

      my $class = $self->{record}->class;
      my $buddy = $self->{buddy} or confess "No buddy object present";

      my $rows  = ${$self->{rowcache}};
      my $ct = 0;

      # use a closure to reduce hash lookups
      # It's very important that this closure is fast.
      # This one routine has more of an effect on speed than anything else in the rest of the code
      $self->{next} = sub {
	    bless( (
		    [
		     ($rows->[$ct++] or $ct = 0 or return DUMMY ),
		     $buddy # buddy object comes along for the ride - to keep my recmaker in scope
		    ]
		   ),	$class );
      };

      return 1;

}


sub _makerecord{
      my $self = shift;

      $self->{record} = DBR::Record::Maker->new(
						session  => $self->{session},
						query    => $self->{query},
						rowcache => $self->{rowcache},
					       ) or confess ('failed to create record class');

      $self->{buddy} ||= $self->{record}->buddy(
						rowcache => $self->{rowcache}
					       ) or confess ('Failed to make buddy object');

      return 1;
}


# IMPORTANT NOTE: (circular reference hazard)
#
# We can't use $self->reset in the closure generated by _db_iterator
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
      $self->{next}  = FIRST;

      return 1;
}

sub DESTROY{
      my $self = shift;
      # DON'T Purge my rowcache!, cus other objects might still have a copy of it

      #print STDERR "ResultSet::DB DESTROY  ($self,\t$self->{state}, \t$self->{sth})\n";
      $self->{state} == CLEAN || $self->{sth}->finish();

      return 1;
}

###################################################
### Utility #######################################
###################################################

sub count{
      my $self = shift;
      return $self->{real_count} if defined $self->{real_count};
      return $self->{rows_hint}  if defined $self->{rows_hint}; # If it's defined, we can trust it

      if($self->{type} == t_SPLIT){ # run automatically if we are a split query
	    $self->_execute();      #HERE HERE HERE - I think this is wrong 
	    return $self->{real_count};
      }

      # HERE HERE HERE - transpose isn't taking splitness into account
      my $cquery = $self->{query}->transpose('Count') or croak "Failed to transpose query to a Count";

      return $self->{real_count} = $cquery->run;

      # Consider profiling min/max/avg rows returned for the scope in question
      # IF max / avg  is < 1000 just fetch all rows instead of executing another query

}

sub where {
       my $self = shift;

       return DBR::ResultSet->new(
				  session    => $self->{session},
				  query      => $self->{query}->child_query( \@_ ), # HERE - Do I need to cache all of these? or just split queries?
				  splitvalue => $self->{splitval},
				 );
}

sub delete {croak "Mass delete is not allowed. No cookie for you!"}

# Dunno if I like this
sub each (&){
      my $self    = shift;
      my $coderef = shift;
      my $r;
      $coderef->($r) while ($r = $self->next);

      return 1;

}

# get all instances of a field or fields from the resultset
# Kind of a flimsy way to do this, but it's lightweight
sub values {
      my $self = shift;
      my @fieldnames = grep { /^[A-Za-z0-9_]+$/ } map { split(/\s+/,$_) }  @_;

      scalar(@fieldnames) or croak('Must provide a list of field names');

      my $rows = $self->_fetch_all or return $self->_error('Failed to retrieve rows');

      return wantarray?():[] unless $self->count > 0;

      my @parts;
      foreach my $fieldname (@fieldnames){
	    push @parts , "\$_[0]->$fieldname";
      }

      my $code;
      if(scalar(@fieldnames) > 1){
	    $code = ' [  ' . join(', ', @parts) . ' ]';
      }else{
	    $code = $parts[0];
      }

      $code = 'sub{ push @output, ' . $code . ' }';

      $self->_logDebug3($code);

      my @output;
      my $sub = eval $code;
      confess "values failed ($@)" if $@;

      $self->each($sub) or confess "Failed to each";

      return wantarray?(@output):\@output;
}

sub hashmap_multi { shift->_lookuphash('multi', @_) }
sub hashmap_single{ shift->_lookuphash('single',@_) }

sub _lookuphash{
      my $self = shift;
      my $mode = shift;
      my @fieldnames = map { split(/\s+/,$_) } @_;

      scalar(@fieldnames) or croak('Must provide a list of field names');

      my $rows = $self->_fetch_all or return $self->_error('Failed to retrieve rows');

      return {} unless $self->count > 0;

      my $class = $self->{record}->class;
      my $buddy = $self->{buddy} or confess "No buddy object present";

      my $code;
      foreach my $fieldname (@fieldnames){
	    my @parts = split(/\.|\->/,$fieldname);
	    map {croak "Invalid fieldname part '$_'" unless /^[A-Za-z0-9_-]+$/} @parts;

	    $fieldname = join('->',@parts);

	    $code .= "{ \$_->$fieldname }";
      }
      my $part = ' map {  bless([$_,$buddy],$class)  } @{$rows}';

      if($mode eq 'multi'){
	    $code = 'map {  push @{ $lookup' . $code . ' }, $_ }' . $part;
      }else{
	    $code = 'map {  $lookup' . $code . ' = $_ }' . $part;
      }
      $self->_logDebug3($code);

      my %lookup;
      eval $code;
      croak "hashmap_$mode failed ($@)" if $@;

      return \%lookup;
}

1;
