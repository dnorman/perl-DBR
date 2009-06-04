#!/usr/bin/perl

use lib '/dj/tools/perl-dbr/lib';
use DBR::Util::Logger;
use DBR;
use strict;
use Data::Dumper;

chdir '../';

my $logger = new DBR::Util::Logger(-logpath => '/tmp/dbr_test.log', -logLevel => 'debug3');
my $dbr    = new DBR(
		     -logger => $logger,
		     -conf   => '/dj/data/DBR.conf',
		    );






my $dbrh = $dbr->connect('esrp_main') || die "failed to connect";

my $ret = $dbrh->select(
  '-table' => 'offices',
          '-keycol' => 'office_id',
          '-fields' => 'office_id tz_id'



		       );
print Dumper($ret);

# my $ret = $dbrh->select(
# 			'-table' => 'resource_locks',
# 			'-where' => {
# 				     'cust_id' => [
# 						   'd',
# 						   '902394'
# 						  ],
# 				     'value' => [
# 						 'd',
# 						 '22461'
# 						],
# 				     'name' => 'invoice',
# 				     'expires' => [
# 						   'd >=',
# 						   1243474231
# 						  ]
# 				    },
# 			'-fields' => 'row_id expires',
# 			'-single' => 1
# 		       );


# 			'-table' => 'receive_unit',
# 			'-where' => {
# 				     'receive_unit_id' => {
# 							   '-table' => 'receive_lot',
# 							   '-where' => {
# 									'receive_lot_id' => [
# 											     'd in',
# 											     '659583'
# 											    ]
# 								       },
# 							   '-field' => 'receive_unit_id'
# 							  }
# 				    },
# 			'-fields' => [
# 				      'product_id'
# 				     ]
