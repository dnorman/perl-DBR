package DBR::Interface::Where;

use strict;
use Carp;
use DBR::Query::Part;

sub new {
      my( $package ) = shift;
      my %params = @_;

      my $self = {};

      $self->{session}  = $params{session}       or croak "session is required";
      $self->{instance} = $params{instance}      or croak "instance is required";
      $self->{table}    = $params{primary_table} or croak "primary_table is required";

      return croak('primary_table object must be specified') unless ref($self->{table}) eq 'DBR::Config::Table';

      bless( $self, $package );

      $self->{tables} = [$self->{table}];
      $self->{aliascount} = 0;

      return( $self );
}

sub tables { shift->{tables} }

sub build{
      my $self = shift;
      my %params = @_;
      my $inwhere    = $params{input}   || croak "input is required";


      !(scalar(@$inwhere) % 2) or croak('Odd number of arguments in where parameters');

      my %grouping = (
		      table => $self->{table} # prime the pump
		     );


      my $ct;
      while(@$inwhere){ # Iterate over key/value pairs
	    my $next    = shift @$inwhere;

	    if( ref($next) eq 'DBR::Util::Operator' ){ # Kaboom! OR is very disruptive
		  my $op = $next->operator;
		  croak "Invalid operator '$op'" unless $op eq 'ormarker';


		  my @ors;
		  croak "Can't use 'OR' divider operator without something preceeding it" unless $ct; # did we actually get anything?

		  #Everything before me...
		  my $whereA = $self->_reljoin( \%grouping );
		  # OR
		  # The contents of the operator a OR (b) ... other stuff
		  my $whereB = $self->build( input => $next->value );

		  my $or = DBR::Query::Part::Or->new($whereA,$whereB) || confess('failed to create Or object');

		  # anything left?
		  if(@$inwhere){
			my $remainder = $self->build( input => $inwhere );
			return DBR::Query::Part::And->new($or,$remainder) || confess('failed to create And object');
		  }else{
			return $or;
		  }

	    }else{
		  my $rawval = shift @$inwhere;
		  $self->_process_comparison($next, $rawval, \%grouping);
	    }

	    $ct++;
      }

      my $where = $self->_reljoin( \%grouping ) or confess('_reljoin failed');

      return $where;
}
sub _process_comparison{
      my $self = shift;

      my $key = shift;
      my $rawval = shift;
      my $ref = shift;


      $key =~ /^\s+|\s+$/g; # trim junk
      my @parts = split(/\s*\.\s*/,$key); # Break down each key into parts

      my $tablect;

      my $cur_table = $self->{table}; # Start

      while ( my $part = shift @parts ){
	    my $last = (scalar(@parts) == 0)?1:0;

		  if($last){ # The last part should always be a field
			die('Sanity error. Duplicate field ' .$part ) if $ref->{fields}->{$part};

			my $field = $cur_table->get_field( $part ) or croak("invalid field $part");
			my $value = $field->makevalue( $rawval )   or croak("failed to build value object for $part");

			my $out = DBR::Query::Part::Compare->new( field => $field, value => $value ) or confess('failed to create compare object');
			$ref->{fields}->{$part} = $out;

		  }else{
			#test for relation?
			$ref = $ref->{kids}->{$part} ||= {}; # step deeper into the tree

			if( $ref->{been_here} ){ # Dejavu - merge any common paths together

			      $cur_table = $ref->{table};  # next!

			}else{

			      my $relation = $cur_table->get_relation($part) or croak("invalid relationship $part");
			      my $maptable = $relation->maptable             or confess("failed to get maptable");

			      # Any to_one relationship results in a join. we'll need some table aliases for later.
			      # Do them now so everything is in sync. I originally assigned the alias in _reljoin,
			      # but it didn't always alias the fields that needed to be aliased due to the order of execution.
			      if($relation->is_to_one){
				    croak ('No more than 25 tables allowed in a join') if $self->{aliascount} > 24;

				    $cur_table ->alias() || $cur_table ->alias( chr(97 + $self->{aliascount}++)  ); # might be doing this one again
				    $maptable  ->alias( chr(97 + $self->{aliascount}++)  );
			      }

			      $ref->{relation}  = $relation;
			      $ref->{prevtable} = $cur_table;
			      $ref->{table}     = $maptable;
			      $ref->{been_here} = 1;

			      $cur_table = $maptable; # next!
			}
		  }

	    };
}
sub _reljoin{
      my $self = shift;
      my $ref  = shift;
      my $tables = shift || $self->{tables}; # Allow override of table list for subqueries

      confess ('ref must be hash') unless ref($ref) eq 'HASH';

      my @and;

      if($ref->{kids}){
	    foreach my $key (keys %{$ref->{kids}}){
		  my $kid = $ref->{kids}->{ $key };
		  my $relation = $kid->{relation};

		  # it's important we use the same table objects to preserve aliases

		  my $table     = $kid->{table}      or confess("failed to get table");
		  my $prevtable = $kid->{prevtable}  or confess("failed to get prev_table");

		  my $field     = $relation->mapfield or confess('Failed to fetch field');
		  my $prevfield = $relation->field    or confess('Failed to fetch prevfield');

		  my $prevalias = $prevtable ->alias();
		  my $alias     = $table     ->alias();

		  $prevfield ->table_alias( $prevalias ) if $prevalias;
		  $field     ->table_alias( $alias     ) if $alias;

		  if ($relation->is_to_one) { # Do a join

			$prevalias or die('Sanity error: prevtable alias is required');
			$alias     or die('Sanity error: table alias is required');

			push @$tables, $table;

			my $where = $self->_reljoin( $kid ) or confess('_reljoin failed');
			push @and, $where;

			my $join = DBR::Query::Part::Join->new($field,$prevfield) or confess('failed to create join object');
			push @and, $join;

		  }else{ # if it's a to_many relationship, then subqery
			my @tables = $table;
			my $where = $self->_reljoin( $kid, \@tables ) or confess('_reljoin failed');

 			my $query = DBR::Query::Select->new(
							    instance => $self->{instance},
							    session  => $self->{session},
							    fields => [$field],
							    tables   => \@tables,
							    where    => $where,
							   ) or confess('failed to create query object');

 			my $subquery = DBR::Query::Part::Subquery->new($prevfield, $query) or confess ('failed to create subquery object');
			push @and, $subquery;
		  }

	    }
      }

      # It's important that fields are evaluated after all relationships are processed for this node
      if($ref->{fields}){
	    my $alias = $ref->{table}->alias;

	    foreach my $key (keys %{$ref->{fields}}){
		  my $compare = $ref->{fields}->{ $key };
		  $compare->field->table_alias( $alias ) if $alias;
		  push @and, $compare;
	    }
      }

      return $and[0] if @and == 1;
      return DBR::Query::Part::And->new(@and) || confess('failed to create And object');


}

1;
