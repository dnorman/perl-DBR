package DBR::Query::Part::Compare;

use strict;
use base 'DBR::Query::Part';
use Carp;

use constant ({
		F_FIELD     => 0,
		F_OPERATOR  => 1,
		F_VALUE     => 2,
		F_SQLFUNC   => 3
	       });

my %sql_ops = (
	       eq      => '=',
	       not     => '!=',
	       ge      => '>=',
	       le      => '<=',
	       gt      => '>',
	       lt      => '<',
	       like    => 'LIKE',
	       notlike => 'NOT LIKE',
	       between    => 'BETWEEN',
	       notbetween => 'NOT BETWEEN',

	       in      => 'IN',     # \
	       notin   => 'NOT IN', #  |  not directly accessable
	       is      => 'IS',     #  |
	       isnot   => 'IS NOT'  # /
	      );

my %str_operators = map {$_ => 1} qw'eq not like notlike';
my %num_operators = map {$_ => 1} qw'eq not ge le gt lt between notbetween';


sub new{
      my( $package ) = shift;
      my %params = @_;

      my $field = $params{field};
      my $value = $params{value};

      croak 'field must be a Field object' unless ref($field) =~ /^DBR::Config::Field/; # Could be ::Anon
      croak 'value must be a Value object' unless ref($value) eq 'DBR::Query::Part::Value';

      my $ref = ref($value);

      my $operator = $value->op_hint || $params{operator} || 'eq';

      if ($value->{is_number}){
	    $num_operators{ $operator } or croak "invalid operator '$operator'";
      }else{
	    $str_operators{ $operator } or croak "invalid operator '$operator'";
      }

      my $sqlfunc = \&_sql;
      if ($operator eq 'between' or $operator eq 'notbetween'){
	    $value->count == 2 or croak "between/notbetween comparison requires two values";
	    $sqlfunc = \&_betweensql;
      }elsif ( $value->count == 0 ){
            $sqlfunc  = $operator eq 'not' ? \&_always_sql : \&_never_sql;
      }elsif ( $value->count != 1 ){
            $sqlfunc = \&_null_split_sql if grep { !defined } $value->raw;
	    $operator = 'in'    if $operator eq 'eq';
	    $operator = 'notin' if $operator eq 'not';
      }elsif ($value->is_null) {
	    $operator = 'is'    if $operator eq 'eq';
	    $operator = 'isnot' if $operator eq 'not';
      }

      my $self = [ $field, $operator, $value, $sqlfunc];

      bless( $self, $package );

      return $self;
}

sub type { return 'COMPARE' };
sub children { return () };
sub field    { return $_[0]->[F_FIELD] }
sub operator { return $_[0]->[F_OPERATOR] }
sub value    { return $_[0]->[F_VALUE] }

sub sql   { shift->[F_SQLFUNC]->(@_) }

sub _sql{ return $_[0]->field->sql($_[1]) . ' ' . $sql_ops{ $_[0]->operator } . ' ' . $_[0]->value->sql($_[1]) }
sub _always_sql { '1 = 1' }
sub _never_sql { '0 = 1' }

sub _betweensql{
      my $quoted = $_[0]->value->quoted( $_[1] );
      @$quoted = sort {$a <=> $b} @$quoted;
      return $_[0]->field->sql($_[1]) . ' ' . $sql_ops{ $_[0]->operator } . " $quoted->[0] AND $quoted->[1]";
}

sub _null_split_sql {
    my ($self, $conn) = @_;
    my $val = $self->value;
    my $nnullv = $val->with_value([grep {defined} $val->raw]);

    my $ct = $nnullv->count;
    my $negated = $self->operator ne 'in';
    my $is_part = $self->field->sql($conn) . ($negated ? ' IS NOT NULL' : ' IS NULL');

    if ($ct == 0) {
        return $is_part;
    }
    else {
        my $newop = $ct > 1 ? ($negated ? 'notin' : 'in') : ($negated ? 'not' : 'eq');
        return '( ' . $is_part . ($negated ? ' AND ' : ' OR ') . $self->field->sql($conn) . ' ' . $sql_ops{$newop} . ' ' . $nnullv->sql($conn) . ' )';
    }
}

sub _validate_self{ 1 }

sub is_emptyset{ $_[0][F_SQLFUNC] == \&_never_sql }
