#!/usr/bin/perl

use strict;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 5;
use DBR::Config::Scope;

my $dbr = setup_schema_ok( 'foobar' );

my $dbrh = $dbr->connect( 'foobar' );
ok($dbrh, 'dbr connect');


########################################################
diag('check that insert/read interleaving works');

my $recs = $dbrh->foo->get([1, 2]);

my $fooA = $recs->next;
$dbrh->bar->insert( foo_id => $fooA->id, data => 'A' );

#                \/ all bars for foosA-B are cached after this point, the subsequent insert is effective, but excluded from the resultsets
is($fooA->bars->next->data, 'A', 'first value of a sequence read after inserting OK');

my $fooB = $recs->next;
$dbrh->bar->insert( foo_id => $fooB->id, data => 'B' );
is($fooB->bars->next->data, 'B', 'subsequent value of a sequence read after inserting OK');




########################################################
diag('check read/insert/read');

my $fooC = $dbrh->foo->get( 3 );
$fooC->bars->values('data');

$dbrh->bar->insert( foo_id => $fooC->id, data => 'C' );
is($fooC->bars->next->data, 'C', 'read/insert/read sequence with a many-one relation returns correct data');



1;

