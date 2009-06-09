package DBR::Util::Connection::Pg;

use strict;
use base 'DBR::Util::Connection';

die "This module doesn't work yet";

sub _prepareSequence{
      my $self = shift;
      my $call = shift;

      my ($seqname,$fieldname) = $self->_getSequenceName();
      return $self->_error('failed to get sequence name and field name') unless ($seqname && $fieldname);
      my ($seqnum) = $self->{dbh}->selectrow_array("SELECT nextval('$seqname')");
      return $self->_error('failed to get sequence value') unless $seqnum;

      $call->{tmp}->{sequenceval} = $seqnum;
      $call->{fields}->{$fieldname} = ['d',$seqnum];

      return 1;
}
sub _getSequenceValue{
      my $self = shift;
      my $call = shift;

      return $call->{tmp}->{sequenceval};
}

sub _getSequenceName{
    my $self = shift;
    my $call = shift;

    my $seq = $call->{params}->{-sequence};

    # explicitly specify sequence name and fieldname (in that order)
    if(ref($seq) eq 'ARRAY'){
	if(scalar(@{$seq}) == 2){
	    return @{$seq};
	}
	return undef;
    }

    # figure out the sequence name based on the field name specified
    return $self->_error('Bad -sequence parameter') unless $seq =~ /^[A-Za-z0-9_-]*$/;

    my $seqname = $call->{params}->{-table} . '_' . $call->{params}->{-sequence} . '_seq';

    return ($seqname,$call->{params}->{-sequence});
}

1;
