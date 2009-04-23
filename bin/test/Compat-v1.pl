#!/usr/bin/perl

use lib '/dj/tools/perl-dbr/lib';
use Data::Dumper;
use DBR::Query::Compat::DBRv1;

my $logger = new ApolloUtils::Logger(-logpath => '/dj/logs/dbr_test.log', -logLevel => 'debug3');

my $compat = DBR::Query::Compat::DBRv1->new(logger => $logger, dbh => 1);

my $query = $compat->_where(
a => 'b',
tableA => {field1 => ['j','tableB.field1']},
[{fieldC => 1},{fieldC => 2}]
);

print Dumper($query);
