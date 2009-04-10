package DBR::Query::QPart;

use strict;
use base 'DBR::Common';

my %operators = (
		 like => 'LIKE',
		 '<>' => ,
		 '>=' => ,
		 '<=' => ,
		 '>' => ,
		 '<' => ,
		);


sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  logger  => $params->{logger},
		 };

      bless( $self, $package );

      if( $params{value} ){

      }elsif($params){
	    
      }else{
	    return $self->_error('value must be specified');
      }

      my $is_number = die;

      if ($flags =~ /like/) { # like
	return $self->_error('LIKE flag disabled without the allowquery flag') unless $self->{config}->{allowquery};
	$operator = 'LIKE';
      } elsif ($flags =~ /\<\>/) { # greater than less than=
	$operator = '<>';
	$value->[0] .= ' d';
      } elsif ($flags =~ /\>=/) { # greater than eq
			  $operator = '>=';
			  $value->[0] .= ' d';
		    } elsif ($flags =~ /\<=/) { # less than eq
			  $operator = '<=';
			  $value->[0] .= ' d';
		    } elsif ($flags =~ /\>/) { # greater than
			  $operator = '>';
			  $value->[0] .= ' d';
		    } elsif ($flags =~ /\</) { # less than
			  $operator = '<';
			  $value->[0] .= ' d';
		    }else{
			  $cont = 1;
		    }

		    my @fvalues = $self->quote($value,$aliasmap);
		    return $self->_error("Quoting error with field $key") unless defined($fvalues[0]);

		    if ($cont) {
			  if ($flags =~ /!in/) {
				if (@fvalues > 1) {
				      $operator = 'NOT IN';
				      $blist = 1;
				} else {
				      $operator = '!=';
				}
			  } elsif ($flags =~ /in/) {
				if (@fvalues > 1) {
				      $operator = 'IN';
				      $blist = 1;
				} else {
				      $operator = '=';
				}
			  } elsif ($flags =~ /!/) {
				$operator = '!=';
			  } else {
				$operator = '=';
			  }
		    }
      return( $self );
}

1;
