#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';
use DBR::Util::Operator;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More;
use Test::Exception;

my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('music');
ok($dbh, 'dbr connect');

my $artist = $dbh->artist->get( 2 );
ok($artist, "got artist");

local $TODO = "does not work";
my $albumids;
lives_ok {
    $albumids = $artist->albums->where( 'artist.name' => LIKE 'Artist%' )->values('id');
} 'select does not die';

ok($albumids, "got ids");

my $albumct;
lives_ok {
    $albumct = $artist->albums->where( 'artist.name' => LIKE 'Artist%' )->count();
} 'count does not die';

ok($albumct, "got albumct");
ok($albumct == 2, "albumct correct");

done_testing();
