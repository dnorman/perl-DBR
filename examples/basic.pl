#!/usr/bin/perl

use strict;

use lib '/dj/tools/perl-dbr/lib';
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

my $artists = $dbrh->artist->all or die "failed to fetch artists";

while (my $artist = $artists->next){
      print "The name of the artist is " . $artist->name . "\n";

     #while (my $album = $artist->albums){ # This will work soon

      # For now we have to do it like this :-(
      my $albums = $dbrh->album->where(artist_id => $artist->artist_id) or die "Failed to retrieve albums";
      while(my $album = $albums->next){

	    print "\tThe name of the album is " . $album->name . "\n";
      }

}
