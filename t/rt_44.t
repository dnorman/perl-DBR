#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 23;

my $dbr = setup_schema_ok('rt_44');

my $dbh = $dbr->connect('test');
ok($dbh, 'dbr connect');

my $items = eval{ $dbh->cart->all };
ok( defined($items), 'items = dbh->cart->all ... ' . $@ );

my $total = 0;

while (my $item = $items->next()) {

  ok( defined( $item), 'item = items->next' );

  my $name = eval{ $item->name };
  ok( defined($name), 'name = item->name (' . $name . ') ... ' . $@ );

  my $price = eval{ $item->price };
  ok( defined($price), 'price = item->price (' . $price . ') ... ' . $@ );

  eval{ $total += $price };
  ok( $total, 'total += price  (' . $total . ') ... ' . $@ );

  my $foo;  # an undefined value
  eval{ $foo += $price };
  ok( defined($foo), 'foo += price (' . $foo . ') ... ' . $@ );
}
