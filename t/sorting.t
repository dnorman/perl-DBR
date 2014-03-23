#!/usr/bin/perl

use strict;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 8;
use DBR::Config::Scope;

my $dbr = setup_schema_ok( 'sorttest' );

my $dbrh = $dbr->connect( 'sorttest' );
ok($dbrh, 'dbr connect');

my $abc = $dbrh->abc;

is($abc->all->order_by('id')->next->id, 1, 'order by id works');
is($abc->all->order_by('a')->next->id, 3, 'order by a works');
is($abc->all->order_by('b')->order_by('id')->next->id, 1, 'order by b, id works');
is($abc->all->order_by('b')->order_by('a')->next->id, 2, 'order by b, a works');
is($abc->all->order_by('-id')->next->id, 3, 'order by id DESC works');
is($abc->all->order_by('-a')->next->id, 1, 'order by a DESC works');

1;

