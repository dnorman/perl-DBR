#!/usr/bin/perl

use strict;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 5;
use DBR::Config::Scope;

my $dbr = setup_schema_ok( 'rt_gh2' );

my $dbrh = $dbr->connect( 'rt_gh2' );
ok($dbrh, 'dbr connect');

sub dumpit {
    my $rec = shift;

    join ' ', $rec->values->values('data');
}

sub appendit {
    my $rec = shift;
    my $val = shift;

    $dbrh->field_values->insert( field_id => $rec->id, data => $val );
}

diag('check that write/read interleaving works');
{
    my @out;
    my @ids = (1, 2);
    my @vals = qw( A B );

    my $map = $dbrh->fields->where( id => \@ids )->hashmap_single('id');

    while (@ids) {
        my $rec = $map->{ shift(@ids) };

        appendit($rec, shift(@vals));
        push @out, dumpit($rec);
    }

    is($out[0], 'A', 'first value of a sequence read after writing OK');
    is($out[1], 'B', 'subsequent value of a sequence read after writing OK');
}

diag('check read/write/read');
{
    my $rec = $dbrh->fields->get(3);

    dumpit($rec);
    appendit($rec, 'C');
    is(dumpit($rec), 'C', 'read / write / read sequence with a many-one relation returns correct data');
}

1;

