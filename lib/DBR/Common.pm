package DBR::Common;

use strict;
use Time::HiRes;
my %TIMERS;

sub _uniq{
    my $self = shift;

    my %uniq;
    return grep{!$uniq{$_}++} @_;

}

sub _split{
      my $self = shift;
      my $value = shift;

      my $out;
      if(ref($value)){
	    $out = $value;
      }else{
	    $value =~ s/^\s*|\s*$//g;
	    $out = [ split(/\s+/,$value) ];
      }

      return $out;
}

# returns true if all elements of Arrayref A (or single value) are present in arrayref B
sub _b_in{
      my $self = shift;
      my $value1 = shift;
      my $value2 = shift;
      $value1 = [$value1] unless ref($value1);
      $value2 = [$value2] unless ref($value2);
      return undef unless (ref($value1) eq 'ARRAY' && ref($value2) eq 'ARRAY');
      my %valsA = map {$_ => 1} @{$value2};
      my $results;
      foreach my $val (@{$value1}) {
            unless ($valsA{$val}) {
                  return 0;
            }
      }
      return 1;
}

sub _stopwatch{
      my $self = shift;
      my $label = shift;

      my ( $package, $filename, $line, $method ) = caller( 1 ); # First caller up
      my ($m) = $method =~ /([^\:]+)$/;

      if($label){
	    my $elapsed = Time::HiRes::time() - $TIMERS{$method};
	    my $seconds = sprintf('%.8f',$elapsed);
	    $self->_logDebug( "$m ($label) took $seconds seconds");
      }

      $TIMERS{ $method } = Time::HiRes::time(); # Logger could be slow

      return 1;
}
sub _error {
      my $self = shift;
      my $message = shift;

      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->logErr($message,$method);
      }else{
	    print STDERR "DBR ERROR: $message ($method, line $line)\n";
      }
      return undef;
}

sub _logDebug{
      my $self = shift;
      my $message = shift;
      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->logDebug($message,$method);
      }elsif($self->is_debug){
	    print STDERR "DBR DEBUG: $message\n";
      }
}
sub _logDebug2{
      my $self = shift;
      my $message = shift;
      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->logDebug2($message,$method);
      }elsif($self->is_debug){
	    print STDERR "DBR DEBUG2: $message\n";
      }
}
sub _logDebug3{
      my $self = shift;
      my $message = shift;
      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->logDebug3($message,$method);
      }elsif($self->is_debug){
	    print STDERR "DBR DEBUG3: $message\n";
      }
}

#HERE HERE HERE - do some fancy stuff with dummy subroutines in the symbol table if nobody is in debug mode

sub _log{
      my $self = shift;
      my $message = shift;
      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->log($message,$method);
      }else{
	    print STDERR "DBR: $message\n";
      }
      return 1;
}

sub logger   { $_[0]->{logger} }
sub is_debug { $_[0]->{debug}  }

1;
