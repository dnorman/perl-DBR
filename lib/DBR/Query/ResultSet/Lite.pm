package DBR::Query::ResultSet::Lite;

use strict;
use base 'DBR::Query::ResultSet::Common';
use Carp;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger   => $params{logger},
		  rows     => $params{rows} || [],
		  query    => $params{query},
		  record   => $params{record},
		 };

      bless( $self, $package );

      if($self->{record}){
	   $self->{recordclass} = $self->{record}->class or return $self->_error('failed to get class');
      }else{
	   return $self->_error('record object is required unless rowcount is 0') if $self->count > 0;
      }

      return $self->_error('logger object must be specified')   unless $self->{logger};
      return $self->_error('query object must be specified')    unless $self->{query};
      $self->_iterator_prep;

      return( $self );

}

sub count     {  scalar @{$_[0]->{rows}} }

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



sub split{ croak "no splits allowed" }

sub next { $_[0]{next}->() }


sub _allrows { $_[0]->{rows} }
sub _iterator_prep{
      my $self = shift;

      my $rows = $self->{rows};
      if ( $self->{recordclass} ) {
	    my $class = $self->{recordclass};
	    my $ct;

	    # use a closure to reduce hash lookups
	    # It's very important that this closure is fast.
	    # This one routine has more of an effect on speed than anything else in the rest of the code
	    $self->{next} = sub {
		  bless( ( $rows->[$ct++ || 0] or return $ct = undef ),	$class );
	    };
      } else {
	    $self->{next} = sub { undef };
      }

      return 1;

}

1;
