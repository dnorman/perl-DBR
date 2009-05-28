package DBR::Query::Part::Compare;

use strict;
use base 'DBR::Query::Part';

my %sql_ops = (
	       eq      => '=',
	       ne      => '!=',
	       ge      => '>=',
	       le      => '<=',
	       gt      => '>',
	       lt      => '<',
	       like    => 'LIKE',
	       notlike => 'NOT LIKE',

	       in      => 'IN',     # \
	       notin   => 'NOT IN', #  |  not directly accessable
	       is      => 'IS',     #  |
	       isnot   => 'IS NOT'  # /
	      );

my %str_operators = map {$_ => 1} qw'eq ne like notlike';
my %num_operators = map {$_ => 1} qw'eq ne ge le gt lt';


sub new{
      my( $package ) = shift;
      my %params = @_;

      my $field = $params{field};
      my $value = $params{value};

      return $package->_error('field must be a Field object') unless ref($field) =~ /^DBR::Config::Field/; # Could be ::Anon
      return $package->_error('value must be a Value object') unless ref($value) eq 'DBR::Query::Part::Value';

      my $ref = ref($value);

      my $operator = $value->op_hint || $params{operator} || 'eq';

      if ($value->{is_number}){
	    return $package->_error("invalid operator '$operator'") unless $num_operators{ $operator };
      }else{
	    return $package->_error("invalid operator '$operator'") unless $str_operators{ $operator };
      }

      if ( $value->count > 1 ){
	    $operator = 'in'    if $operator eq 'eq';
	    $operator = 'notin' if $operator eq 'ne';
      }elsif ($value->is_null) {
	    $operator = 'is'    if $operator eq 'eq';
	    $operator = 'isnot' if $operator eq 'ne';
      }

      my $self = [ $field, $operator, $value ];

      bless( $self, $package );

      return $self;
}

sub type { return 'COMPARE' };
sub children { return () };
sub field    { return $_[0]->[0] }
sub operator { return $_[0]->[1] }
sub value    { return $_[0]->[2] }

sub sql   { return $_[0]->field->sql($_[1]) . ' ' . $sql_ops{ $_[0]->operator } . ' ' . $_[0]->value->sql($_[1]) }

sub _validate_self{ 1 }
