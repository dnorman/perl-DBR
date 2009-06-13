# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Interface::Object;

use strict;
use base 'DBR::Common';
use DBR::Query::Part;
use DBR::Config::Scope;


sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  session => $params{session},
		  instance   => $params{instance},
		  table  => $params{table},
		 };

      bless( $self, $package );

      return $self->_error('table object must be specified') unless ref($self->{table}) eq 'DBR::Config::Table';
      return $self->_error('instance object must be specified')   unless $self->{instance};

      return( $self );
}

sub all{
      my $self = shift;
      my %inwhere = @_;

      my $table = $self->{table};
      my $scope = DBR::Config::Scope->new(
					  session        => $self->{session},
					  conf_instance => $table->conf_instance,
					  extra_ident   => $table->name,
					 ) or return $self->_error('Failed to get calling scope');

      my $pk = $table->primary_key or return $self->_error('Failed to fetch primary key');
      my $prefields = $scope->fields or return $self->_error('Failed to determine fields to retrieve');

      my %uniq;
      my @fields = grep { !$uniq{ $_->field_id }++ } (@$pk, @$prefields);

      my $query = DBR::Query->new(
				  session => $self->{session},
				  instance   => $self->{instance},
				  select => {
					     fields => \@fields
					    },
				  tables => $table,
				  scope  => $scope,
				 ) or return $self->_error('failed to create Query object');

      my $resultset = $query->resultset or return $self->_error('failed to get resultset');

      return $resultset;
}

sub where{
      my $self = shift;
      my %inwhere = @_;

      my $table = $self->{table};
      my $scope = DBR::Config::Scope->new(
					  session        => $self->{session},
					  conf_instance => $table->conf_instance,
					  extra_ident   => $table->name,
					 ) or return $self->_error('Failed to get calling scope');



      my $pk = $table->primary_key or return $self->_error('Failed to fetch primary key');
      my $prefields = $scope->fields or return $self->_error('Failed to determine fields to retrieve');

      my %uniq;
      my @fields = grep { !$uniq{ $_->field_id }++ } (@$pk, @$prefields);

      my @tables = ($table);
      my $where = $self->_buildwhere(\%inwhere,\@tables) or return $self->_error('Failed to generate where');

      my $alias = $table->alias;
      if($alias){
	    map { $_->table_alias($alias) } @fields;
      }

      my $query = DBR::Query->new(
				  session => $self->{session},
				  instance   => $self->{instance},
				  select => {
					     fields => \@fields
					    },
				  tables => \@tables,
				  where  => $where,
				  scope  => $scope,
				 ) or return $self->_error('failed to create Query object');

      my $resultset = $query->resultset or return $self->_error('failed to get resultset');

      return $resultset;
}


sub _buildwhere{
      my $self = shift;
      my $inwhere = shift;
      my $tables_ref = shift;
      my $table = $self->{table};

      my %grouping = (
		      table => $table # prime the pump
		     );
      foreach my $key (keys %$inwhere){
	    my $rawval = $inwhere->{ $key };

	    $key =~ /^\s+|\s+$/g; # trim junk

	    my $outpart;

	    my @parts = split(/\s*\.\s*/,$key);
	    my $ref = \%grouping;
	    my $tablect;

	    my $cur_table = $table;
	    while ( my $part = shift @parts ){
		  my $last = (scalar(@parts) == 0)?1:0;

		  if($last){
			return $self->_error('Sanity error. Duplicate field ' .$part ) if $ref->{fields}->{$part};

			my $field = $cur_table->get_field( $part ) or return $self->_error("invalid field $part");
			my $value = $field->makevalue( $rawval ) or return $self->_error("failed to build value object for $part");

			my $out = DBR::Query::Part::Compare->new( field => $field, value => $value ) or return $self->_error('failed to create compare object');
			$ref->{fields}->{$part} = $out;

		  }else{
			#test for relation?
			$ref = $ref->{kids}->{$part} ||= {};

			if($ref->{maptable}){ # Dejavu - merge any common paths together

			      $cur_table = $ref->{maptable};  # next!

			}else{

			      my $relation = $cur_table->get_relation($part) or return $self->_error("invalid relationship $part");
			      my $maptable = $relation->maptable             or return $self->_error("failed to get maptable");

			      $ref->{relation} = $relation;
			      $ref->{table}    = $cur_table;
			      $ref->{maptable} = $maptable;

			      $cur_table = $maptable; # next!
			}
		  }

	    };
      }

      my $aliascount = 0;
      my $where = $self->_reljoin(\%grouping, $tables_ref, \$aliascount) or return $self->_error('_reljoin failed');

      return $where;
}

