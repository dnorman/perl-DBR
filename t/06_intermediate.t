#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More;

my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('test');
ok($dbh, 'dbr connect');
my $rv;
# Repeat the whole test twice to test both query modes (Unregistered and Prefetch)
for(1..2){

      my $artists = $dbh->artist->all();
      ok( defined($artists) , 'select all artists');

      # this will loop four times
      while (my $artist = $artists->next()) {

	    my $albums = $artist->albums;
	    ok($albums, 'retrieve albums');
	    while(my $album = $albums->next){
		  my $date = $album->date_released;
		  ok(defined($date), '$date defined');
	    }
      }

}

done_testing();
