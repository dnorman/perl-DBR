#!/usr/bin/perl

use strict;

use lib qw'../lib ../../lib';
use DBR;
use DBR::Util::Logger;   # Any object that implements log, logErr, logDebug, logDebug2 and logDebug3 will do
use DBR::Util::Operator; # Imports operator functions

my $logger = new DBR::Util::Logger(
				   -logpath => '/tmp/dbr_example.log',
				   -logLevel => 'debug3'
				  );

my $dbr = new DBR(
		  -logger => $logger,
		  -conf   => 'support/example_dbr.conf'
		 );

my $dbrh = $dbr->connect('example') || die "failed to connect";




my $artists = $dbrh->artist->where(name => []) or die "failed to fetch artists";


print "Artists:\n\n";
while (my $artist = $artists->next) {

      print $artist->name . "\n";

}
