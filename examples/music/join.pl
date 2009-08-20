#!/usr/bin/perl

use strict;

use lib qw'../lib ../../lib';
use DBR;
use DBR::Util::Logger;   # Any object that implements log, logErr, logDebug, logDebug2 and logDebug3 will do
use DBR::Util::Operator; # Imports operator functions

my $filepath = "";

if (scalar(@ARGV) gt 1) {
   $filepath = $1 . '/';
}

my $logger = new DBR::Util::Logger(
				   -logpath => '/tmp/dbr_example.log',
				   -logLevel => 'debug3'
				  );

my $dbr = new DBR(
		  -logger => $logger,
		  -conf => $filepath . 'support/example_dbr.conf'
		 );



my $dbrh = $dbr->connect('example') || die "failed to connect";




print "\n========================================\n\n";

print "Do a join\n";
print "Albums where artist name like Test, with a fair or poor rating:\n\n";

my $albums = $dbrh->album->where(
				 'artist.name' => LIKE '%Test%',
				 rating => 'fair poor',
				) or die "failed to fetch albums";

while (my $album = $albums->next) {

      print $album->name . "\n";

}


print "\n========================================\n\n";


print "Do a subquery\n";
print "Artists where track name like Test, with an album rating of  fair or poor:\n\n";
my $artists = $dbrh->artist->where(
				   'albums.tracks.name' => LIKE '%Test%','albums.rating' => 'fair poor'
				  ) or die "failed to fetch artists";

while (my $artist = $artists->next) {

      print $artist->name . "\n";


}

print "\n========================================\n\n";


print "Do a join AND a subquery\n";
print "Albums where artist name like Test, with a fair or poor rating, and track name like Test:\n\n";

my $album = $dbrh->album->where(
				'artist.royalty_rate' => GT 2.01,
				rating       => 'fair poor',
				'tracks.name' => LIKE '%Test%',
				'tracks.album.artist.name' => LIKE '%Test Artist%' # yes, I'm querying crazy crazy things
			       ) or die "failed to fetch albums";

while (my $album = $album->next) {

      print $album->name . "\n";

}
