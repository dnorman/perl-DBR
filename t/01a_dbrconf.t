#!/usr/bin/perl

# Test that everything compiles, so the rest of the test suite can
# load modules without having to check if it worked.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 2;

ok( $] >= 5.00600, 'Perl version is new enough' );
use_ok('DBR');
#use_ok('t::lib::Test');

my $logger = {};
my $dbrconf = "/tmp/some/file.dbrconf";

my $dbr = new DBR(
	-logger   => $logger,
	-conf     => "t/resource/dbr_conf_mysql_fake.conf",
	-admin    => 1,
	-fudge_tz => 0,
	use_exceptions => 1
) or die 'failed to create dbr object';

$dbr->flush_handles;
# diag("\$DBR::VERSION=$DBR::VERSION");
