#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';
use DBR::Util::Operator;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More;

my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('music');
ok($dbh, 'dbr connect');

my $artist = $dbh->artist->get( 2 );
ok($artist, "got artist");

my $albumids = $artist->albums->where( 'artist.name' => LIKE 'Artist%' )->values('id');

ok($albumids, "got ids");

my $albumct = $artist->albums->where( 'artist.name' => LIKE 'Artist%' )->count();

ok($albumct, "got albumct");
ok($albumct == 2, "albumct correct");

done_testing();