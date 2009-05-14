#!/usr/bin/perl

use strict;
use lib '/dj/tools/perl-dbr/lib';
use lib '/dj/tools/apollo-utils/lib';
#use lib '/dj/tools/esrp-utils/lib';
use ApolloUtils::Logger;
use DBR;
use DBR::Operators; # Imports operator functions



my $logger = new ApolloUtils::Logger(-logpath => '/dj/logs/dbr_test.log', -logLevel => 'debug3');

#<STDIN>;

my $dbr = new DBR(
		  -logger => $logger,
		  -conf   => '/dj/data/DBR.conf',
		 );


my $dbrh = $dbr->connect('esrp_main','query') || die "failed to connect";

#my $ret =  $dbh->orders->where(cust_id => 902349);
#my $ret =  $dbh->orders->get($order_ids);

# my $imaginary = $dbh->join(
# 			   orders.order_id => 'items.order_id',
# 			   orders.X => 'items.X',
# 			  );

# $imaginary->where(orders.cust_id => 902349 );

my $ret =  $dbrh->orders->where(
				cust_id => 902349,
				#status  => NOT 'ordered approved',
				#foo => \@somelist
			      );

#    die "select failed" unless
#      my $ret = $dbh->select(
#  			    -table => 'orders',
#  			    -fields => 'order_id total date_created',
#  			    -where => [cust_id => 'somevalue'],
#  			   );

use Data::Dumper;
while (my $order = $ret->next){

     # print $row->status ; # { handle => 'cancelled', }

      $order->status(3);

      print STDERR Dumper($order->ship_method_id);

     #my $items = $order->items;#->set(something => 'foo');
}

#undef $ret;

#$container->values('order_id');

#<STDIN>;
