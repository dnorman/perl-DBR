#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 28;

# As always, it's important that the sample database is not tampered with, otherwise our tests will fail
my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('test');
ok($dbh, 'dbr connect');

my $count;
my $rv;

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

$count = $allartists->count; # Count without any retrieval, so we force it to issue a sidecar query
ok(defined($count), 'v2 all artists resultset count defined');
ok($count == 2,     "v2 count matches ($count)");
$count = $allartists->count;
ok($count == 2,     "v2 count re-run matches ($count)");

my $allartistsB = $dbh->artist->all;
ok($allartistsB, 'v2 all artists resultset(B)');

my @artist_ids = $allartistsB->values('artist_id'); # Perform a retrieval, so we force it to do the full select
ok(@artist_ids == 2, 'v2 all artists values count matches');

$count = $allartists->count;
ok(defined($count), 'v2 all artists resultset count defined');
ok($count == 2,     "v2 count matches ($count)");




# v1 select / delete / select
my $tracks = $dbh->select( -table => 'track', -fields => 'track_id album_id name', -where => { album_id => ['d',2] } );
ok(ref($tracks) eq 'ARRAY', 'v1 select');
ok(@$tracks == 3,     "v1 correct number of rows");

$rv = $dbh->delete( -table => 'track', -where => { album_id => ['d',2], name => 'Track BA3' } );
ok(defined($rv), 'v1 delete defined');
ok($rv, 'v1 delete');

$tracks = $dbh->select( -table => 'track', -fields => 'track_id album_id name', -where => { album_id => ['d',2] } );
ok(ref($tracks) eq 'ARRAY', 'v1 select');
ok(@$tracks == 2,     "v1 correct number of rows");


# v2 select/delete/select
my $tracksB = $dbh->track->where( album_id => 2 );
ok($tracksB, 'v2 select');
ok($tracksB->count == 2, "v2 correct number of rows");

# v2 select/delete/select
$rv = $dbh->track->where( album_id => 2, name => 'Track BA2' )->next->delete;
ok(defined($rv), 'v2 delete defined');
ok($rv, 'v2 delete');

$tracksB = $dbh->track->where( album_id => 2 );
ok($tracksB, 'v2 select');
ok($tracksB->count == 1, "v2 correct number of rows");
