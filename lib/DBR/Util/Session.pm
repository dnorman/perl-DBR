package DBR::Util::Session;

use strict;
use base 'DBR::Common';
use Carp;


sub new {
      my( $package ) = shift;

      my %params = @_;
      my $self = {
		  logger  => $params{logger},
		 };

      bless( $self, $package );

      croak ('logger is required') unless $self->{logger};

      $self->timezone('server') or confess "failed to initialize timezone";

      return $self;
}


sub timezone {
      my $self = shift;
      my $tz   = shift;

      return $self->{tz} unless defined($tz);

      if($tz eq 'server' ){
	    my $tzobj = DateTime::TimeZone->new( name => 'local');
	    $tz = $tzobj->name;
      }

      DateTime::TimeZone->is_valid_name( $tz ) or return $self->_error( "Invalid Timezone '$tz'" );

      $self->_logDebug2('Set timezone to ' . $tz);

      return $self->{tz} = $tz;
}

sub _session { $_[0] }

sub _log{
      my $self    = shift;
      my $message = shift;
      my $mode    = shift;

      my ( undef,undef,undef, $method) = caller(2);
      $self->{logger}->log($message,$method,$mode);

      return 1;
}

1;
