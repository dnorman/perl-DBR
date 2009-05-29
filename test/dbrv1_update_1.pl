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

my $ret = $dbrh->update(
			'-table' => 'product',
			'-where' => {
				     'product_id' => [
						      'd in',
						      '617113',
						      '541506',
						      '617114'
						     ]
				    },
			'-fields' => {
				      'status' => [
						   'd',
						   3
						  ],
				      'date_pulled' => undef
				     }
		       );


print Dumper($ret);
