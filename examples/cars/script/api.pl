#!/usr/bin/perl -w

# how to use this script:
#   simply run the script from the demo directory (not the script subdir!)
#   see what various methods can do and what the code looks like.
#   watch the log file (/tmp/dbr_api.log) to see why the first pass
#     through some code is awfully slow, but very fast on all subsequent
#     calls.
#   change the log level in init() to measure real speed.
#   change any code to be more complex if you wish.
#   run all_cars.pl to see the data set being targeted by this code.
#   edit create.pl or run add_car.pl to change the data set.

# how to add more api code:
#   copy the needed structure in the apis() sub ... basically:
#   thing => {
#     package => 'Perl::Package::Of::Thing',
#     desc => 'Some description text about thing',
#     methods => {
#       name => {
#         before => 'Text to show before the source and output',
#         code => ...
#         after => 'Text to show after execution output',
#       },
#       name => { ... }
#       ...etc...
#     },
#   },
#   Note that the 'code' is optional, may be code text or an anonymous
#   sub, or a separate script sub named thing__method (2 undrescores!).
#   typically, you code an anonymous sub inline first, then change the
#   sub to => q^...code...^, or remove the code key completely and
#   place the code in a properly named sub.  See object__all for example.

# todo:
#   add benchmarking metrics on code execution.
#   add lots more api example code!

use strict;
use warnings;

use Data::Dumper;

use lib qw( ../lib ../../lib );
use DBR;
use DBR::Util::Logger;
use DBR::Util::Operator;

my ($logger,$dbr,$dbrh);
&init;

my $apis = &apis;
while (1) {
      print "\n" . '_'x80 . "\nWhat would you like to explore today?\n";
      map { print "\t$_\n" } sort keys %{$apis};
      print "\t\t(enter '?' for full index, or ?filter to search (try: ?enum))\n";
      my $thing;
      while (1) {
            print "> "; chomp( $thing = <STDIN> ); last unless $thing;
            last if exists $apis->{$thing};
            &api_index($1) and next if $thing =~ m!^\?(.*)!;
            print "invalid - try again\n";
      }
      last unless $thing;
      print "\n$apis->{$thing}->{package}\n";
      print "\n$apis->{$thing}->{desc}\n\n";

      print "Select a method:\n";
      map { print "\t$_\n" } sort keys %{$apis->{$thing}->{methods}};
      my $method;
      while (1) {
            print "> "; chomp( $method = <STDIN> ); last unless $method;
            last if exists $apis->{$thing}->{methods}->{$method};
            print "invalid - try again\n";
      }
      next unless $method;

      my $before = $apis->{$thing}->{methods}->{$method}->{before};
      print "\n$before\n" if $before;

      # show the code
      my $code = $apis->{$thing}->{methods}->{$method}->{code};
      if ($code) {
            unless (ref($code)) {
                  $code =~ s!^\n+!!;
                  $code =~ s!^(\s+)!!;
                  my $len = length($1);
                  $code =~ s!\n\s{$len}!\n!g;
                  print "\ncode:\n", $code, "\n";
            }
            else {
                  print "\ncode:\n\t(source code is not available yet)\n\n";
            }
      }
      else {
            my $source = &source_code( "$thing\__$method" );
            $code = $source ? "\&$thing\__$method" : 'print "No code found\n";';
            print "\ncode:\n$source\n";
      }

      # execute the code
      my $sub = ref($code) ? $code : eval( "sub { $code }" );
      print '-' x 80 . "\n";
      &$sub;
      print '-' x 80 . "\n";

      my $after = $apis->{$thing}->{methods}->{$method}->{after};
      print "$after\n" if $after;
}

