package DBR::Enum::Custom;

use strict;
use base 'DBR::Enum';

sub where{
      my $self = shift;
      my %where = shift;

      # Use caller information to determine selected fields
      my ( $package, $filename, $line, $method) = caller(1);

      my $table = $self->{table};
      my %outwhere;
      foreach my $fieldname (keys %where){
	    my $value = $fields{ $fieldname };

	    my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");

	    $outwhere{ $field->name } = $field->buildwhere($value) or return $self->_error("failed to build fieldpart for $fieldname");

      }

      my $result = $self->{dbh}->select(
					-table => $table->name,
					-fields => $getfields,
					-where => \%outwhere
				       );

      return $result;
}

1;
