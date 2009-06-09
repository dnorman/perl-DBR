#!/usr/bin/perl

use strict;
use lib '/dj/tools/perl-dbr/lib';
use lib '/dj/tools/apollo-utils/lib';
#use lib '/dj/tools/esrp-utils/lib';
use ApolloUtils::Logger;
use DBR;
use DBR::Util::Operator; # Imports operator functions

my $logger = new ApolloUtils::Logger(-logpath => '/dj/logs/dbr_test.log', -logLevel => 'debug3');

#<STDIN>;

my $dbr = new DBR(
		  -logger => $logger,
		  -conf   => '/dj/data/DBR.conf',
		 );

my $dbrh = $dbr->connect('esrp_main') || die "failed to connect";


#$dbr->timezone('America/New_York') or die "failed to set timezone";
#my $ret =  $dbh->orders->where(cust_id => 902349);
#my $ret =  $dbh->orders->get($order_ids);

# my $imaginary = $dbh->join(
# 			   orders.order_id => 'items.order_id',
# 			   orders.X => 'items.X',
# 			  );

# $imaginary->where(orders.cust_id => 902349 );
# my $obj = $dbrh->orders;

# $dbrh->_stopwatch();
# for (1..10000){
#       #my $foo = eval ' $obj->test();';
#       $obj->test();
#       #print STDERR "$foo\n";
# }

# $dbrh->_stopwatch('caller loopp');

# exit;


#  print "OPTIONS\n";
#  foreach my $option ( $dbrh->orders->enum('status') ){
#        print "Handle: " . $option->handle . "\n";
#        print "Concat: " . $option . "\n";
#        print "Quoted: $option\n";

#        print "IS EQ 'error'\n" if $option eq 'error';
#        print "IS NE 'error'\n" if $option ne 'error';
#        print "IS IN 'shipped settled'\n" if $option->in('shipped settled');

#        print "\n\n";
#  }
#  exit;

$dbrh->_stopwatch();
# for(1..10000){
#my $orders = $dbrh->orders->get(163675);#where( cust_id => 902349, );





my $orders = $dbrh->orders->where(
				cust_id => 902349,# + 100000,
				#date_created => LT time,
			       ) or die "where failed";

#my $lookup = $orders->lookup_hash('status ship_method_id');
#use Data::Dumper;
#print Dumper($lookup);

$dbr->timezone('America/New_York') or die "failed to set timezone";


use Data::Dumper;
print STDERR Dumper(scalar $orders->values('status date_created'));
#exit;

my $ct;
       while (my $order = $orders->next){

	     print "order_id is "   . $order->order_id . "\n";
	     print "  Status is "   . $order->status . "\n";
	     print "  Date Created is "   . $order->date_created . "\n";
	     print "  Date Created minus two days is "   . ($order->date_created - '2 days')  . "\n";
	     print "  Date Created midnight is "   . $order->date_created->midnight  . "\n";

#	     $order->status('settled') if !$ct++;

# 	     #print "Worked\n" if $order->status ne 'approved';
# 	     #$order->status('shipped') or die 'failed to set status';
# # 	     $dbrh->_stopwatch();

#   	      $order->set(status => 'shipped',
#    			 type => 'phone',
#    			 company_id => 1,
#    			)  or die 'failed to set';

# # 	     $dbrh->_stopwatch('set');
# 	     #$dbrh->_stopwatch();


 	     #my %fields = $order->gethash('status total prodtotal ship_method_id duties type');
 	     #print "fields are " . join(', ', map { "$_ => $fields{$_}" } keys %fields) . "\n";

 	     #print "YES\n" if $order->status->in('ordered error shipped');

	     print "\tItems:\n";
  	     my $items = $order->items;
  	     while (my $item = $items->next){

  		   my @ifields = $item->get('status product_id price');
		   print "\tITEM: fields are " . join(',',@ifields) . "\n";

  	     }

	     print "ITEM COUNT: ${\$items->count}\n";

# 	     if($items->count == 0){
		   
# 		   $order->delete;
# 	     }

	    # $dbrh->_stopwatch('get');

	     #print "Status is now " . $order->status . "\n"; # { handle => 'cancelled', }

# 	     print "Total is " . $order->total . " \n";
# 	     print "prodtotal is " . $order->prodtotal . " \n";
# 	     my $foo = $order->total;
# 	     print "Mod total is " . ($foo)  . " \n";

# 	     #print "Test passes \n" if $order->status->in('bar foo shipped');
# 	     print "the ref is " . ref($order->status) . "\n";
	     print "\n";
       }

$dbrh->_stopwatch('cycle');
# }

	     #       $order->status('approved') or die "failed to set status";
	#     print "date_created is ${\$order->date_created}\n";

	     #       #$self->{xml}->{order} = $order->fetch_hashref('order_id source company_id')

	     #      #my $items = $order->items;#->set(something => 'foo');
#$dbrh->orders->where( cust_id => 902349 )->set( status => 'approved' );



#$dbrh->orders->insert(cust_id => 902349, status=>'ordered');

#my $map = $orders->make_map('cust_id status');


#$my $order = $map{902349}->{'settled'}->[0];


#undef $ret;

#$container->values('order_id');

print "\n orders: ${\$orders->count}\n";

#print "\n\nPress a key to quit... \n";
#<STDIN>;
