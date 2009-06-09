#!/usr/bin/perl -w

# add_car.pl
# populate the car table interactively.

# TODO:
# - support model.style enumeration
# - support car_feature.cost dollar value

use strict;
use warnings;

use lib qw( ../lib ../../lib );  # works without deploy; remove if ran deploy
use DBR;
use DBR::Util::Logger;

my ($logger,$dbr,$dbrh);
&init;

# intro
print "USAGE:\n\t<Enter> to quit\n\t'n' for a new item\n";

while (1) {
      &new_car or last;
}

sub new_car {
      print "\nAdding New Car:\n";

      my $model = &pick_model or return undef;

      my $salesperson = &pick_salesperson or return undef;

      print "car price> "; chomp( my $price = <STDIN> ); return undef unless $price;

      print "date received> "; chomp( my $date_received = <STDIN> ); return undef unless $date_received;

      print "date sold> "; chomp( my $date_sold = <STDIN> );  # optional (unsold)

      print "model year> "; chomp( my $model_year = <STDIN> ); return 0 if $model_year eq 'q';

      my $color = &pick_color or return undef;

      # insert new car
      my $car_id = $dbrh->car->insert(
                                      model_id       => $model->model_id,
                                      price          => $price,
                                      date_received  => &unix_timestamp( $date_received ),
                                      date_sold      => &unix_timestamp( $date_sold ),
                                      salesperson_id => $salesperson->salesperson_id,
                                      model_year     => $model_year,
                                      color          => $color->handle,
                                     )
        or return &_error( 'failed to create new car' );

      # features
      while (1) {
            my $feature = &pick_feature or last;

            $dbrh->car_feature->insert(
                                       car_id => $car_id,
                                       feature_id => $feature->feature_id,
                                      )
              or &_error( 'failed to insert car feature' );
      }

      return $car_id;
}

sub pick_color {
      print "COLORS:\n";

      foreach my $color ($dbrh->car->enum( 'color' )) {
            print "\t" . $color->handle . ': ' . $color . "\n";
      }

      print "color> "; chomp( my $handle = <STDIN> );
      return undef unless $handle;

      # validate
      my $color = $dbrh->car->parse( 'color', $handle )
        or return &_error( 'invalid color' );

      return $color;
}

sub pick_feature {
      print "\nFEATURES:\n";

      my $features = $dbrh->feature->all;
      while (my $feature = $features->next) {
            print "\t" . $feature->feature_id . ': ' . $feature->name . ' ... ' . $feature->description . "\n";
      }

      print "feature> "; chomp( my $feature_id = <STDIN> );
      $feature_id = &new_feature if $feature_id eq 'n';
      return undef unless $feature_id;

      my $feature = $dbrh->feature->where( feature_id => $feature_id )->next
        or die "invalid feature_id - try again\n";

      print "You selected: " . $feature->name . "\n";

      return $feature;
}

sub new_feature {
      print "Adding New Feature ...\n";

      print "name> "; chomp( my $name = <STDIN> ); return undef unless $name;
      print "description> "; chomp( my $description = <STDIN> ); return undef unless $description;

      my $feature_id = $dbrh->feature->insert(
                                              name => $name,
                                              description => $description,
                                             )
        or return &_error( 'failed to create new feature' );

      return $feature_id;
}

sub pick_salesperson {
      my $salesperson;
      do {
            print "\nSALESPEOPLE:\n";

            my $salespeople = $dbrh->salesperson->all;

            while (my $salesperson = $salespeople->next) {
                  print "\t" . $salesperson->salesperson_id . ': ' . $salesperson->name . "\n";
            }

            print "> "; chomp( my $salesperson_id = <STDIN> );
            $salesperson_id = &new_salesperson if $salesperson_id eq 'n';
            return undef unless $salesperson_id;

            $salesperson = $dbrh->salesperson->where( salesperson_id => $salesperson_id )->next
              or print "invalid selection\n";
      } until ($salesperson);

      print "You selected " . $salesperson->name . "\n";

      return $salesperson;
}

sub new_salesperson {
      print "Adding New Salesperson ...\n";

      print "name> "; chomp( my $name = <STDIN> ); return undef unless $name || $name eq 'q';

      my $salesperson_id = $dbrh->salesperson->insert(
                                                      name => $name
                                                     )
        or return &_error( 'failed to create new salesperson' );

      return $salesperson_id;
}

sub pick_model {
      print "\nMODELS:\n";

      my $models = $dbrh->model->all;

      while (my $model = $models->next) {
            print "\t" . $model->model_id . ': ' . $model->name . ' (' . $model->make->name . ")\n";
      }
      print "> "; chomp( my $model_id = <STDIN> );
      $model_id = &new_model if $model_id eq 'n';
      return undef unless $model_id;

      my $model = $dbrh->model->where( model_id => $model_id )->next
        or return &_error( "invalid model_id - try again" );

      print "You selected " . $model->name . "\n";

      return $model;
}

sub new_model {
      print "\nAdding New Model ...\n";

      my $make_id = &pick_make;
      print "model name> "; chomp( my $name = <STDIN> );  return 0 if $name eq 'q';
      my $model_id = $dbrh->model->insert(
                                          make_id => $make_id,
                                          name => $name,
                                         );
      return $model_id;
}

sub pick_make {
      print "\nMAKES:\n";

      my $makes = $dbrh->make->all;

      while (my $make = $makes->next) {
            print "\t" . $make->make_id . ': ' . $make->name .
              ($make->longname ? ' (' . $make->longname . ')' : '') . "\n";
      }

      print "> "; chomp( my $make_id = <STDIN> );
      $make_id = &new_make if $make_id eq 'n';
      return undef unless $make_id;

      my $make = $dbrh->make->where( make_id => $make_id )->next
        or return &_error( "invalid make id" );

      print "You selected " . $make->name . "\n";

      return $make_id;
}

sub new_make {
      print "\nAdding New Make ...\n";

      print "name> ";  chomp( my $name = <STDIN> ); return 0 if $name eq 'q';
      print "long name> "; chomp( my $longname = <STDIN> ); return 0 if $longname eq 'q';

      my $make_id = $dbrh->make->insert(
                                        name => $name,
                                        longname => $longname,
                                       )
        or die "failed to insert new make\n";

      return $make_id;
}


# this should not be necessary once date support in place
sub unix_timestamp {
      my $str = shift;
      chomp( my ($epoch) = `date -d '$str' +%s` );
      return $epoch;
};

sub init {
      $logger = new DBR::Util::Logger(
                                      -logpath => '/tmp/dbr_demo.log',
                                      -logLevel => 'debug3'
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
