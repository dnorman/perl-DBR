#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 16;

# As always, it's important that the sample database is not tampered with, otherwise our tests will fail
my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('test');
ok($dbh, 'dbr connect');
my $rv;

my $count;
# v1 select count
$count = $dbh->select( -count => 1, -table => 'artist' );
ok(defined($count), 'v1 -count defined');
ok($count == 2,     "v1 -count matches ($count)");

$count = $dbh->select( -count => 1, -table => 'track', -where => { album_id => ['d',1] } );
ok(defined($count), 'v1 -count defined');
ok($count == 3,     "v1 -count matches ($count)");

$count = $dbh->select( -count => 1, -table => 'track', -where => { album_id => ['d',999] } ); # Intentional - There is no album 999
ok(defined($count), 'v1 -count defined');
ok($count == 0,     "v1 -count matches ($count)");


# v2 select count

my $allartists = $dbh->artist->all;
ok($allartists, 'v2 all artists resultset');

$count = $allartists->count;
ok(defined($count), 'v2 all artists resultset count defined');
ok($count == 2,     "v2 count matches ($count)");
$count = $allartists->count;
ok($count == 2,     "v2 count re-run matches ($count)");

my $allartistsB = $dbh->artist->all;
ok($allartistsB, 'v2 all artists resultset(B)');

my @artist_ids = $allartistsB->values('artist_id');
ok(@artist_ids == 2, 'v2 all artists values count matches');

$count = $allartists->count;
ok(defined($count), 'v2 all artists resultset count defined');
ok($count == 2,     "v2 count matches ($count)");
