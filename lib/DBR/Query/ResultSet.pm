package DBR::Query::ResultSet;

use strict;
use base 'DBR::Common';

use DBR::Query::ResultSet::DB;
use DBR::Query::ResultSet::Mem;
use DBR::Query::Dummy;

use Carp;

sub delete {croak "Mass delete is not allowed. No cookie for you!"}

# Dunno if I like this
sub each (&){
      my $self    = shift;
      my $coderef = shift;
      my $r;
      $coderef->($r) while ($r = $self->next);

      return 1;

}

sub split{
      my $self = shift;
      my $field = shift;

      my $idx = $field->index;
      return $self->_error('field object must provide an index') unless defined($idx);

      my $rows = $self->_fetch_all or return $self->_error('_fetch_all failed');

      my $code = 'map { push @{$groupby{ $_->[' . $idx . '] }}, $_ } @{ $rows }';
      $self->_logDebug3($code);

      my %groupby;
      eval $code;

      foreach my $key (keys %groupby){
	    $groupby{$key} = DBR::Query::ResultSet::Mem->new(
							     session  => $self->{session},
							     rows    => $groupby{$key},
							     record  => $self->{record},
							     buddy   => $self->{buddy}, # use the same record buddy object
							     query   => $self->{query},
							    ) or return $self->_error('failed to create resultset lite object');
      }

      return \%groupby;
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

sub dummy_record{ bless([],'DBR::Query::Dummy') }

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


sub _mem_iterator{
      my $self = shift;

      my $class = $self->{record}->class;
      my $buddy = $self->{buddy} or confess "No buddy object present";

      my $rows  = ${$self->{rowcache}};
      my $ct = 0;
      my $dummy = $self->dummy_record;

      # use a closure to reduce hash lookups
      # It's very important that this closure is fast.
      # This one routine has more of an effect on speed than anything else in the rest of the code
      $self->{next} = sub {
	    bless( (
		    [
		     ($rows->[$ct++] or $ct = 0 or return $dummy ),
		     $buddy # buddy object comes along for the ride - to keep my recmaker in scope
		    ]
		   ),	$class );
      };

      return 1;

}


sub _makerecord{
      my $self = shift;

      $self->{record} ||= $self->{query}->makerecord(
						     rowcache => $self->{rowcache} # Consider passing rowcache only to the record buddy object
						    ) or return $self->_error('failed to setup record');

      $self->{buddy} ||= $self->{record}->buddy(
						rowcache => $self->{rowcache}
					       ) or return $self->_error('Failed to make buddy object');

      return 1;
}

1;
