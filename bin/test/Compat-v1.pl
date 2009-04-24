#!/usr/bin/perl

use lib '/dj/tools/apollo-utils/lib';
use lib '/dj/tools/perl-dbr/lib';
use Data::Dumper;
use ApolloUtils::Logger;
use DBR::Query::Compat::DBRv1;

my $logger = new ApolloUtils::Logger(-logpath => '/dj/logs/dbr_test.log', -logLevel => 'debug3');

my $compat = DBR::Query::Compat::DBRv1->new(logger => $logger, dbh => 1);

my $query = $compat->_where([
			     a => 'valueA',
			     tableA => {field1 => ['j','tableB.field1']},
			     [ {fieldC => 1}, {fieldC => 2} ],
			     c => ['gt','valueC'],
			     'tableB.field2' => ['j','tableC.field2'],
			     'tableB.field3' => ['d',27]
                            ]
			   );

print Dumper($query);
