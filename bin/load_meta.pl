#!/usr/bin/perl

use lib '/dj/tools/perl-dbr/lib';

use DBR::Util::Logger;
use DBR;
use strict;

my $logger = new DBR::Util::Logger(-logpath => '/tmp/dbr_loadmeta.log', -logLevel => 'debug3');
my $dbr    = new DBR(
		     -logger => $logger,
		     -conf   => '/dj/tools/perl-dbr/examples/support/example_dbr.conf',
		    );

my $scandb = $ARGV[0];

my $confdb = 'dbrconf';
my $schema_id = 1;

my $conf_instance = $dbr->get_instance($confdb) or die "No config found for confdb $confdb";
my $scan_instance = $dbr->get_instance($scandb) or die "No config found for scandb $scandb";

my $dbrh = $scan_instance->connect or die "failed to connect";

my $ret = $dbrh->select(
			-table => 'album',
			-fields => 'album_id artist_id name'
		       ) or die 'failed to se;ect from album';


use Data::Dumper;
print Dumper($ret);
