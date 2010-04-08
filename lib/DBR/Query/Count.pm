package DBR::Query::Part::Count;

use strict;
use base 'DBR::Query::Part';

sub new{
      my( $package ) = shift;
      return bless( [], $package );
}

sub children { return ()  };
sub sql      { 'count(*)' }
sub _validate_self{ 1 }

# # do not run this until the last possible moment, and then only once
# sub sql{
#       my $self = shift;

#       my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');
#       my $sql;
#       my $tables = join(',', map {$_->sql} @{$self->{tables}} );

#       if (    $self->[v_select] ){
# 	    $sql = "SELECT " . $self->[v_select]->sql($conn) . " FROM $tables";

#       }elsif( $self->[v_insert] ){
# 	    $sql = "INSERT INTO $tables " . $self->[v_insert]->sql($conn);

#       }elsif( $self->[v_update] ){
# 	    $sql = "UPDATE $tables SET "  . $self->[v_update]->sql($conn);

#       }elsif( $self->[v_delete] ){
# 	    $sql = "DELETE FROM $tables";

#       }

#       $sql .= ' WHERE ' . $self->[v_where]->sql($conn) if $self->[v_where];
#       $sql .= ' FOR UPDATE'                            if $self->[v_lock];
#       $sql .= ' LIMIT ' . $self->[v_limit]             if $self->[v_limit];

#       return $sql;
# }
