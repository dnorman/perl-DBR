#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 11;

# As always, it's important that the sample database is not tampered with, otherwise our tests will fail
my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('music');
ok($dbh, 'dbr connect');

my $count;
my $rv;
my $log;

$log = '';
$dbh->add_rollback_hook(sub { $log .= 'A' });
is($log, '', 'rollback hook outside txn is ignored');

$log = '';
$dbh->add_pre_commit_hook(sub { $log .= 'B' });
is($log, 'B', 'pre-commit hook outside txn is run immediately');

$log = '';
$dbh->add_pre_commit_hook(sub { $log .= 'C' });
is($log, 'C', 'post-commit hook outside txn is run immediately');

$log = '';
$dbh->begin;
$dbh->add_rollback_hook(sub { $log .= 'D' });
$dbh->commit;
is($log, '', 'rollback hook is ignored by commit');

$log = '';
$dbh->begin;
$dbh->add_rollback_hook(sub { $log .= 'E' });
$dbh->rollback;
is($log, 'E', 'rollback hooks are run by rollback');

$log = '';
$dbh->begin;
$dbh->add_rollback_hook(sub { $log .= 'F' });
$dbh->add_rollback_hook(sub { $log .= 'G' });
$dbh->rollback;
is($log, 'GF', '... in reverse order');

$log = '';
$dbh->begin;
$dbh->add_pre_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'H' : 'I' });
$dbh->add_post_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'J' : 'K' });
$dbh->add_pre_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'L' : 'M' });
$dbh->add_post_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'N' : 'O' });
is($log, '', 'commit hooks deferred in transaction');
$dbh->commit;
is($log, 'HLKO', 'run correctly on commit');

$log = '';
$dbh->begin;
$dbh->add_pre_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'H' : 'I' });
$dbh->add_post_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'J' : 'K' });
$dbh->add_pre_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'L' : 'M' });
$dbh->add_post_commit_hook(sub { $log .= $dbh->{conn}->b_intrans ? 'N' : 'O' });
$dbh->rollback;
is($log, '', 'ignored on rollback');

