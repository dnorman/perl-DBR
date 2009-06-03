package DBR::Query::RecHelper;

use strict;
use base 'DBR::Common';
use DBR::Query::Part;
use DBR::Query::ResultSet::Empty;
use Carp;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger   => $params{logger},
		  instance => $params{instance},
		  tablemap => $params{tablemap},
		  flookup  => $params{flookup},
		  pkmap    => $params{pkmap},
		  scope    => $params{scope},
		  lastidx  => $params{lastidx},
		  rowcache => $params{rowcache},
		 };

      bless( $self, $package ); # BS object

      $self->{logger}   or return $self->_error('logger is required');
      $self->{instance} or return $self->_error('instance is required');
      $self->{scope}    or return $self->_error('scope is required');

      $self->{tablemap} or return $self->_error('tablemap is required');
      $self->{pkmap}    or return $self->_error('pkmap is required');           # X
      $self->{flookup}  or return $self->_error('flookup is required');         # X
      defined($self->{lastidx}) or return $self->_error('lastidx is required');
      $self->{rowcache} or return $self->_error('rowcache is required');

      return $self;
}

sub set{
      my $self = shift;
      my $record = shift;
      my %params = @_;

      my %sets;
      foreach my $fieldname (keys %params){
	    my $field = $self->{flookup}->{$fieldname} or return $self->_error("$fieldname is not a valid field");
	    $field->is_readonly && return $self->_error("Field $fieldname is readonly");

	    my $setvalue = $field->makevalue($params{$fieldname}) or return $self->_error('failed to create setvalue object');
	    $setvalue->count == 1 or return $self->_error("Field ${\$field->name} allows only a single value");

	    my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');

	    push @{$sets{$field->table_id}}, $setobj;
      }
      my $ct = scalar(keys %sets);


      my $dbrh;
      if($ct > 1){
	    # create a new DBRH here to ensure proper transactional handling
	    $dbrh = $self->{instance}->connect or return $self->_error('failed to connect');
	    $dbrh->begin;
      }

      foreach my $table_id (keys %sets){
	    $self->_set($record, $table_id, $sets{$table_id}) or return $self->_error('failed to set');
      }

      $dbrh->commit if $ct > 1;

      return 1;
}

# set a field REGARDLESS of whether it was prefetched or not
sub setfield{
      my $self = shift;
      my $record = shift;
      my $field = shift;
      my $value = shift;

      my $setvalue = $field->makevalue($value) or return $self->_error('failed to create value object');
      $setvalue->count == 1 or return $self->_error("Value of ${\$field->name} must have only a single value");

      my $setobj   = DBR::Query::Part::Set->new( $field, $setvalue ) or return $self->_error('failed to create set object');

      return $self->_set($record, $field->table_id, [$setobj]);
}

sub _set{
      my $self = shift;
      my $record = shift;
      my $table_id = shift;
      my $sets = shift;

      my ($outwhere,$tablename) = $self->_pk_where($record,$table_id) or return $self->_error('failed to create where tree');

       my $query = DBR::Query->new(
				   logger => $self->{logger},
				   instance => $self->{instance},
				   tables => $tablename,
				   where  => $outwhere,
				   update => { set => $sets }
				  ) or return $self->_error('failed to create Query object');

      my $rv = $query->execute() or return $self->_error('failed to execute');

      foreach my $set (@$sets){
	    $self->_setlocalval($record, $set->field, $set->value->raw->[0]) or
	      return $self->_error('failed to _setlocalval');
      }

      return $rv;
}

# Fetch a field ONLY if it was not prefetched
sub getfield{
       my $self = shift;
       my $record = shift;
       my $field = shift;

       # Check to see if we've previously been assigned an index. if so, see if our record already has it fetched
       # This could happen if the field was not fetched in the master query, but was already fetched with getfield
       my $idx = $field->index;
       return $record->[$idx] if defined($idx) && exists($record->[$idx]);

       $self->{scope}->addfield($field) or return $self->_error('Failed to add field to scope');

       my ($outwhere,$tablename)  = $self->_pk_where($record,$field->table_id) or return $self->_error('failed to create where tree');

       # Because we are doing a new select, which will set the indexes on
       # its fields, we must clone the field provided by the original query
       my $newfield = $field->clone;

       my $query = DBR::Query->new(
				   logger   => $self->{logger},
				   instance => $self->{instance},
				   tables   => $tablename,
				   where    => $outwhere,
				   select   => { fields => [ $newfield ] } # use the new cloned field
				  ) or return $self->_error('failed to create Query object');

       my $sth = $query->prepare or return $self->_error('failed to execute');

       $sth->execute() or return $self->_error('Failed to execute sth');
       my $row  = $sth->fetchrow_arrayref() or return $self->_error('Failed to fetchrow');

       my $val = $row->[ $newfield->index ];

       $self->_setlocalval($record,$field,$val) or return $self->_error('failed to _setlocalval');

       return $val;
}

