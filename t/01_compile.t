#!/usr/bin/perl

# Test that everything compiles, so the rest of the test suite can
# load modules without having to check if it worked.

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 3;

ok( $] >= 5.00600, 'Perl version is new enough' );
use_ok('DBR');
#use_ok('t::lib::Test');

{
    my $c = DBR->new(0);
    is $c->get(), 0, "got initial value";
    is $c->inc(), undef, "inc returns undef";
    is $c->get(), 1, "inc incremented";
}

# my $logger = {};
# my $dbrconf = "/tmp/some/file.dbrconf";

# my $dbr = new DBR(
# 	-logger   => $logger,
# 	-conf     => $dbrconf,
# 	-admin    => 1,
# 	-fudge_tz => 1,
# ) or die 'failed to create dbr object';

# diag("\$DBR::VERSION=$DBR::VERSION");
