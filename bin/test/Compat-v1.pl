#!/usr/bin/perl

use lib '/dj/tools/apollo-utils/lib';
use lib '/dj/tools/perl-dbr/lib';
use Data::Dumper;
use ApolloUtils::Logger;
use DBR;
use DBR::Query::Compat::DBRv1;

my $logger = new ApolloUtils::Logger(-logpath => '/dj/logs/dbr_test.log', -logLevel => 'debug3');


my $dbr = new DBR(
		  -logger => $logger,
		  -conf   => '/dj/data/DBR.conf',
		 );

my $dbrh = $dbr->connect('esrp_main') || die "failed to connect";

my $compat = DBR::Query::Compat::DBRv1->new(logger => $logger, dbrh => $dbrh);

my $query = $compat->select(
  			    -table => {
				       tableA => 'orders',
				       tableB => 'items',
				       tableC => 'product',
				      },
  			    -fields => 'order_id total date_created',
			    -where => [
				       a => 'valueA',
				       tableA => {field1 => ['j','tableB.field1']},
				       [ {fieldC => 1}, {fieldC => 2} ],
				       c => ['>','37'],
				       'tableB.field2' => ['j','tableC.field2'],
				       'tableB.field3' => ['d',27,21,22]
				      ],
			   ) or die 'failed to select';

print Dumper({response => $query->sql});
