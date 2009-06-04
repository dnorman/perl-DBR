#!/usr/bin/perl

use lib '/dj/tools/perl-dbr/lib';

use DBR::Util::Logger;
use DBR::Util::ScanDB;

use DBR;
use strict;

my ($conffile,$scandb,$confdb) = @ARGV;
$confdb ||= 'dbrconf';

my $logger = new DBR::Util::Logger(-logpath => '/tmp/dbr_loadmeta.log', -logLevel => 'debug3');
my $dbr    = new DBR(
		     -logger => $logger,
		     -conf   => $conffile,
		    );

my $conf_instance = $dbr->get_instance($confdb) or die "No config found for confdb $confdb";
my $scan_instance = $dbr->get_instance($scandb) or die "No config found for scandb $scandb";

my $scanner = DBR::Util::ScanDB->new(
				     logger => $logger,
				     conf_instance => $conf_instance,
				     scan_instance => $scan_instance,
				    );


$scanner->scan() or die "Failed to scan $scandb";
