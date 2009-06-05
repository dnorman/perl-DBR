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
      }elsif($value =~ /^\d+$/){ # smells like a unixtime
	    return $value;
      }else{

	    # 	    my ($mon,$mday,$year,$hour,$min,$sec,$tz_abbrev) = 
# 	      $date =~ /^(\d{1,2})[^\d](\d{1,2})[^\d](\d{2,4})[^\d]*(\d{1,2})?[^\d]?(\d{1,2})?[^\d]?(\d{1,2})?\s*([A-Z]T)?[^\d]*$/i;

# 	    my $dt = DateTime->new( year   => 1066,
#                                      month  => 10,
#                                      day    => 25,
#                                      hour   => 7,
#                                      minute => 15,
#                                      second => 47,
#                                      nanosecond => 500000000,
#                                      time_zone  => 'America/Chicago',
	    #                                    );

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
 '+'  => sub { $_[0]->manip( $_[1], 'add' )      || croak "Invalid date manipulation '$_[1]'" },
 '-'  => sub { $_[0]->manip( $_[1], 'subtract' ) || croak "Invalid date manipulation '$_[1]'" },

# Some ideas:
# 

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
      return strftime ("%H:%M:%S %Z", localtime($_[0][0]));
}

sub datetime  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%D %H:%M:%S %Z", localtime($_[0][0]));
}

sub fancytime  {
      local($ENV{TZ}) = ${$_[0][1]}; tzset();
      return strftime ("%I:%M:%S %p %Z", localtime($_[0][0]));
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

sub manip{
      my $self = shift;
      my $manip = shift;
      my $mode = shift;

      $manip =~ s/^\s+|\s+$//g;
      return undef unless $manip;

      my ($number, $unit) = $manip =~ /^(\d+)\s+([A-Za-z]+?)s?$/;
      $unit = lc($unit);

      my $unixtime = $self->unixtime;

      # This isn't actually the correct way to do this, on account of DST nd leap year and so on,
      # just a proof of concept. Should probably just farm it out to Date::Manip

      my $diff;
      if($unit eq 'second'){
	    $diff = $number
      }elsif($unit eq 'minute'){
	    $diff = $number * 60;
      }elsif($unit eq 'hour'){
	    $diff = $number * 3600;
      }elsif($unit eq 'day'){
	    $diff = $number * 86400;
      }elsif($unit eq 'year'){
	    $diff = $number * 31536000;
      }else{
	    return undef;
      }

      if ($mode eq 'add'){
	    return $self->new( $unixtime + $diff );
      }elsif($mode eq 'subtract'){
	    return $self->new( $unixtime - $diff );
      }

      return undef;

}


#              uxtime , tzref
sub new{ bless([ $_[1], $_[0][1] ],'DBR::_UXTIME') }

1;