sub getrelation{
      my $self = shift;
      my $record = shift;
      my $relation = shift;
      my $field  = shift;

      my $ridx = $relation->index;
      # Check to see if this record has a cached version of the resultset
      return $record->[$ridx] if defined($ridx) && exists($record->[$ridx]); # skip the rest if we have that


      my $fidx = $field->index();
      my $val;
      my %allvals; # For uniq-ing

      if( defined($fidx) && exists($record->[$fidx]) ){
	    $val = $record->[ $fidx ]; # My value
	    map { $allvals{ $_->[ $fidx ] } = 1 } @${$self->{rowcache}}; # look forward in the rowcache and add those too
      }else{
	    $val = $self->getfield($record,$field) or return $self->_error("failed to fetch the value of ${\ $field->name }");
	    $fidx ||= $field->index;
	    return $self->_error('field object STILL does not have an index') unless defined($fidx);
      }

      $allvals{$val} = 1;
      delete $allvals{undef}; # equivalent to grep { $_ }

      my $maptable = $relation->maptable or return $self->_error('Failed to fetch maptable');
      my $mapfield = $relation->mapfield or return $self->_error('Failed to fetch mapfield');

      my $value = $mapfield->makevalue( [ keys %allvals ] ) or return $self->_error('failed to create value object');
      my $outwhere = DBR::Query::Part::Compare->new( field => $mapfield, value => $value ) or return $self->_error('failed to create compare object');

      #HERER HERE HERE - scope probably needs an offset here
      my $scope = DBR::Config::Scope->new(
					  logger        => $self->{logger},
					  conf_instance => $maptable->conf_instance,
					  extra_ident   => $maptable->name,
					 ) or return $self->_error('Failed to get calling scope');

      my $pk        = $maptable->primary_key or return $self->_error('Failed to fetch primary key');
      my $prefields = $scope->fields or return $self->_error('Failed to determine fields to retrieve');

      my %uniq;
      my @fields = grep { !$uniq{ $_->field_id }++ } ($mapfield, @$pk, @$prefields );

      my $query = DBR::Query->new(
				  logger   => $self->{logger},
				  instance => $self->{instance},
				  tables   => $maptable->name,
				  where    => $outwhere,
				  select   => { fields => \@fields },
				  scope    => $scope,
				 ) or return $self->_error('failed to create Query object');

      my $resultset = $query->resultset or return $self->_error('failed to retrieve resultset');

      # HERE HERE HERE ########################################################################
      # This is a >>> VERY <<< lazy way to solve the problem, but....
      #
      # Just straight up save a copy of the resultset into this helper object
      # Don't do anything with it... just save it so it doesn't go out of scope
      # This will prevent it's generated class from poofing out of existance because
      # the contained recmaker object will stay in scope by association.
      # >> Theoretically << when MY outer resultset goes out of scope, it's recmaker object
      # will go out of scope, which will make ME go out of scope, and then cascade to
      # these resultsets, and so on, ad infinitum. Ideally the generated class wouldn't poof until
      # the last record went out of scope. Presumably this would be done by including the recmaker
      # or rechelper object in each record object itself, not the generated class.
      # ...but much like a junkie stealing your TV, I did it for the speeeeed %-)

      push @{ $self->{EVIL_MEMLEAK} }, $resultset;

      ########################################################################################
      ########################################################################################


      my $to1 = $relation->is_to_one;

      if(scalar(keys %allvals) > 1){
	    my $resultmap;
	    my $myresult;
	    if($to1){
		  $resultmap = $resultset->lookup_hash(  $mapfield->name ) or return $self->_error('failed to split resultset');

		  $myresult = $resultmap->{$val};
	    }else{
		  $resultmap = $resultset->split( $mapfield ) or return $self->_error('failed to split resultset');

		  $myresult = $resultmap->{$val} || DBR::Query::ResultSet::Empty->new() # Empty resultset
		    or return $self->_error('failed to create ResultSet::Empty object');
	    }

	    $self->_setlocalval($record,$relation,$myresult) or return $self->_error('failed to _setlocalval');

	    # look forward in the rowcache and assign the resultsets for whatever we find
	    foreach my $row (@${$self->{rowcache}}) {

		  my $rs = $resultmap->{ $row->[$fidx] } || DBR::Query::ResultSet::Empty->new() # Empty resultset
			or return $self->_error('failed to create ResultSet::Empty object');

		  $self->_setlocalval($row,$relation,$rs) or return $self->_error('failed to _setlocalval');
	    }

	    return $myresult;

      }else{
	    my $result = $resultset;
	    if($to1){
		  $result = $resultset->next;
	    }

	    $self->_setlocalval($record,$relation,$result) or return $self->_error('failed to _setlocalval');

	    return $result;
      }
}

sub _pk_where{
      my $self = shift;
      my $record = shift;
      my $table_id = shift;

      my $table = $self->{tablemap}->{ $table_id } || return $self->_error('Missing table for table_id ' . $table_id );
      my $pk    = $self->{pkmap}->{ $table_id }    || return $self->_error('Missing primary key');

      my @and;
      foreach my $part (@{ $pk }){
	    my $value = $part->makevalue( $record->[ $part->index ] ) or return $self->_error('failed to create value object');
	    my $outfield = DBR::Query::Part::Compare->new( field => $part, value => $value ) or return $self->_error('failed to create compare object');

	    push @and, $outfield;
      }


      return (DBR::Query::Part::And->new(@and), $table->name);
}

sub _setlocalval{
      my $self   = shift;
      my $record = shift;
      my $field  = shift; # Could also be a relationship
      my $val    = shift;

      my $idx = $field->index;
      # update the field object to give it an index if necessary
      if(!defined $idx){ #Could be 0
	    $idx = ++$self->{lastidx};
	    $field->index($idx); # so we'll have it for next time this gets accessed
      }

      # Update this record to reflect the new value
      $record->[$idx] = $val;

      return 1;
}

1;
