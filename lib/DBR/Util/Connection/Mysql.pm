package DBR::Util::Connection::Mysql;

use strict;
use base 'DBR::Util::Connection';


sub getSequenceValue{
      my $self = shift;
      my $call = shift;

      my ($insert_id)  = $self->{dbh}->selectrow_array('select last_insert_id()');
      return $insert_id;

}

1;
