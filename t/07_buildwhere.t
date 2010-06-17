#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';
use Time::HiRes;
use DBR::Util::Operator;
use Carp;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More;

my $testct = 0;
my $loops = 5000;

# As always, it's important that the sample database is not tampered with, otherwise our tests will fail
my $dbr = setup_schema_ok('music');

my $session = $dbr->session;

my $instance = $dbr->get_instance('test') or die "Failed to retrieve DB instance";
ok($instance, 'dbr instance');

my $schema = $instance->schema or die "Failed to retrieve schema";
ok($schema, 'dbr schema');

test(
     [ album_id => 2 ],
     'album_id = 2'
    );
test(
     [ album_id => 1, rating   => 'earbleed' ],
     'album_id = 1 AND rating = 9'
    );
test(
     [ album_id => 1, AND rating   => 'earbleed' ],
     'album_id = 1 AND rating = 9'
    );
test(
     [
      album_id => 2,
      name     => 'Track BA2',
      rating   => 'earbleed',
      date_released => GT 'November 26th 2005'
     ],
     "album_id = 2 AND date_released > 1132992000 AND name = 'Track BA2' AND rating = 9"
    );

test([
      album_id => 2,
      OR name     => 'Track BA2',
      OR rating   => 'earbleed',
      OR date_released => GT 'November 26th 2005'
     ],
     "album_id = 2 OR (name = 'Track BA2' OR (rating = 9 OR date_released > 1132992000))"
    );
test([
      album_id => 2,
      AND name => 'Track BA2',
      AND rating => 'earbleed',
      AND date_released => GT 'November 26th 2005'
     ],
     "album_id = 2 AND date_released > 1132992000 AND name = 'Track BA2' AND rating = 9"
    );

test([
      (
       ( album_id => 1, AND rating => 'earbleed' ),
       OR album_id => 789 
      ),   # closing peren ends the list of args to OR
      date_released => GT 'November 26th 2005',
     ],
     "((album_id = 1 AND rating = 9) OR album_id = 789) AND date_released > 1132992000"
    );

test([
      album_id => 1,
      AND (rating   => 'earbleed', OR album_id => 789 ),
      AND date_released => GT 'November 26th 2005'
     ],
     "(rating = 9 OR album_id = 789) AND album_id = 1 AND date_released > 1132992000"
     );
test([
      date_released => GT 'November 26th 2005',
      album_id => 1,
      OR (album_id => 2, rating => 'earbleed'),
      OR (album_id => 3)
     ],
     "((album_id = 1 AND date_released > 1132992000) OR (album_id = 2 AND rating = 9)) OR album_id = 3"
    );

test([
      date_released => GT 'November 26th 2005',
      AND (
	   album_id => 1,
	   OR (album_id => 2, rating => 'earbleed'),
	   OR (album_id => 3)
	  )
     ],
     "((album_id = 1 OR (album_id = 2 AND rating = 9)) OR album_id = 3) AND date_released > 1132992000"
    );

test([
      'artist.name'      => 'Artist A',
      'artist.artist_id' => 1
     ],
     "(b.artist_id = 1 AND b.name = 'Artist A') AND a.artist_id = b.artist_id"
    );

test([
      'artist.name' => 'Artist A',
      AND
      'artist.artist_id' => 1
     ],
     "(b.artist_id = 1 AND b.name = 'Artist A') AND a.artist_id = b.artist_id"
    );

test([
      (
       'artist.name' => 'Artist A',
       AND
       'artist.artist_id' => 1
      ),
      OR
      'artist.name' => 'Artist B',
     ],
     "((b.artist_id = 1 AND b.name = 'Artist A') AND a.artist_id = b.artist_id) OR (c.name = 'Artist B' AND a.artist_id = c.artist_id)"
    );

test([
      'artist.name' => 'Artist A',
      AND (
	   'artist.artist_id' => 1,
	   OR
	   'artist.name' => 'Artist B'
	  )
     ], # A little less than efficient SQL-wise... but technically correct
     "((c.artist_id = 1 AND a.artist_id = c.artist_id) OR (d.name = 'Artist B' AND a.artist_id = d.artist_id)) AND b.name = 'Artist A' AND a.artist_id = b.artist_id"
    );

done_testing();
exit;


sub test{
      my $where = shift;
      my $reference_sql   = shift;

      $testct++;
      my $conn = $instance->connect('conn');
      ok($conn,'Connect');


      my $table = $schema->get_table( 'album' ) or die("failed to look up table");

      my $builder = DBR::Interface::Where->new(
					       session       => $session,
					       instance      => $instance,
					       primary_table => $table,
					      ) or die("Failed to create wherebuilder");

      my $output = $builder->build( @$where );
      ok($output,"Test build $testct");
      my $sql = $output->sql($conn);
      ok($sql,"Produce sql") or return;
      diag ("SQL:  $sql");
      diag ("WANT: $reference_sql");
      ok($sql eq $reference_sql,"SQL correctness check") or return;

      return 1;  # Benchmarking currently doesn't work with joins cus of an inability to reset aliases

      my $start = Time::HiRes::time();
      for (1..$loops){
	    my $output = $builder->build( @$where ) || confess 'Failed to build where';
	    my $sql    = $output->sql( $conn )     || confess 'Failed to generate SQL';
      }
      my $end = Time::HiRes::time();

      my $seconds = $end - $start;
      my $wps = $loops / $seconds;

      diag("Benchmark $testct took $seconds seconds. (" . sprintf("%0.4d",$wps). " per second)");
}
