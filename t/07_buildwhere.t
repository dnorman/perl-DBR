#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';
use Time::HiRes;
use DBR::Util::Operator;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 43;

my $loops = 10000;

# As always, it's important that the sample database is not tampered with, otherwise our tests will fail
my $dbr = setup_schema_ok('music');

my $session = $dbr->session;

my $instance = $dbr->get_instance('test') or die "Failed to retrieve DB instance";
ok($instance, 'dbr instance');

my $schema = $instance->schema or die "Failed to retrieve schema";
ok($schema, 'dbr schema');

my $table = $schema->get_table( 'album' ) or die("failed to look up table");


my $builder = DBR::Interface::Where->new(
					 session       => $session,
					 instance      => $instance,
					 primary_table => $table,
					) or die("Failed to create wherebuilder");
# test(1,
#      album_id => 2
#     );
  # test(2,
  #      album_id => 2,
  #      name     => 'Track BA2',
  #      rating   => 'earbleed',
  #      date_released => GT '1 year ago',
  #     );

 test(2,
       album_id => 2,
       OR name     => 'Track BA2',
       OR rating   => 'earbleed',
       OR date_released => GT '1 year ago',
      );
 # test(2,
 #       album_id => 2,
 #       AND name     => 'Track BA2',
 #       AND rating   => 'earbleed',
 #       AND date_released => GT '1 year ago',
 #      );
exit;

# test(3,
#      album_id => 1,
#      AND(
#      rating   => 'earbleed',
# 	)
#     );
 # test(4,
 #      album_id => 123,
 #      AND (album_id => 456),
 #      OR (album_id => 789),
 #      album_id => 999
 #     );
 test(4,
      album_id => 123,
      AND (rating   => 'earbleed'),
      OR (album_id => 789),
      date_released => GT '1 year ago',
     );
# test(5,
#      date_released => GT '1 year ago',
#      AND (
# 	  album_id => 1,
# 	  OR (album_id => 2, rating => 'earbleed'),
# 	  OR (album_id => 3)
 #	 ),
#     );

sub test{
      my $ct = shift;
      my @where = @_;

      my $conn = $instance->connect;
      ok($conn,'Connect');

      my $where = $builder->build([
				   @where
				  ]
				 );
      ok($where,"Test build $ct");
      my $sql = $where->sql($conn);
      ok($sql,"Produce sql");
      diag ("SQL: $sql");
return;

      my $start = Time::HiRes::time();
      for (1..$loops){
	    my $where = $builder->build(
					[
					 @where
					]
				       );
	    my $sql = $where->sql($conn);
      }
      my $end = Time::HiRes::time();

      my $seconds = $end - $start;
      my $wps = $loops / $seconds;

      diag("Benchmark $ct took $seconds seconds");
      diag(sprintf("%0.4d",$wps). " where clauses per second");
      ok(1,"Benchmark $ct")
}
