package DBR::Config::Trans::Percent;

use strict;
use base 'DBR::Config::Trans';

sub new { die "Should not get here" }


sub forward{
      my $self = shift;
      my $rawvalue = shift;
      return bless( [$rawvalue] , 'DBR::_PERCENT');
}

sub backward{
      my $self = shift;
      my $value = shift;

      return undef unless defined($value) && length($value);

      if( ref($value) eq 'DBR::_PERCENT' ){ # looks like it's a percent object
	    return $value->value;
      }

      $value =~ s/[^\d\.-]//g; # strip everything but digit and .
      unless( $value =~ /^\-?\d*\.?\d+$/ ){
	    $self->_error('invalid value specified');
	    return ();
      }

      return $value;
}

package DBR::_PERCENT;

use strict;
use Carp;
use overload 
#values
'""' => sub { $_[0]->format },
'0+' => sub { $_[0]->value },

#operators
'+'  => sub { new($_[0]->value + $_[1]) },
'-'  => sub {
      my ($a,$b) = ($_[0]->value, $_[1]);
      new ($_[2] ? $b - $a : $a - $b);
},

# comparisons
'eq' => sub { $_[0]->value == (0 + $_[1]) },
'ne' => sub { $_[0]->value != (0 + $_[1]) },

'*'  => sub { new($_[0]->value * sprintf("%f",$_[1]) ) },
'/'  => sub {
      my ($a,$b) = ($_[0]->value, sprintf("%f",$_[1]) );
      new ($_[2] ? $b / $a : $a / $b);
},

'fallback' => 1
;

*TO_JSON = \&format;

sub value  {
      return '' unless defined($_[0][0]);
      return $_[0][0]
};

sub format {
      return '' unless defined($_[0][0]);
      $_[0]->value . '%' 
};

#utilities
sub new{ bless([ $_[1] || $_[0] ],'DBR::_PERCENT') } # will work OO or functional


1;
