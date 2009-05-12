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
      return $package->_error('value must be a Value object') unless ref($value) eq 'DBR::Query::Value';

      my $ref = ref($value);

      my $operator = $value->op_hint || $params{operator} || 'eq';

      if ($value->{is_number}){
	    return $self->_error("invalid operator '$operator'") unless $num_operators{ $operator };
      }else{
	    return $self->_error("invalid operator '$operator'") unless $str_operators{ $operator };
      }

      if ( $self->value->count > 1 ){
	    $operator = 'in'    if $operator eq 'eq';
	    $operator = 'notin' if $operator eq 'ne';
      }elsif ($self->value->is_null) {
	    $op = 'is'    if $op eq 'eq';
	    $op = 'isnot' if $op eq 'ne';
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

sub sql   { return $_[0]->field->sql . ' ' . $sql_ops{ $self->operator } . ' ' . $_[0]->value->sql }

sub _validate_self{ 1 }
