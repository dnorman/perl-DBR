package DBR::Query::RecordMaker;

use strict;
use base 'DBR::Common';

my $BASECLASS = 'DBR::Query::Record';
my $classidx = 0;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		 };

      bless( $self, $package );

      return( $self );
}

sub _mk_class{
      my $self = shift;

      my $class = $BASECLASS . 'C' . ++$classidx;

      no strict refs;
      @{"$class::ISA"} = 'TestMe';

      foreach my $method (@methods){
	    my $subref = $self->_mk_method(
					   mode  => 'rw',
					   index => $field->index,
					  );
	    *{"$class::$method"} = $subref
      }
}


sub _mk_method{
      my $self = shift;
      my $idx = shift;

      my $obj    = '$_[0]'; # $self   = shift
      my $update = '$_[1]'; # $update = shift
      my $value  = $obj . '->[' . $idx . ']';

      my $code;
      if($mode eq 'rw'){
	    $code = "   $update ? $obj->set( $update ) : $value   ";
      }elsif($mode eq 'ro'){
	    $code = "   $value   ";
      }

      return eval "sub {$code}";
}


1;
