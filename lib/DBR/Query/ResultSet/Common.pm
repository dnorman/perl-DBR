package DBR::Query::ResultSet::Common;

use strict;
use base 'DBR::Common';
use Carp;

sub delete {croak "Mass delete is not allowed. No cookie for you!"}

sub arrayrefs{ $_[0]->_allrows }

#HERE HERE HERE this is broken for fields that aren't in the resultset
# Consider adding a method to Query.pm to provide an overlayed list of fields selected, AND possible

sub map {
      my $self = shift;
      my @fieldnames = map { split(/\s+/,$_) } @_;

      scalar(@fieldnames) or croak('Must provide a list of field names');

      return {} unless $self->count > 0;

      my $rows = $self->_allrows or return $self->_error('Failed to retrieve rows');

      my $qfields = $self->{query}->fields or return $self->_error('failed to retrieve query fields');


      my %fieldmap;
      map {$fieldmap{$_->name} = $_} @{$qfields};

      my $class = $self->{record}->class;

      my $code;
      foreach my $fieldname (@fieldnames){
	    my $field = $fieldmap{$fieldname} or return $self->_error('invalid field ' . $fieldname);
	    my $idx = $field->index;
	    return $self->_error('fields must have indexes') unless defined $idx;

	    $code .= "{ \$_->[$idx] }";
      }
      $code = 'map {  push @{$root' . $code . '}, bless($_,$class)  } @{$rows}';

      $self->_logDebug3($code);
      my %root;
      eval $code;

      return \%root;
}


1;
