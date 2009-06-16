#!/usr/bin/perl -w

use strict;
use warnings;

my @subs = `find ../.. -name '*.pm' -exec grep -H '^sub' {} \\;`;

my $currfile = '';
foreach my $sub (@subs) {
      chomp $sub;
      $sub =~ s!^.*?lib/!!;
      my ($file,$name) = $sub =~ m!^([^:]+):sub\s+(\w+)!;
      if ($file ne $currfile) {
            print "\n$file:\n";
      }
      print "\t$name\n";
      $currfile = $file;
}

1;
