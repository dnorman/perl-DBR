#!/usr/bin/perl

use strict;
use lib qw'../lib ../../lib';
use DBR ( conf => 'support/example_dbr.conf', logpath => 'dbr_example.log', loglevel => 'debug3' );



my $dbrh    = $dbr_connect('example') || die "failed to connect";

my $artists = $dbrh->artist->all or die "failed to fetch artists";
print "Artists:\n\n";
while (my $artist = $artists->next) {

      print $artist->name . "\n";

}
