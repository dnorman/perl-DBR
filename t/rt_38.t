#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$|++;

use lib './lib';
use t::lib::Test;
use Test::More tests => 15;

my $dbr = setup_schema_ok('rt_38');

my $dbh = $dbr->connect('test');
ok($dbh, 'dbr connect');

my $names = $dbh->firstnames->all();
ok(defined($names), 'select all first names');

# this will loop four times
while (my $name = $names->next()) {

	ok(defined($name), 'name = $names->next');

	my $first = eval{ $name->firstname };
	ok(defined($first), 'first = name->firstname (' . $first . ')');

	my $lastname = eval{ $name->last_name->lastname };
	ok(defined($lastname), 'lastname = name->last_name->last_name (' . $lastname . ')');

}
