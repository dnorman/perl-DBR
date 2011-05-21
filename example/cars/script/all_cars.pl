#!/usr/bin/perl -w

# add_car.pl
# populate the car table interactively.

use strict;
use warnings;

use lib qw( ../lib ../../lib );  # works without deploy; remove if ran deploy
use DBR;
use DBR::Util::Logger;

my ($logger,$dbr,$dbrh);
&init;

print "\nCars and their features:\n";
my $cars = $dbrh->car->all;
while (my $car = $cars->next) {

      print join( "\n\t",
                  join( ' ',
                        $car->model_year,
                        $car->model->make->name,
                        $car->model->name,
                        '(' . $car->model->style . ')' ),
                  $car->price,
                  "made in: " . $car->model->make->country->name,
                  "received: " . $car->date_received,
                  "sold: " . $car->date_sold,
                  "salesperson: " . $car->salesperson->name,
                ) . "\n";

      my $car_features = $car->car_features;

      my $total = 0;
      while (my $car_feature = $car_features->next) {  # we could $car->car_features->next
            my $feature = $car_feature->feature;
            print "\t\t" . $feature->name . " (" . $car_feature->cost . ")\n";
            $total += $car_feature->cost;
      }
      print "\t\tTOTAL: $total\n";

      print "\n";
}

print "\nFeatures and the cars that have them:\n";
my $features = $dbrh->feature->all;
while (my $feature = $features->next) {
      print $feature->name . "\n";
      my $car_features = $feature->car_features;
      while (my $car_feature = $car_features->next) {
            my $car = $car_feature->car;
            print "\t\t" . join( ' ', $car->model_year, $car->model->make->name, $car->model->name ) . "\n";
      }
}


# this should not be necessary once date support in place
sub unix_timestamp {
      my $str = shift;
      chomp( my ($epoch) = `date -d '$str' +%s` );
      return $epoch;
};

sub init {
      $logger = new DBR::Util::Logger(
                                      -logpath => '/tmp/dbr_examples.log',
                                      -logLevel => 'debug2'
                                     )
        or return &_error( 'failed to get logger' );

      $dbr = new DBR(
                     -logger => $logger,
                     -conf   => 'conf/dbr.conf'
                    )
        or return &_error( 'failed to get dbr' );

      $dbrh = $dbr->connect('car_dealer')
        or return &_error( "failed to connect" );

      return 1;
}

sub _error {
      print STDERR scalar( localtime( time ) ) . ' ... ' . join( '', @_ ) . "\n";
      return undef;
}

1;
