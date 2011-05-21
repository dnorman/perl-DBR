#!/usr/bin/perl -w

# create.pl
# populate the application database using inserts.

use strict;
use warnings;

use lib qw( ../lib ../../lib );  # works without deploy; remove if ran deploy
use DBR;
use DBR::Util::Logger;

my ($logger,$dbr,$dbrh);
&init;


# clear
&truncate( $dbrh->country, 'country' );
&truncate( $dbrh->make, 'make' );
&truncate( $dbrh->model, 'model' );
&truncate( $dbrh->feature, 'feature' );
&truncate( $dbrh->car, 'car' );
&truncate( $dbrh->car_feature, 'car_feature' );
&truncate( $dbrh->salesperson, 'salesperson' );

sub truncate {
      my $table = shift or die "NOTHING!\n";
      my $table_name = shift;

      my $pkey_name = "$table_name\_id";

      my $all = $table->all or die "NO ALL!\n";
      while (my $row = $all->next) {
            $dbrh->delete(
                          -table => $table_name,
                          -where => { $pkey_name => [ 'd', $row->$pkey_name ] },
                         );
      }
}

# countries
my $usa_id   = $dbrh->country->insert( name => 'Unites States', abbrev => 'USA' );
my $gdr_id   = $dbrh->country->insert( name => 'Germany',       abbrev => 'GDR' );
my $india_id = $dbrh->country->insert( name => 'India',         abbrev => ''    );  # blank string to avoid warnings
my $japan_id = $dbrh->country->insert( name => 'Japan',         abbrev => ''    );  # blank string to avoid warnings

# makes
my $vw_id    = $dbrh->make->insert( name       => 'VW',
                                    longname   => 'Volkswagon',
                                    country_id => $gdr_id,
                                 );
my $tata_id  = $dbrh->make->insert( name       => 'Tata',
                                    longname   => 'Tata Motors',
                                    country_id => $india_id,
                                 );
my $bmw_id   = $dbrh->make->insert( name       => 'BMW',
                                    longname   => 'Bavarian Motor Works',
                                    country_id => $gdr_id,
                                 );
my $ford_id  = $dbrh->make->insert( name       => 'Ford',
                                    longname   => 'Form Motor Company',
                                    country_id => $usa_id,
                                 );
my $niss_id  = $dbrh->make->insert( name       => 'Nissan',
                                    longname   => 'Nissan',
                                    country_id => $japan_id,
                                 );
my $toy_id   = $dbrh->make->insert( name       => 'Toyota',
                                    longname   => 'Toyota',
                                    country_id => $japan_id,
                                 );
my $honda_id = $dbrh->make->insert( name       => 'Honda',
                                    longname   => 'Honda',
                                    country_id => $japan_id,
                                 );

# models
my $taurus_id  = $dbrh->model->insert( make_id => $ford_id,
                                       name    => 'Taurus SHO',
                                       style   => 'sedan' );
my $mustang_id = $dbrh->model->insert( make_id => $ford_id,
                                       name    => 'Mustang',
                                       style   => 'coupe' );
my $f150_id    = $dbrh->model->insert( make_id => $ford_id,
                                       name    => 'F-150',
                                       style   => 'pickup' );
my $f250_id    = $dbrh->model->insert( make_id => $ford_id,
                                       name    => 'F-250',
                                       style   => 'pickup' );
my $civic_id   = $dbrh->model->insert( make_id => $honda_id,
                                       name    => 'Civic DX',
                                       style   => 'compact' );
my $niss300_id = $dbrh->model->insert( make_id => $niss_id,
                                       name    => '300ZX',
                                       style   => 'coupe' );
my $niss350_id = $dbrh->model->insert( make_id => $niss_id,
                                       name    => '350Z',
                                       style   => 'coupe' );
my $camry_id   = $dbrh->model->insert( make_id => $toy_id,
                                       name    => 'Camry LE',
                                       style   => 'sedan' );

# features
my $sunroof_id  = $dbrh->feature->insert( name => 'Sun Roof',
                                          description => 'Window in roof that can be opened' );
my $moonroof_id = $dbrh->feature->insert( name => 'Moon Roof',
                                          description => 'Window in roof that cannot be opened' );
my $cruise_id   = $dbrh->feature->insert( name => 'Cruise Control',
                                          description => 'Adjustable speed control' );
my $navsys_id   = $dbrh->feature->insert( name => 'Navigation',
                                          description => 'Navigation guidance with voice control' );
my $hotseat_id  = $dbrh->feature->insert( name => 'Heated Seats',
                                          description => 'Stay warm in the cold weather' );
my $pwrseat_id  = $dbrh->feature->insert( name => 'Power Seats',
                                          description => 'Nine-way power adjustable seats (eject included)' );

# salesperson
my $daniel_id = $dbrh->salesperson->insert( name => 'Daniel' );
my $john_id   = $dbrh->salesperson->insert( name => 'John' );
my $ollie_id  = $dbrh->salesperson->insert( name => 'Ollie' );

# cars
my $red_350z = $dbrh->car->insert( model_id       => $niss350_id,
                                   price          => 28995,
                                   date_received  => &unix_timestamp( '2009-03-11 12:34:56' ),
                                   salesperson_id => $john_id,
                                   model_year     => 2005,
                                   color          => 'red',
                                 );
my $blue_f150 = $dbrh->car->insert( model_id       => $f150_id,
                                    price          => 24595,
                                    date_received  => &unix_timestamp( '2009-03-10 12:34:56' ),
                                    date_sold      => &unix_timestamp( '2009-04-15 07:14:21' ),
                                    salesperson_id => $daniel_id,
                                    model_year     => 2008,
                                    color          => 'blue',
                                  );

# car features
$dbrh->car_feature->insert( car_id => $red_350z, feature_id => $sunroof_id, cost => 447.21 );
$dbrh->car_feature->insert( car_id => $red_350z, feature_id => $pwrseat_id, cost => 124.95 );
$dbrh->car_feature->insert( car_id => $red_350z, feature_id => $cruise_id,  cost => 79.99 );

$dbrh->car_feature->insert( car_id => $blue_f150, feature_id => $moonroof_id, cost => 147.63 );
$dbrh->car_feature->insert( car_id => $blue_f150, feature_id => $cruise_id,   cost => 69.95 );

# races
$dbrh->race->insert( car_one => $red_350z, car_two => $blue_f150, event => 'California Speedway Race-Off 2009' );


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
