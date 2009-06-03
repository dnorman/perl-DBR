package DBR::Query::ResultSet;

use strict;
use base 'DBR::Common';

use DBR::Query::ResultSet::DB;
use DBR::Query::ResultSet::Mem;

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
							     logger  => $self->{logger},
							     rows    => $groupby{$key},
							     record  => $self->{record}, #keep RecMaker object in scope);
							    ) or return $self->_error('failed to create resultset lite object');
      }

      return \%groupby;
}

#HERE HERE HERE this is broken for fields that aren't in the resultset
# Consider adding a method to Query.pm to provide an overlayed list of fields selected, AND possible
sub lookup_hash {
      my $self = shift;
      my @fieldnames = map { split(/\s+/,$_) } @_;

      scalar(@fieldnames) or croak('Must provide a list of field names');

      my $rows = $self->_fetch_all or return $self->_error('Failed to retrieve rows');
      print "FOO 1\n";
      return {} unless $self->count > 0;
      print "FOO 2\n";

      my $qfields = $self->{query}->fields or return $self->_error('failed to retrieve query fields');


      my %fieldmap;
      map {$fieldmap{$_->name} = $_} @{$qfields};

      my $class = $self->{record}->class;

      my $code;
      foreach my $fieldname (@fieldnames){
	    my $field = $fieldmap{$fieldname} or return $self->_error('invalid field ' . $fieldname);
	    my $idx = $field->index;
	    return $self->_error('fields must have indexes') unless defined $idx;

	    $code .= "{ \$_->$fieldname }";
      }
      $code = 'map {  $lookup' . $code . ' = bless($_,$class)  } @{$rows}';

      $self->_logDebug3($code);
      my %lookup;
      eval $code;

      return \%lookup;
}


# sub map {
#       my $self = shift;
#       my @fieldnames = map { split(/\s+/,$_) } @_;

#       scalar(@fieldnames) or croak('Must provide a list of field names');

#       return {} unless $self->count > 0;

#       my $rows = $self->_fetch_all or return $self->_error('Failed to retrieve rows');

#       my $qfields = $self->{query}->fields or return $self->_error('failed to retrieve query fields');


#       my %fieldmap;
#       map {$fieldmap{$_->name} = $_} @{$qfields};

#       my $class = $self->{record}->class;

#       my $code;
#       foreach my $fieldname (@fieldnames){
# 	    my $field = $fieldmap{$fieldname} or return $self->_error('invalid field ' . $fieldname);
# 	    my $idx = $field->index;
# 	    return $self->_error('fields must have indexes') unless defined $idx;

# 	    $code .= "{ \$_->[$idx] }";
#       }
#       $code = 'map {  push @{$root' . $code . '}, bless($_,$class)  } @{$rows}';

#       $self->_logDebug3($code);
#       my %root;
#       eval $code;

#       return \%root;
# }


sub _mem_iterator{
      my $self = shift;

      my $class = $self->{record}->class;
      my $rows  = ${$self->{rowcache}};
      my $ct;

      # use a closure to reduce hash lookups
      # It's very important that this closure is fast.
      # This one routine has more of an effect on speed than anything else in the rest of the code
      $self->{next} = sub {
	    bless( ( $rows->[$ct++ || 0] or return $ct = undef ),	$class );
      };

      return 1;

}


1;
