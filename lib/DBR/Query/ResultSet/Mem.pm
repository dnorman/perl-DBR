package DBR::Query::ResultSet::Mem;

use strict;
use base 'DBR::Query::ResultSet';
use Carp;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger   => $params{logger},
		  record   => $params{record},
		 };

      bless( $self, $package );

      $self->_error('record object is required') unless $self->{record};

      my $rows = $params{rows};
      $self->{rowcache} = \$rows;

      return $self->_error('logger object must be specified')   unless $self->{logger};
      $self->_mem_iterator;

      return( $self );

}

sub split { croak "Cannot split an already ResultSet::Mem object" }

sub next   { $_[0]->{next}->() }
sub count  {  scalar @{    ${ $_[0]->{rowcache} }    } }

sub hashrefs{
      my $self = shift;

      return [] unless $self->count > 0;

      my $rows = $self->_allrows;
      my $code;
      foreach my $field (@{$self->{fields}}){
	    my $idx = $field->index;
	    return $self->_error('fields must have indexes') unless defined $idx;
	    $code .= $field->name . ' => $_->[' . $idx . '],' . "\n";
      }
      $code = '[ map {  {' . $code . '}  } @{$rows} ]';

      #$self->_logDebug3($code);

      return eval $code;
}

sub _fetch_all {   ${ $_[0]->{rowcache} }   }

1;
