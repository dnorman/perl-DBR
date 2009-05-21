package DBR::Query::RecMaker;

use strict;
use base 'DBR::Common';
use Symbol qw( qualify_to_ref delete_package);
use DBR::Query::RecHelper;
use DBR::Query::Part;

#IDPOOL is a revolving door of package ids... we have to reuse package names otherwise we get a nasty memory leak
my @IDPOOL = (1..15); # Prime the ID pool with multiple IDs just to reduce the risk of a package getting used when it shouldn't
my $BASECLASS = 'DBR::_R';
my $classidx = 1; #overflow

#%REFCOUNT;

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
      $self->{dbrh} or return $self->_error('dbrh object must be specified');

      $self->{classidx} = ++$classidx; # (shift @IDPOOL) || ++$classidx;
      print STDERR "PACKAGEID: $self->{classidx}\n";

      $self->_prep or return $self->_error('prep failed');

      return $self;
}

sub class { $_[0]->{recordclass} }

sub _prep{
      my $self = shift;

      my $class = $BASECLASS . $self->{classidx};
      $self->{recordclass} = $class;

      my $fields = $self->{query}->fields or return $self->_error('Failed to get query fields');
      $fields = [ @$fields ]; #Shallow clone

      my @table_ids;
      # It's important that we preserve the specific field objects from the query. They have payloads that new ones do not.
      foreach my $field (@$fields){
	    my $field_id = $field->field_id or next; # Anon fields have no field_id
	    my $table_id = $field->table_id;
	    $self->{fieldmap}->{ $field_id } = $field;

	    push @table_ids, $table_id;
      }

      my %tablemap;
      my %pkmap;
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

	    $tablemap{$table_id} = $table;
	    $pkmap{$table_id}    = \@pk;

      }


      my $helper = DBR::Query::RecHelper->new(
					      logger   => $self->{logger},
					      dbrh     => $self->{dbrh},
					      tablemap => \%tablemap,
					      pkmap    => \%pkmap,
					      scope    => $self->{scope}
					     ) or return $self->_error('Failed to create RecHelper object');

      my $mode = 'rw';
      foreach my $field (@$fields){

	    my $sub = $self->_mk_method(
					mode  => $mode,
					index => $field->index,
					field => $field,
					helper => $helper,
				       ) or return $self->_error('Failed to create method');

	    my $method = $field->name;
	    #push @{$self->{methods}||=[]}, $method;

	    #print STDERR "$class\:\:$method\n";
	    my $symbol = qualify_to_ref( "$class\:\:$method" );
	    *$symbol = $sub;
      }

     # my $destroy =  qualify_to_ref( "$class\:\:DESTROY" );
     # *destroy = eval 'sub {}'

      return 1;
}

sub _mk_method{
      my $self = shift;
      my %params = @_;

      my $mode = $params{mode} or return $self->_error('Mode is required');
      my $helper = $params{helper} or return $self->_error('helper is required');

      my $field = $params{field};

      my $obj      = '$_[0]';
      my $record   = $obj . '[0]';
      my $setvalue = '$_[1]';
      my $value;

      my $idx = $params{index};
      if(defined $idx){ #did we actually fetch this?
	    $value = $record . '[' . $idx . ']';
      }else{
	    $value = "\$h->get( $obj, \$f )";
      }

      my $code;
      my $trans;
      if($mode eq 'rw' && $field){
	    if ($trans = $field->translator){
		  $value = "\$t->forward($value)";
	    }

	    $code = "   exists( $setvalue ) ? \$h->set( $obj, \$f, $setvalue ) : $value   ";
      }elsif($mode eq 'ro'){
	    $code = "   $value   ";
      }
      $code = "sub {$code}";
      $self->_logDebug2($code);

      my $ref = _eval_method($helper,$field,$trans,$code) or $self->_error('Failed to eval method' . $@);
      return $ref;
}

#Seperate method for scope cleanliness
sub _eval_method{
      my $h = shift;
      my $f = shift;
      my $t = shift;

      return eval shift;
}


sub DESTROY{ # clean up the temporary object from the symbol table
      my $self = shift;
      $self->_logDebug2('Destroy');
      my $class = $self->{recordclass};

      print STDERR "DESTROY $class, $self->{classidx}\n";
      Symbol::delete_package($class);

      #Unfortunately we have to reuse the package names, otherwise we get memory leaks.
      #Yes, even though we are supposedly deleting the package
     # push @IDPOOL, $self->{classidx};

#       print STDERR "\n\nAFTER ($class)\n";
#       foreach my $entry ( keys %DBR::Query:: )
# 	{
# 	      print STDERR "$entry\n";
# 	}
      
#       print STDERR "\n\nAFTER2 ($class)\n";
#       foreach my $entry ( keys %DBR::Query::Rec1:: )
# 	{
# 	      print STDERR "$entry\n";
# 	}
}

1;



1;
