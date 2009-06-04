package DBR::Config::Trans::UnixDate;

use strict;
use base 'DBR::Config::Trans';

sub new { die "Should not get here" }


sub forward{
      my $self = shift;
      my $cents = shift;
      return bless( [$cents] , 'DBR::_DATE');
}

sub backward{
      my $self = shift;
      my $prettymoney = shift;

      $prettymoney =~ tr/0-9.-//cd; # the items listed are ALLOWED values
      return $self->_error('invalid value specified') unless $prettymoney;

      return sprintf("%.0f", ($prettymoney * 100) );
}

package DBR::_DATE;

use strict;
use Carp;
use overload 
#values
'""' => sub { $_[0]->format },
'0+' => sub { $_[0]->dollars },

#operators
'+'  => sub { new($_[0]->cents + _getcents($_[1])) },
'-'  => sub {
      my ($a,$b) = ($_[0]->cents, _getcents($_[1]));
      new ($_[2] ? $b - $a : $a - $b);
},

'*'  => sub { new($_[0]->cents * $_[1]) },
'/'  => sub {
      my ($a,$b) = ($_[0]->cents, $_[1] );
      new ($_[2] ? $b / $a : $a / $b);
},

'fallback' => 1,
'nomethod' => sub {croak "Dollar object: Invalid operation '$_[3]' The ways in which you can use dollar objects is restricted"}
;

sub cents   { $_[0]->[0] };
sub dollars { sprintf("%.02f",$_[0]->cents/100) };
sub format  {
      my $dollars = shift->dollars;
      $dollars =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g;
      return '$' . $dollars;
}

#utilities
sub new{ bless([ $_[1] || $_[0] ],'DBR::_DOLLARS') } # will work OO or functional
sub _getcents{
      my $val = $_[1] || $_[0]; # can be OO or functional
      return $val->cents if ref($val) eq __PACKAGE__;
      return sprintf("%.0f", ($val * 100) )
}


1;
