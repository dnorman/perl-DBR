package DBR::Query::Record;

use strict;
use base 'DBR::Common';
use Symbol qw( qualify_to_ref );
use DBR::Query::Record;
use DBR::Query::Part;

my $BASECLASS = 'DBR::Query::Rec';
my $classidx = 0;


sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		  dbrh   => $params{dbrh},
		  query  => $params{query},
		 };

      bless( $self, $package ); # BS object

      $self->{query} or return $self->_error('query is required');

      $self->{scope} = $self->{query}->scope; # optional

      my $fields = $self->{query}->fields or return $self->_error('Failed to get query fields');
      $fields = [ @$fields ]; #Shallow clone

      $self->{dbrh} or return $self->_error('dbrh object must be specified');

      my $class = $BASECLASS . ++$classidx;

      $self->{recordclass} = $class;


      my @table_ids;
      # It's important that we preserve the specific field objects from the query. They have payloads that new ones do not.
      foreach my $field (@$fields){ 
	    my $field_id = $field->field_id or next; # Anon fields have no field_id
	    my $table_id = $field->table_id;
	    $self->{fieldmap}->{ $field_id } = $field;

	    push @table_ids, $table_id;
      }

      foreach my $table_id ($self->_uniq( @table_ids )){

	    my $table = DBR::Config::Table->new(
						dbrh     => $self->{dbrh},
						logger   => $self->{logger},
						table_id => $table_id,
					       ) or return $self->_error('Failed to create table object');

	    my $allfields = $table->fields or return $self->_error('failed to retrieve fields for table');

	    my @pk;
	    #We need to check to make sure that all PK fields are included in the query results.
	    #These are field objects, but don't use them elsewhere. They are devoid of query indexes
	    foreach my $checkfield (@$allfields){
		  my $field = $self->{fieldmap}->{ $checkfield->field_id };

		  if( $checkfield->is_pkey ){
			if(!$field){
			      return $self->_error('Resultset is missing primary key field ' . $checkfield->name);
			}

			push @pk, $field;
		  }else{
			if(!$field){
			      push @$fields, $checkfield; #not in the resultset, but we should still know about it
			}
		  }
	    }

	    $self->{tablemap}->{$table_id} = $table;
	    $self->{pkmap}->{$table_id}    = \@pk;

      }
      my $mode = 'rw';
      foreach my $field (@$fields){

	    my $sub = $self->_mk_method(
					mode  => $mode,
					index => $field->index,
					field => $field,
				       ) or return $self->_error('Failed to create method');

	    my $method = $field->name;
	    push @{$self->{methods}||=[]}, $method;

	    #print STDERR "$class\:\:$method\n";
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

      my $field = $params{field};

      my $record   = '$_[0]'; # $self   = shift
      my $setvalue = '$_[1]'; # $set    = shift
      my $value;

      my $idx = $params{index};
      if(defined $idx){ #did we actually fetch this?
	    $value = $record . '[' . $idx . ']';
      }else{
	    $value = "\$p->_get( $record, \$f )";
      }

      my $code;
      my $trans;
      if($mode eq 'rw' && $field){
	    if ($trans = $field->translator){
		  $value = "\$t->forward($value)";
	    }

	    $code = "   exists( $setvalue ) ? \$p->_set( $record, \$f, $setvalue ) : $value   ";
      }elsif($mode eq 'ro'){
	    $code = "   $value   ";
      }
      $code = "sub {$code}";
      $self->_logDebug2($code);

      return $self->_eval_method($field,$trans,$code);
}

#Seperate method for scope cleanliness
sub _eval_method{
      my $p = shift;
      my $f = shift;
      my $t = shift;

      return eval shift;
}

sub _set{
       my $self = shift;
       my $record = shift;
       my $field = shift;
       my $value = shift;

       # DO THIS ONCE PER TABLE
       my $table = $self->{tablemap}->{ $field->table_id } || return $self->_error('Missing table for table_id ' . $field->table_id );
       my $pk    = $self->{pkmap}->{ $field->table_id }    || return $self->_error('Missing primary key');

       my $setvalue = $field->makevalue($value) or return $self->_error('failed to create setvalue object');
       my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');

       ##### Where ###########
       my @and;
       foreach my $part (@{ $pk }){
	     my $value = $part->makevalue( $record->[ $part->index ] ) or return $self->_error('failed to create value object');
	     my $outfield = DBR::Query::Part::Compare->new( field => $part, value => $value ) or return $self->_error('failed to create compare object');

	     push @and, $outfield;
       }


       my $outwhere = DBR::Query::Part::And->new(@and);
       #######################

       my $query = DBR::Query->new(
				   logger => $self->{logger},
				   dbrh   => $self->{dbrh},
				   tables => $table->name,
				   where  => $outwhere,
				   update => { set => $setobj }
				  ) or return $self->_error('failed to create Query object');

       return $query->execute() or return $self->_error('failed to execute');


}
sub _get{
       my $self = shift;
       my $record = shift;
       my $field = shift;

       # DO THIS ONCE PER TABLE
       my $table = $self->{tablemap}->{ $field->table_id } || return $self->_error('Missing table for table_id ' . $field->table_id );
       my $pk    = $self->{pkmap}->{ $field->table_id }    || return $self->_error('Missing primary key');

       ##### Where ###########
       my @and;
       foreach my $part (@{ $pk }){
	     my $value = $part->makevalue( $record->[ $part->index ] ) or return $self->_error('failed to create value object');
	     my $outfield = DBR::Query::Part::Compare->new( field => $part, value => $value ) or return $self->_error('failed to create compare object');

	     push @and, $outfield;
       }


       my $outwhere = DBR::Query::Part::And->new(@and);
       #######################

       my $query = DBR::Query->new(
				   logger => $self->{logger},
				   dbrh   => $self->{dbrh},
				   tables => $table->name,
				   where  => $outwhere,
				   select => { fields => [$field] }
				  ) or return $self->_error('failed to create Query object');

       my $sth = $query->execute(
				 sth_only => 1 # Don't want to create another resultset
				) or return $self->_error('failed to execute');

       $sth->execute() or return $self->_error('Failed to execute sth');
       my $row  = $sth->fetchrow_arrayref() or return $self->_error('Failed to fetchrow');

       #HERE HERE HERE cache this, and update the accessor?
       $self->{scope}->addfield($field) or return $self->_error('Failed to add field to scope');

       return $row->[0];
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

1;

package DBR::Query::Rec;




1;
