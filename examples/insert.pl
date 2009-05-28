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




my $artists = $dbrh->artist->where(name => 'Test Artist') or die "failed to fetch artists";


print "Artists:\n\n";
while (my $artist = $artists->next){

      print $artist->name . "\n";

      $dbrh->album->insert(
			   artist_id => $artist->artist_id,
			   name      => 'Test Album ' . int(rand(100000)),
			   rating    => 'fair'
			  ) or die "failed to insert"
}
