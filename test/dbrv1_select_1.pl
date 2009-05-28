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
			'-table' => 'resource_locks',
			'-where' => {
				     'cust_id' => [
						   'd',
						   '902394'
						  ],
				     'value' => [
						 'd',
						 '22461'
						],
				     'name' => 'invoice',
				     'expires' => [
						   'd >=',
						   1243474231
						  ]
				    },
			'-fields' => 'row_id expires',
			'-single' => 1
		       );


print Dumper($ret);
