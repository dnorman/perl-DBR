#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 3;

my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('music');
ok($dbh, 'dbr connect');

my $track = $dbh->track->get(4);
$track->name;
$track->set( name => 'foo' );
is $track->name, 'foo', 'set communicates with accessors even on an empty cache';
