package DBR::Util::Operator;

use strict;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(GT LT GE LE NOT LIKE NOTLIKE BETWEEN NOTBETWEEN);

# Object oriented
sub new{
      my $package  = shift;
      my $operator = shift;
      my $value    = shift;

      my $self  = [$operator,$value];
      bless ( $self, $package );
      return ( $self );
}

sub operator {$_[0]->[0]}
sub value    {$_[0]->[1]}

# EXPORTED:

sub GT   ($) { __PACKAGE__->new('gt',  $_[0]) }
sub LT   ($) { __PACKAGE__->new('lt',  $_[0]) }
sub GE   ($) { __PACKAGE__->new('ge',  $_[0]) }
sub LE   ($) { __PACKAGE__->new('le',  $_[0]) }
sub NOT  ($) { __PACKAGE__->new('not', $_[0]) }
sub LIKE ($) { __PACKAGE__->new('like',$_[0]) }
sub NOTLIKE ($) { __PACKAGE__->new('notlike',$_[0]) }

sub BETWEEN    ($$) { __PACKAGE__->new('between',   [ $_[0],$_[1] ]) }
sub NOTBETWEEN ($$) { __PACKAGE__->new('notbetween',[ $_[0],$_[1] ]) }

1;