sub apis {
      return {
              object => {
                         package => 'DBR::Interface::Object',
                         desc => 'Provides an object interface to a table.',
                         methods => {
                                     all => {
                                             before => 'Returns a ResultSet for all rows.',
                                             after => 'funky, eh?',
                                            },
                                     where => {
                                               before => 'Returns a ResultSet of filtered rows.',
                                               code => sub {
                                                     my $cars = $dbrh->car->where( model_year => GT 2006 );
                                                     print "\$cars is [".ref($cars)."]\n";
                                                     while (my $car = $cars->next) {
                                                           print join( ' ',
                                                                       $car->model_year,
                                                                       $car->model->make->name,
                                                                       $car->model->name,
                                                                       "\$car is [".ref($car)."]",
                                                                       "\n" );
                                                     }
                                               },
                                               after => 'funky, eh?',
                                              },
                                     insert => {
                                                before => '',
                                               },
                                     get => {
                                             before => '',
                                            },
                                     enum => {
                                              before => '',
                                             },
                                     parse => {
                                               before => '',
                                              },
                                    },
                        },
              dollars => {
                          package => 'DBR::Config::Trans::Dollars',
                          desc => '',
                          methods => {
                                      cents => {
                                                before => '',
                                               },
                                      dollars => {
                                                  before => '',
                                                 },
                                      format => {
                                                 before => '',
                                                },
                                     },
                         },
              unixtime => {
                           package => 'DBR::Config::Trans::UnixTime',
                           desc => '',
                           methods => {
                                       unixtime => {
                                                    before => '',
                                                   },
                                       date => {
                                                before => '',
                                               },
                                       time => {
                                                before => '',
                                               },
                                       datetime => {
                                                    before => '',
                                                   },
                                       fancytime => {
                                                     before => '',
                                                    },
                                       fancydatetime => {
                                                         before => '',
                                                        },
                                       fancydate => {
                                                     before => '',
                                                    },
                                       midnight => {
                                                    before => '',
                                                   },
                                       endofday => {
                                                    before => '',
                                                   },
                                       manip => {
                                                 before => '',
                                                },
                                      },
                          },
              enum => {
                          package => 'DBR::Config::Trans::Enum',
                          desc => "Enum values are bound to a table column\nand are identified by a handle string\nand are associated to a render string.",
                          methods => {
                                      handle => {
                                                 before => '',
                                                },
                                      name => {
                                               before => '',
                                              },
                                      chunk => {
                                                before => '',
                                               },
                                      in => {
                                             before => '',
                                            }
                                     },
                      },
              operator => {
                           package => 'DBR::Util::Operator',
                           desc => 'Operators may be used with a where condition.',
                           methods => {
                                       GT => {
                                              before => 'Greater than.',
                                              after => "The while loop that walks the resultset\nis currently a necessary evil for\nSQLite.  This would not be necessary for MySQL.\nThis will go away with a pending fix to count().",
                                              code => q^
                                                    my $cars = $dbrh->car->where( model_year => GT 2005 );
                                                    while ($cars->next) {}
                                                    print "found ", $cars->count, " cars.\n";
                                              ^,
                                             },
                                       LT => {
                                              before => 'Less than.',
                                              after => 'funky, eh?',
                                              code => sub {
                                              },
                                             },
                                       GE => {
                                              before => 'Greater than or equal to.',
                                              after => 'funky, eh?',
                                              code => sub {
                                              },
                                             },
                                       LE => {
                                              before => 'Less than or equal to.',
                                              after => 'funky, eh?',
                                              code => sub {
                                              },
                                             },
                                       NOT => {
                                               before => 'Not equal to.',
                                               after => 'funky, eh?',
                                               code => sub {
                                               },
                                              },
                                       LIKE => {
                                                before => 'Matches regular expression.',
                                                after => 'funky, eh?',
                                                code => sub {
                                                },
                                               },
                                       NOTLIKE => {
                                                   before => 'Not match regular expression.',
                                                   after => 'funky, eh?',
                                                   code => sub {
                                                   },
                                                  },
                                       EQ => {
                                              before => 'There is no EQ - it is implicit with a scalar value',
                                              after => 'funky, eh?',
                                             },
                                       IN => {
                                              before => 'There is no IN - it is implicit with a list value',
                                              after => 'funky, eh?',
                                             },
                                      },
                          },
             };
}

sub object__all {
      my $cars = $dbrh->car->all;
      print "\$cars is [".ref($cars)."]\n";
      while (my $car = $cars->next) {
            print join( ' ',
                        $car->model_year,
                        $car->model->make->name,
                        $car->model->name,
                        "  (car is ".ref($car).")" ),
                          "\n";
      }

      my $models = $dbrh->model->all;
      print "\n\$models is [".ref($models)."]\n";
      while (my $model = $models->next) {
            print join( ' ',
                        $model->make->name,
                        $model->name,
                        "  (model is ".ref($model).")" ),
                          "\n";
      }
}

sub source_code {
      my $sub_name = shift;
      open( IFILE, "<./script/api.pl" ) or die "failed to open api.pl\n";
      my @code = ();
      my $grabbing = 0;
      while (my $line = <IFILE>) {
            if ($grabbing) {
                  last if $line =~ m!^\}!;
                  push @code, $line;
            }
            if (!$grabbing) {
                  $grabbing = 1 if $line =~ m!^sub $sub_name!;
            }
      }
      close IFILE;
      return join( '', @code );
}

sub api_index {
      my $filter = shift;
      foreach my $thing (sort keys %{$apis}) {
            print "\t$thing\n" if !$filter || $filter && $thing =~ m!$filter!i;
            foreach my $method (sort keys %{$apis->{$thing}->{methods}}) {
                  if ($filter) {
                        print "\t$thing:$method\n" if $method =~ m!$filter!i;
                  }
                  else {
                        print "\t\t$method\n";
                  }
            }
      }
      return 1;
}

sub get_date {
      my ($obj,$field,$prompt) = @_;
      return &get_validated( $obj, $field,
                             "bad date/time format - try yyyy-mm-dd hh:mm:ss\n",
                             $prompt );
}

sub get_dollars {
      my ($obj,$field,$prompt) = @_;
      return &get_validated( $obj, $field,
                             "bad money format - try dddd.cc\n",
                             $prompt );
}

sub get_enum {
      my ($obj,$field,$prompt) = @_;
      return &get_validated( $obj, $field,
                             "bad value - check your spelling\n",
                             $prompt );
}

sub get_validated {
      my ($obj,$field,$error_msg,$prompt) = @_;

      if (!defined $prompt) {
            $prompt = $field;
            $prompt =~ s!_! !g;
      }

      while (1) {
            print "$prompt> ";
            chomp( my $value = <STDIN> );
            return undef unless $value;

            $value = $obj->parse( $field, $value )
              or print $error_msg and next;

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
