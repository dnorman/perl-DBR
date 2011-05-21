#!/usr/bin/perl
#!/usr/bin/perl -w

# find.pl
# search for cars

use strict;
#use warnings;

use Data::Dumper;

use lib qw( ../lib ../../lib );  # works without deploy; remove if ran deploy
use DBR;
use DBR::Util::Logger;
use DBR::Util::Operator;

my ($logger,$dbr,$dbrh);
&init;

my %fields = (
              'Country'      => { fields => [ 'model.make.country.name' ] },
              'Feature Cost' => { fields => [ 'car_features.cost' ], type => 'dollars' },
              'Feature'      => { fields => [ 'car_features.feature.name' ] },
              'Make'         => { fields => [ 'model.make.name' ] },
              'Model'        => { fields => [ 'model.name' ] },
              'Price'        => { fields => [ 'price' ], type => 'dollars' },
              'Received'     => { fields => [ 'date_received' ], type => 'date' },
              'Salesperson'  => { fields => [ 'salesperson.name' ] },
              'Sold'         => { fields => [ 'date_sold' ], type => 'date' },
              'Style'        => { fields => [ 'model.style' ], type => 'enum' },
              'Year'         => { fields => [ 'model_year' ], type => 'number' },
             );

my %where = ();
my @choices = sort keys %fields;
while (1) {
      my $choice = 0;
      map { print ++$choice . ": $_\n" } @choices;
      print "> "; chomp( $choice = <STDIN> ); last unless $choice;
      my $prompt = $choices[$choice-1];
      my $field = $fields{$prompt};
      print "$prompt> "; chomp( my $value = <STDIN> ); next unless $value;
      foreach my $path (@{$field->{fields}}) {
            if ($field->{type} && $field->{type} =~ m!^(date|dollars|number)$!) {
                  if (my ($op,$val) = $value =~ m!([A-Z]{2,})\s+(.*)!) {
                        $where{$path} = eval "$op $val";
                  }
                  else {
                        $where{$path} = $value;
                  }
            }
            else {
                  $where{$path} = $value =~ m!%! ? LIKE $value : $value;  # enum too
            }
      }
}
exit unless %where;
print "WHERE:\n" . Dumper( \%where );

print "\nFOUND:\n";
my $matches = $dbrh->car->where( %where ) or die "query failed\n";
while (my $car = $matches->next) {
      print join( ' ',
                  $car->model_year,
                  $car->model->make->name,
                  $car->model->name ) . "\n";
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
