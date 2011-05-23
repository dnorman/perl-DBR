#!/usr/bin/perl
use strict;
use lib qw'lib ../lib ../../lib';
####### Provision the sandbox DB, for examples/testing only ###########
use DBR::Sandbox( schema => 'music', writeconf => 'example_dbr.conf' ); 
#######################################################################

# Here is the real code:

use DBR ( conf => 'example_dbr.conf', logpath => 'dbr_example.log', loglevel => 'debug3', use_exceptions => 1 );


my $dbrh = dbr_connect('example') || die "failed to connect";


print "The choices for rating are:\n";
foreach my $rating ($dbrh->album->enum('rating')){
      print "\t $rating \t ( ${\ $rating->handle } )\n";
}

print "\n\n";
my $artists = $dbrh->artist->all or die "failed to fetch artists";


print "Artists:\n";
my $ct;
while (my $artist = $artists->next){

      print "\t" . $artist->name . "\t Royalty Rate: " . $artist->royalty_rate . "\n";
      my $albums = $artist->albums or die "failed to retrieve albums";


      while (my $album = $albums->next){

 	    print "\t\t Album:   '" . $album->name . "'\n";
 	    print "\t\t Rating:   " . $album->rating . " (" . $album->rating->handle .")\n"; # rating is an enum. Enums and other translators are "magic" objects
 	    print "\t\t Released: " . $album->date_released . "\n";

	    my $tracks = $album->tracks or die "failed to retrieve tracks";
 	    while (my $track = $tracks->next){

 		  print "\t\t\t Track: '" . $track->name . "'\n";
 	    }
 	    print "\t\t ( No tracks )\n" unless $tracks->count;
 	    print "\n";

      }

      if ($albums->count){
	    print "\t\t ( ${\ $albums->count } albums )\n";
      }else{
	    print "\t\t ( No albums )\n";
      }

      print "\n";
}
