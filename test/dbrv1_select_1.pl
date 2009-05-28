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
			'-table' => 'property_records',
			'-where' => {
				     'type_id' => [
						   'd',
						   2
						  ],
				     'prop_no' => {
						   '-table' => 'property_lookup',
						   '-where' => {
								'class' => [
									    'd in',
									    1
									   ]
							       },
						   '-field' => 'prop_no'
						  },
				     'item_id' => [
						   'in d',
						   '125668'
						  ]
				    },
			'-fields' => [
				      'item_id',
				      'prop_no',
				      'value'
				     ]

		       ) or die 'failed to select from album';


print Dumper($ret);
