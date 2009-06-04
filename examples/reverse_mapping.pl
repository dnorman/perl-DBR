#!/usr/bin/perl

use strict;

use DBR;
use DBR::Util::Logger;   # Any object that implements log, logErr, logDebug, logDebug2 and logDebug3 will do
use DBR::Util::Operator; # Imports operator functions

my $logger = new DBR::Util::Logger(
				   -logpath => '/tmp/dbr_example.log',
				   -logLevel => 'debug3'
				  );

my $dbr = new DBR(
		  -logger => $logger,
		  -conf => 'support/example_dbr.conf'
		 );


my $dbrh = $dbr->connect('example') || die "failed to connect";

my $albums = $dbrh->album->where(name => LIKE '%T%') or die "failed to fetch albums";


my $record;
print "Albums:\n";
while (my $album = $albums->next){
      print "\t" . $album->name . "\n";

      my $artist = $album->artist or die "failed to retrieve artist";
      if($artist){
	    print "\t\t Artist: " . $artist->name
      }

      print "\n";
}
