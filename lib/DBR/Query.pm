package DBR::Query;

use strict;
use base 'DBR::Common';
use DBR::Query::ResultSet;
use DBR::Operators;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		  table  => $params{table},
		  dbh    => $params{dbh},
		  sqlobj => $params{sql},
		 };

      bless( $self, $package );

      return $self->_error('table object must be specified') unless $self->{table};
      return $self->_error('dbh object must be specified')   unless $self->{dbh};
      return $self->_error('sql object must be specified')   unless $self->{sqlobj};

      return( $self );
}


sub where{
      my $self = shift;
      my %where = @_;

      # Use caller information to determine selected fields
      my ( $package, $filename, $line, $method) = caller(1);

      my $table = $self->{table};
      my %outwhere;
      foreach my $fieldname (keys %where){

 	    my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");

 	    $outwhere{ $field->name } = $field->makevalue( $where{ $fieldname } ) or return $self->_error("failed to build value object for $fieldname");

      }

      return $self->_error('failed to build select sql') unless
	my $sql = $self->{sqlobj}->buildSelect(
					       -table => $self->{table}->name,
					       -where => \%where,
					       -fields => 'order_id'
					      );

      $self->_logDebug($sql);

      my $sth = $self->{dbh}->prepare($sql) or return $self->_error('failed to prepare statement');

      my $resultset = DBR::Query::ResultSet->new(
						 logger => $self->{logger},
						 query  => $self,
						 sth    => $sth
						) or return $self->_error('failed to create resultset');
      return $resultset;
}

#Fetch by Primary key
sub fetch{
}

1;