sub _reljoin{
      my $self = shift;
      my $ref  = shift;
      my $tables_ref = shift;
      my $aliascount = shift;

      return $self->_error('ref must be hash') unless ref($ref) eq 'HASH';

      my @and;

      if($ref->{fields}){
	    my $alias = $ref->{table}->alias;

	    foreach my $key (keys %{$ref->{fields}}){
		  my $compare = $ref->{fields}->{ $key };
		  $compare->field->table_alias( $alias ) if $alias;
		  push @and, $compare;
	    }
      }

      if($ref->{kids}){
	    foreach my $key (keys %{$ref->{kids}}){
		  my $kid = $ref->{kids}->{ $key };
		  my $relation = $kid->{relation};
		  my ($alias, $mapalias);

		  # it's important we use the same table objects
		  my $table     = $kid->{table}       or return $self->_error("failed to get table");
		  my $maptable  = $kid->{maptable}    or return $self->_error("failed to get maptable");

		  my $field     = $relation->mapfield or return $self->_error('Failed to fetch field');
		  my $mapfield  = $relation->mapfield or return $self->_error('Failed to fetch mapfield');

		  if ($relation->is_to_one) {
			return $self->_error('No more than 25 tables allowed in a join') if $$aliascount > 24;

			$alias    = $table    ->alias() || $table    ->alias( chr(97 + $$aliascount++)  );
			$mapalias = $maptable ->alias() || $maptable ->alias( chr(97 + $$aliascount++)  );
			push @$tables_ref, $maptable;

			$field    ->table_alias( $alias    );
			$mapfield ->table_alias( $mapalias );
		  }

		  my $where = $self->_reljoin($kid, $aliascount,$mapalias) or return $self->_error('_reljoin failed');

		  if ($relation->is_to_one) {
			push @and, $where;

			my $join = DBR::Query::Part::Join->new($field,$mapfield) or return $self->_error('failed to create join object');
			push @and, $join;

		  } else {
 			my $query = DBR::Query->new(
 						    instance => $self->{instance},
 						    session  => $self->{session},
 						    select   => { fields => [$mapfield] },
 						    tables   => $maptable,
 						    where    => $where,
 						   ) or return $self->_error('failed to create query object');

 			my $subquery = DBR::Query::Part::Subquery->new($field, $query) or return $self->_error('failed to create subquery object');
			push @and, $subquery;
		  }

	    }
      }

      return $and[0] if @and == 1;
      return DBR::Query::Part::And->new(@and) || $self->_error('failed to create And object');


}

sub insert {
      my $self = shift;
      my %fields = @_;

      my $table = $self->{table};
      my @sets;
      foreach my $fieldname (keys %fields){

 	    my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");
 	    my $value = $field->makevalue( $fields{ $fieldname } ) or return $self->_error("failed to build value object for $fieldname");

	    my $set = DBR::Query::Part::Set->new($field,$value) or return $self->_error('failed to create set object');
	    push @sets, $set;
      }


      my $query = DBR::Query->new(
				  instance   => $self->{instance},
				  session => $self->{session},
				  insert => {
					     set => \@sets,
					    },
				  tables => $table,
				 ) or return $self->_error('failed to create query object');

      return $query->execute();

      # HERE HERE HERE - consider changing behavior. Use wantarray to determine if we are being executed in a void context or not ( wantarray == undef )
}


#Fetch by Primary key
sub get{
      my $self = shift;
      my $pkval = shift;

      my $table = $self->{table};
      my $pk = $table->primary_key or return $self->_error('Failed to fetch primary key');
      scalar(@$pk) == 1 or return $self->_error('the get method can only be used with a single field pkey');
      my $field = $pk->[0];

      my $scope = DBR::Config::Scope->new(
					  session        => $self->{session},
					  conf_instance => $table->conf_instance
					 ) or return $self->_error('Failed to get calling scope');

      my $prefields = $scope->fields or return $self->_error('Failed to determine fields to retrieve');

      my %uniq;
      my @fields = grep { !$uniq{ $_->field_id }++ } (@$pk, @$prefields);

      my $value = $field->makevalue( $pkval ) or return $self->_error("failed to build value object for ${\$field->name}");

      my $outwhere = DBR::Query::Part::Compare->new( field => $field, value => $value ) or return $self->_error('failed to create compare object');

      my $query = DBR::Query->new(
				  session => $self->{session},
				  instance => $self->{instance},
				  select => { fields => \@fields },
				  tables => $table,
				  where  => $outwhere,
				  scope  => $scope,
				 ) or return $self->_error('failed to create Query object');

      my $resultset = $query->resultset or return $self->_error('failed to get resultset');

      return $resultset;

}

1;



sub enum{
      my $self = shift;
      my $fieldname = shift;

      my $table = $self->{table};
      my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");

      my $trans = $field->translator or return $self->_error("Field '$fieldname' has no translator");
      $trans->module eq 'Enum' or return $self->_error("Field '$fieldname' is not an enum");

      my $opts = $trans->options or return $self->_error('Failed to get opts');

      return wantarray?@{$opts}:$opts;
}


sub parse{
      my $self = shift;
      my $fieldname = shift;
      my $value = shift;

      my $table = $self->{table};
      my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");
      my $trans = $field->translator or return $self->_error("Field '$fieldname' has no translator");

      return $trans->parse( $value ) || return $self->_error("Invalid value '$value' for " . $field->name);

}
