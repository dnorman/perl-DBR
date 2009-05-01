package DBR::Query::Record;

use strict;
use base 'DBR::Common';
use Symbol qw( qualify_to_ref );
use DBR::Query::Record;

my $BASECLASS = 'DBR::Query::Rec';
my $classidx = 0;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		 };

      bless( $self, $package ); # BS object

      my $fields = $params{fields} or return $self->_error('fields are required');

      my $class = $BASECLASS . ++$classidx;

      $self->{recordclass} = $class;

      #no strict 'refs';
      #@{"$class\:\:ISA" } = ($BASECLASS);

      foreach my $field (@$fields){
	    my $sub = $self->_mk_method(
					mode  => 'ro',
					index => $field->index,
				       ) or return $self->_error('Failed to create method');

	    my $method = $field->name;
	    push @{$self->{methods}||=[]}, $method;

	    print STDERR "$class\:\:$method\n";
	    my $symbol = qualify_to_ref( "$class\:\:$method" );

	    *$symbol = $sub;
      }

      return $self;
}

sub class { $_[0]->{recordclass} }

sub _mk_method{
      my $self = shift;
      my %params = @_;

      my $mode = $params{mode} or return $self->_error('Mode is required');
      my $idx = $params{index};
      return $self->_error('index is required') unless defined $idx;

      my $obj    = '$_[0]'; # $self   = shift
      my $update = '$_[1]'; # $update = shift
      my $value  = $obj . '[' . $idx . ']';

      my $code;
      if($mode eq 'rw'){
	    $code = "   $update ? $obj->set( $update ) : $value   ";
      }elsif($mode eq 'ro'){
	    $code = "   $value   ";
      }
      $code = "sub {$code}";
      $self->_logDebug2($code);

      return eval $code;
}


sub DESTROY{ # clean up the temporary object from the symbol table
      my $self = shift;
      $self->_logDebug2('Destroy');
      #undef @{"$class::ISA" };
      my $class = $self->{recordclass};
      foreach my $method (@{$self->{methods}}){
	    my $symbol = qualify_to_ref( "$class\:\:$method" );
	    undef *$symbol;
	    #$self->_logDebug2("undef '$class\:\:$method'");
      }
}

package DBR::Query::Rec;




1;
