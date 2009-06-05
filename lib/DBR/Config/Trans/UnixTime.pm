package DBR::Config::Trans::UnixTime;

use strict;
use base 'DBR::Config::Trans';
use strict;

sub new { die "Should not get here" }

sub init {
      my $self = shift;
      $self->{tzref} = $self->{session}->timezone_ref or return $self->_error('failed to get timezone ref');
      return 1;
}

sub forward{
      my $self = shift;
      my $unixtime = shift;
      return bless( [$unixtime,$self->{tzref}] , 'DBR::_UXTIME');
}

sub backward{
      my $self = shift;
      my $value = shift;

      if(ref($value) eq 'DBR::_UXTIME'){ #ahh... I know what this is
	    return $value->unixtime;
      }elsif($value =~ /^\d$/){ # smells like a unixtime
	    return $value;
      }else{
	    return $self->_error('I can dish it out, but I cant take it... yet');
      }

}

package DBR::_UXTIME;

use strict;
use POSIX qw(strftime tzset);
use Carp;
use overload 
#values
'""' => sub { $_[0]->datetime },
'0+' => sub { $_[0]->unixtime },

#operators
# '+'  => sub { new($_[0]->cents + _getcents($_[1])) },
# '-'  => sub {
#       my ($a,$b) = ($_[0]->cents, _getcents($_[1]));
#       new ($_[2] ? $b - $a : $a - $b);
# },

# '*'  => sub { new($_[0]->cents * $_[1]) },
# '/'  => sub {
#       my ($a,$b) = ($_[0]->cents, $_[1] );
#       new ($_[2] ? $b / $a : $a / $b);
# },

'fallback' => 1,
'nomethod' => sub {croak "UnixTime object: Invalid operation '$_[3]' The ways in which you can use UnixTime objects is restricted"}
;

sub unixtime { $_[0][0] };

# Using $ENV{TZ} and the posix functions is ugly... and about 60x faster than the alternative in benchmarks

sub date  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%D", localtime($_[0][0]));
}

sub time  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%H:%M:%S", localtime($_[0][0]));
}

sub datetime  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%D %H:%M:%S", localtime($_[0][0]));
}

sub fancytime  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%I:%M:%S %p", localtime($_[0][0]));
}

sub fancydatetime  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%A %B %e %H:%M:%S %Y", localtime($_[0][0]));
}

sub fancydate  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%A %B %e, %Y", localtime($_[0][0]));
}

sub midnight{
      my $self = shift;

      local($ENV{TZ}) = ${$self->[1]}; tzset();
      my ($sec,$min,$hour) = localtime($self->[0]);

      my $midnight = $self->[0] - ($sec + ($min * 60) + ($hour * 3600) ); # rewind!
      return $self->new($midnight);

}

sub endofday{
      my $self = shift;

      local($ENV{TZ}) = ${$self->[1]}; tzset();
      my ($sec,$min,$hour) = localtime($self->[0]);

      my $endofday = $self->[0] + 86399 - ($sec + ($min * 60) + ($hour * 3600) ) ; # rewind!
      return $self->new($endofday);
}

#              uxtime , tzref
sub new{ bless([ $_[1], $_[0][1] ],'DBR::_UXTIME') }

1;
