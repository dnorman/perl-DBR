#!/usr/bin/perl

use strict;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 14;
use DBR::Config::Scope;

my $dbr = setup_schema_ok( 'rt_53' );

my $dbrh = $dbr->connect( 'test' );
ok($dbrh, 'dbr connect');

# 2 tests so far, plus tests below

for my $pass (1..2) {      # 2x tests
  ok( 1, "pass $pass:" );

  my $all = $dbrh->test_abc->all;
  ok( $all, "  got all records" );

  my ($val,$next);

  $next = $all->next;
  $val = 0 + $next->xyz->someval;
  ok( $val == 0,   "  expect zero value from NULL fkey - got $val" );
  $val = 0 + ($next->xyz_id ? $next->xyz->someval : 0);
  ok( $val == 0,   "  expect zero value from NULL fkey - got $val" );

  $next = $all->next;
  $val = 0 + $next->xyz->someval;
  ok( 222 == $val, "  got $val value" );
  $val = 0 + ($next->xyz_id ? $next->xyz->someval : 0);
  ok( 222 == $val, "  got $val value" );
}

1;

