package DBR::Driver::Mysql;

use strict;
use base 'DBR::Driver';


sub _getSequenceValue{
      my $self = shift;
      my $call = shift;

      my ($insert_id)  = $self->{dbh}->selectrow_array('select last_insert_id()');
      return $insert_id;

      return ;
}

1;
