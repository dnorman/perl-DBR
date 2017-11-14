package DBR;

use strict;
use DBR::Handle;
use DBR::Config;
use DBR::Config::Instance;
use DBR::Misc::Session;
use Scalar::Util 'blessed';
use base 'DBR::Common';
use DBR::Util::Logger;
use Carp;

our $VERSION = '-DBR-VERSION-TAG-';

my %APP_BY_CONF;
my %CONF_BY_APP;
my %OBJECTS;
my $CT;

sub import {
      my $pkg = shift;
      my %params = @_;

      my ($callpack, $callfile, $callline) = caller;

      my $app  = $params{app};
      my $exc  = exists $params{use_exceptions} ? $params{use_exceptions} || 0 : 1;
      my $conf;

      if( $params{conf} ){
	    croak "conf file '$params{conf}' not found" unless -e $params{conf};

	    $conf = $params{conf};
	    $app ||= $APP_BY_CONF{ $conf } ||= 'auto_' . $CT++; # use existing app id if conf exists, or make one up
	    $CONF_BY_APP{ $app } = $conf;
      }elsif ( defined $app && length $app ){
	    $conf = $CONF_BY_APP{ $app };
      }

      return 1 unless $app; # No import requested

      if($conf){
	    $OBJECTS{ $app }{ $exc } ||= DBR->new(
						  -logger => DBR::Util::Logger->new(
										    -logpath  => $params{logpath} || '/tmp/dbr_auto.log',
										    -logLevel => $params{loglevel} || 'warn'
										   ),
						  -conf           => $conf,
						  -use_exceptions => $exc,
						 );
      }

      my $dbr = $OBJECTS{ $app }{ $exc } or croak "No DBR object could be located";

      no strict 'refs';
      *{"${callpack}::dbr_connect"} =
	sub {
	      shift if exists ($_[0]) && (blessed($_[0]) || $_[0]->isa( [caller]->[0] ));
	      $dbr->connect(@_);
	};
        
      *{"${callpack}::dbr_instance"} =
	sub {
	      shift if exists ($_[0]) && (blessed($_[0]) || $_[0]->isa( [caller]->[0] ));
	      $dbr->get_instance(@_);
	};
        
      *{"${callpack}::dbr_schema"} =
	sub {
	      shift if exists ($_[0]) && (blessed($_[0]) || $_[0]->isa( [caller]->[0] ));
	      $dbr->get_schema(@_);
	};
        
      *{"${callpack}::dbr_session"} =
	sub {
	      shift if exists ($_[0]) && (blessed($_[0]) || $_[0]->isa( [caller]->[0] ));
	      $dbr->session;
	};
        

}
package DBR;

use strict;
use warnings;

require XSLoader;
XSLoader::load();
