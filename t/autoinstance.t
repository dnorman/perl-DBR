#!/usr/bin/perl

use strict;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 6;
use DBR::Config::Scope;

my $dbr = setup_schema_ok( 'sorttest' );

my $dbrh = $dbr->connect( 'newsch' );
ok(!$dbrh, 'dbr connect does not exist, fails');

my $dbinfo = $dbr->connect('dbrconf')->select( -table => 'dbr_instances', -fields => 'instance_id schema_id class dbname username password host dbfile module handle readonly tag' )->[0];

ok($dbinfo, 'fetch DB config info');

my $r = $dbr->connect('dbrconf')->insert( -table => 'dbr_instances', -fields => { schema_id => ['d',$dbinfo->{schema_id}], map(($_, $dbinfo->{$_}), qw'class dbfile module'), handle => 'newsch' } );
ok($r, 'save DB config info');

$dbrh = $dbr->connect( 'newsch' );
ok($dbrh, 'dbr connect now exists, succeeds');

is ($dbrh->abc->all->count, 3, 'can use new connection');

1;

