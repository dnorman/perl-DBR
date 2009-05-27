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


print "\n\n";
print "The choices for rating are:\n";
foreach my $rating ($dbrh->album->enum('rating')){
      print "\t $rating \t ( ${\ $rating->handle } )\n";
}

print "\n\n";
my $artists = $dbrh->artist->all or die "failed to fetch artists";


print "Artists:\n";
my $ct;
while (my $artist = $artists->next){
      print "\t" . $artist->name . "\n";

      my $albums = $artist->albums or die "failed to retrieve albums";

      while (my $album = $albums->next){

	    print "\t\t Album: '" . $album->name . "'\n";
	    print "\t\t Rating: " . $album->rating . " (" . $album->rating->handle .")\n"; # rating is an enum. Enums and other translators are "magic" objects

      }

      if ($albums->count){
	    print "\t\t ( ${\ $albums->count } albums )\n";
      }else{
	    print "\t\t ( No albums )\n";
      }

      print "\n";
}
