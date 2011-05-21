#!/usr/bin/perl -w

# add_car.pl
# populate the car table interactively.

use strict;
use warnings;

use Data::Dumper;

use lib qw( ../lib ../../lib );  # works without deploy; remove if ran deploy
use DBR;
use DBR::Util::Logger;

my ($logger,$dbr,$dbrh);
&init;

# intro
print "\nUSAGE:\n\t<Enter> to quit\n\t'n' for a new item\n";

while (1) {
      &new_car or last;
}

sub new_car {
      print "\nAdding New Car:\n";

      my $model = &pick_model or return undef;

      my $salesperson = &pick_salesperson or return undef;

      my $price = &get_dollars( obj => $dbrh->car,
                                field => 'price',
                                prompt => 'car price',
                                required => 1 ) or return undef;

      my $date_received = &get_date( obj => $dbrh->car,
                                     field => 'date_received',
                                     required => 1 ) or return undef;

      my $date_sold = &get_date( obj => $dbrh->car,
                                 field => 'date_sold' ) or return undef;

      print "model year> "; chomp( my $model_year = <STDIN> ); return undef unless $model_year;

      my $color = &pick_color or return undef;

      # insert new car
      my $car_id = $dbrh->car->insert(
                                      model_id       => $model->model_id,
                                      price          => $price,
                                      date_received  => $date_received,
                                      date_sold      => $date_sold,
                                      salesperson_id => $salesperson->salesperson_id,
                                      model_year     => $model_year,
                                      color          => $color->handle,
                                     )
        or return &_error( 'failed to create new car' );

      # features
      while (1) {
            my $feature = &pick_feature or last;
            my $cost = &get_dollars( obj => $dbrh->car_feature,
                                     field => 'cost',
                                     required => 1 ) or return undef;

            $dbrh->car_feature->insert(
                                       car_id     => $car_id,
                                       feature_id => $feature->feature_id,
                                       cost       => $cost,
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

      return &get_enum( obj => $dbrh->car,
                        field => 'color' ) or return undef;
}

sub pick_feature {
      print "\nFEATURES:\n";

      my $features = $dbrh->feature->all;
      while (my $feature = $features->next) {
            print "\t" . $feature->feature_id . ': ' . $feature->name . ' ... ' . $feature->description . "\n";
      }

      my $feature;
      while (!$feature) {
            print "feature> "; chomp( my $feature_id = <STDIN> );
            $feature_id = &new_feature if $feature_id eq 'n';
            return undef unless $feature_id;

            $feature = $dbrh->feature->get( $feature_id )
              or print "invalid feature_id - try again\n";
      }
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
      print "\nSALESPEOPLE:\n";

      my $salespeople = $dbrh->salesperson->all;

      while (my $salesperson = $salespeople->next) {
            print "\t" . $salesperson->salesperson_id . ': ' . $salesperson->name . "\n";
      }

      my $salesperson;
      while (!$salesperson) {
            print "> "; chomp( my $salesperson_id = <STDIN> );
            $salesperson_id = &new_salesperson if $salesperson_id eq 'n';
            return undef unless $salesperson_id;

            $salesperson = $dbrh->salesperson->get( $salesperson_id )
              or print "invalid selection\n";
      }
      print "You selected " . $salesperson->name . "\n";

      return $salesperson;
}

sub new_salesperson {
      print "Adding New Salesperson ...\n";

      print "name> "; chomp( my $name = <STDIN> ); return undef unless $name;

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

      my $model;
      while (!$model) {
            print "> "; chomp( my $model_id = <STDIN> );
            $model_id = &new_model if $model_id eq 'n';
            return undef unless $model_id;

            $model = $dbrh->model->get( $model_id )
              or print "invalid model_id\n";
      }
      print "You selected " . $model->name . "\n";

      return $model;
}

sub new_model {
      print "\nAdding New Model ...\n";

      my $make = &pick_make or return undef;
      print "model name> "; chomp( my $name = <STDIN> );  return undef unless $name;
      my $style = &pick_style or return undef;
      my $model_id = $dbrh->model->insert(
                                          make_id => $make->make_id,
                                          name    => $name,
                                         );
      return $model_id;
}

sub pick_style {
      print "STYLES:\n";

      foreach my $style ($dbrh->model->enum( 'style' )) {
            print "\t" . $style->handle . ': ' . $style . "\n";
      }

      return &get_enum( obj => $dbrh->model,
                        field => 'style' ) or return undef;
}

sub pick_make {
      print "\nMAKES:\n";

      my $makes = $dbrh->make->all;

      while (my $make = $makes->next) {
            print "\t" . $make->make_id . ': ' . $make->name .
              ($make->longname ? ' (' . $make->longname . ')' : '') .
                ($make->country ? ' (' . $make->country->name . ')' : '') . "\n";
      }

      my $make;
      while (!$make) {
            print "> "; chomp( my $make_id = <STDIN> );
            $make_id = &new_make if $make_id eq 'n';
            return undef unless $make_id;

            $make = $dbrh->make->get( $make_id )
              or return &_error( "invalid make id" );
      }
      print "You selected " . $make->name . "\n";

      return $make;
}

sub new_make {
      print "\nAdding New Make ...\n";

      print "name> ";  chomp( my $name = <STDIN> ); return undef unless $name;
      print "long name> "; chomp( my $longname = <STDIN> );
      my $country = &pick_country or return undef;

      my $make_id = $dbrh->make->insert(
                                        name       => $name,
                                        longname   => $longname,
                                        country_id => $country->country_id,
                                       )
        or die "failed to insert new make\n";

      return $make_id;
}

sub pick_country {
      print "\nCOUNTRIES:\n";

      my $countries = $dbrh->country->all;

      while (my $country = $countries->next) {
            print "\t" . $country->country_id . ': ' . $country->name .
              ($country->abbrev ? ' (' . $country->abbrev . ')' : '') . "\n";
      }

      my $country;
      while (!$country) {
            print "> "; chomp( my $country_id = <STDIN> );
            $country_id = &new_country if $country_id eq 'n';
            return undef unless $country_id;

            $country = $dbrh->country->get( $country_id )
              or print "invalid country id\n";
      }
      print "You selected " . $country->name . "\n";

      return $country;
}

sub new_country {
      print "\nAdding New Country ...\n";

      print "name> ";   chomp( my $name = <STDIN> ); return undef unless $name;
      print "abbrev> "; chomp( my $abbrev = <STDIN> );

      my $country_id = $dbrh->country->insert(
                                              name   => $name,
                                              abbrev => $abbrev,
                                             )
        or die "failed to insert new country\n";

      return $country_id;
}

sub get_date    { return &get_validated( @_, error_msg => "bad date/time format - try yyyy-mm-dd hh:mm:ss" ) }
sub get_dollars { return &get_validated( @_, error_msg => "bad money format - try dddd.cc" ) }
sub get_enum    { return &get_validated( @_, error_msg => "bad value - check your spelling" ) }

sub get_validated {
      my %params = @_;  # obj, field, error_msg, prompt, required

      print "cannot validate - missing required obj or field param\n" and
        return undef unless $params{obj} && $params{field};

      my $prompt = $params{prompt};
      if (!defined $prompt) {
            $prompt = $params{field};
            $prompt =~ s!_! !g;
      }

      while (1) {
            print "$prompt> ";
            chomp( my $value = <STDIN> );
            return undef if $params{required} && length($value) == 0;

            $value = $params{obj}->parse( $params{field}, $value )
              or print "$params{error_msg}\n" and next;

            return $value;
      }
}

# this should not be necessary once date support in place
sub unix_timestamp {
      my $str = shift;
      my $epoch;
      chomp( ($epoch) = `date -d '$str' +%s` ) if $str;
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
