#!/usr/bin/perl

use strict;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 6;
use DBR::Config::Scope;
use DBR::Util::Operator;

my $dbr = setup_schema_ok( 'rt_54' );

my $dbrh = $dbr->connect( 'test' );
ok($dbrh, 'dbr connect');

# 2 tests so far, plus tests below

my $recs;

$recs = $dbrh->abc->where( status => 'one' );
ok( $recs, 'get recs' );

$recs = $dbrh->abc->where( status => NOT 'one' );
ok( $recs, 'get recs' );

$recs = $dbrh->abc->where( status => 'one two' );
ok( $recs, 'get recs' );

$recs = $dbrh->abc->where( status => NOT 'one two' );
ok( $recs, 'get recs' );

1;

