#!/usr/bin/perl

use strict;
use lib qw'lib ../lib ../../lib';
####### Provision the sandbox DB, for examples/testing only ###########
use DBR::Sandbox( schema => 'music', writeconf => 'example_dbr.conf' ); 
#######################################################################

# Here is the real code:

use DBR ( conf => 'example_dbr.conf', logpath => 'dbr_example.log', loglevel => 'debug3', use_exceptions => 1 );

my $music   = dbr_connect('music'); # dbr_connect is imported into your scope when you 'use DBR (...)'
my $artists = $music->artist->all or die "failed to fetch artists";

print "Artists:\n\n";

while (my $artist = $artists->next) {

      print $artist->name . "\n";

}