package DBR::Query;
use base 'DBR::Common';
use strict;
use Carp;
use DBR::Query::Part;
sub _params{ confess "Shouldn't get here" }
sub _reqparams{ confess "Shouldn't get here" }
use Scalar::Util 'blessed';

sub new {
      my( $package, %params ) = @_;

      $package ne __PACKAGE__ || croak "Can't create a query object directly, must create a subclass for the given query type";
      my $self = bless({},$package);

      $self->{instance} = $params{instance} || croak "instance is required";
      $self->{session}  = $params{session}  || croak "session is required";
      $self->{scope}    = $params{scope};
      $self->{splitfield} = $params{splitfield};

      my %req = map {$_ => 1} $self->_reqparams;
      for my $key ( $self->_params ){

	    if(  $params{$key} ){
		  $self->$key( $params{$key} );

	    }elsif($req{$key}){
		  croak "$key is required";
	    }
      }

      $self->validate() or croak "Object is not valid"; # HERE - not enough info as to why

      return $self;
}

sub tables{
      my $self   = shift;
      exists( $_[0] )  or return wantarray?( @$self->{tables} ) : $self->{tables} || undef;
      my @tables = $self->_arrayify(@_);

      scalar(@tables) || croak "must provide at least one table";

      my @tparts;
      my %aliasmap;
      foreach my $table (@tables){
	    croak('must specify table as a DBR::Config::Table object') unless ref($table) =~ /^DBR::Config::Table/; # Could also be ::Anon

	    my $name  = $table->name or confess 'failed to get table name';
	    my $alias = $table->alias;
	    $aliasmap{$alias} = $name if $alias;
      }

      $self->{tables}   = \@tables;
      $self->{aliasmap} = \%aliasmap;

      return $self;
}

sub check_table{
      my $self  = shift;
      my $alias = shift;

      return $self->{aliasmap}->{$alias} ? 1 : 0;
}

sub where{
      my $self = shift;
      exists( $_[0] )  or return $self->{where} || undef;
      my $part = shift || undef;

      !$part || ref($part) =~ /^DBR::Query::Part::(And|Or|Compare|Subquery|Join)$/ ||
	croak('param must be an AND/OR/COMPARE/SUBQUERY/JOIN object');

      $self->{where} = $part;

      return $self;
}

sub builder{
      my $self = shift;
      exists( $_[0] )  or return $self->{builder} || undef;
      my $builder = shift || undef;

      !$builder || ref($builder) eq 'DBR::Interface::Where' || croak('must specify a builder object');

      $self->{builder} = $builder;

      return $self;
}

sub limit{
  my $self = shift;
  exists( $_[0] ) or return $self->{limit} || undef;
  $self->{limit} = shift || undef;

  return $self;
}

sub offset{
  my $self = shift;
  exists( $_[0] ) or return $self->{offset} || undef;
  $self->{offset} = shift || undef;

  return $self;
}

sub _limit_clause {
    my $self = shift;
    my ($limit, $offset) = @{ $self }{ 'limit', 'offset' };

    if ($limit && $offset) {
        return "$offset, $limit";
    } elsif ($limit) {
        return "$limit";
    } elsif ($offset) {
        return "$offset, 999999999"; # hugenum :|
    } else {
        return "";
    }
}

sub lock{
  my $self = shift;
  exists( $_[0] ) or return $self->{lock} || undef;
  $self->{lock} = shift() ? 1 : 0;

  return $self;
}

sub quiet_error{
  my $self = shift;
  exists( $_[0] ) or return $self->{quiet_error} || undef;
  $self->{quiet_error} = shift() ? 1 : 0;

  return $self;
}

sub primary_table{ shift->{tables}[0] } # HERE HERE HERE - this is lame

# Copy the guts of this query into a query of a different type
# For instance: transpose a Select into an Update.
sub transpose{
      my $self   = shift;
      my $module = shift;

      my $class = __PACKAGE__ . '::' . $module;
      my %params;
      map { $params{ $_ } = $self->{$_} if $self->{$_} } (qw'instance session scope',$self->_params);
      
      return $class->new(
			 %params,
			 @_, # extra params
			) or croak "Failed to create new $class object";
}

sub child_query{
      my $self = shift;
      my $where = shift;

      my $builder = $self->{builder} ||= DBR::Interface::Where->new(
								    session       => $self->{session},
								    instance      => $self->{instance},
                                                                    primary_table => $self->primary_table,
								    tables        => $self->{tables},
								   );

      my $ident = $builder->digest( $where );

      return $self->{child_queries}{$ident} ||= $self->_new_child_query($where);
}

sub _new_child_query{
      my $self = shift;
      my $where = shift;

      #HERE - I don't think this is the correct place to do this
      my $qpart = $self->{builder}->build($where);

      my %child;

      # Copy everything over, including internal goodies # HERE HERE HERE - I'm uncertain if builder should be copied
      map { $child{$_} = $self->{$_} } (qw'instance session scope splitfield last_idx', $self->_params);

      $child{where} = $self->{where} ? DBR::Query::Part::And->new( $self->{where}, $qpart ) : $qpart;

      if($child{fields}){
          my $alias = $self->primary_table->alias;
          if($alias){
              map { $_->table_alias($alias) } @{ $child{fields} };
          }
      }
      my $class = blessed($self);
      return bless(\%child, $class); # not even calling new
}

sub instance { $_[0]{instance} }
sub _session { $_[0]{session} }
sub session  { $_[0]{session} }
sub scope    { $_[0]{scope} }

sub can_be_subquery { 0 }

sub validate{
      my $self = shift;

      return 0 unless $self->_validate_self; # make sure I'm sane

      # Now check my component objects
      if($self->{where}){
	    $self->{where}->validate( $self ) or croak "Invalid where clause";
      }

      return 1;
}

1;
