package DBR::Enum;

use strict;
use base 'DBR::Common';

sub new {
  my( $package ) = shift;
  my %params = @_;
  my $self = {
	      logger => $params{logger},
	      dbh    => $params{dbh},
	     };

  bless( $self, $package );

  return $self->_error('dbh object must be specified')   unless $self->{dbh};

  return( $self );
}


sub _enum {
      my $self = shift;
      my $context = shift;
      my $field = shift;
      my $flag = shift;

      return $self->_error('must pass in context') unless $context;
      return $self->_error('must pass in field') unless $field;


      return $self->_error('_enumlist failed') unless
	my $enums = $self->_enumlist($context,$field);

      my $lookup = {};
      if($flag eq 'text'){
	    map {  $lookup->{$_->{value}} = $_->{name}  } @{$enums};
      }elsif($flag eq 'reverse'){
	    map {  $lookup->{$_->{value}} = $_->{handle}  } @{$enums};
      }else{
	    map {  $lookup->{$_->{handle}} = $_->{value}  } @{$enums};
      }

      bless $lookup, 'ESRPCommon::EnumHandler';
      return $lookup;
}


sub _enumlist {
      my $self = shift;
      my $context = shift;
      my $field = shift;

      return $self->_error('must pass in context') unless $context;
      return $self->_error('must pass in field') unless $field;

      $ENUM ||= {};
      $ENUM->{list} ||= {};

      my $retlist;
      if($ENUM->{list} && $ENUM->{timestamp} > ($self->_time() - 1800)) {

	    $retlist = $ENUM->{list};

      } else {

	    return $self->_error('failed to connect to esrp_main') unless
	      my $dbh = $self->{dbr}->connect('esrp_main','query');

	    return $self->_error('failed to select from esrp_enum') unless
	      my $enums = $dbh->select(
				       -table => 'esrp_enum',
				       -fields => 'context field handle name val sortval',
				      );

	    my $enumlist = {};
	    map {   push @{  $enumlist->{$_->{context}}->{$_->{field}}  },  { handle => $_->{handle}, value => $_->{val}, name => $_->{name}, sortval => $_->{sortval}}   } @{$enums};

	    $ENUM->{list} = $enumlist;
	    $ENUM->{timestamp} = $self->_time();

	    $retlist = $ENUM->{list};

      }

      return clone($retlist->{$context}->{$field});
}


1;
