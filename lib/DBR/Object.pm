# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Object;

use strict;
use base 'DBR::Common';
use DBR::Query::ResultSet;
use DBR::Query::Part;
use DBR::Operators;

use Digest::MD5 qw(md5_base64);
my %SCOPES;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger => $params{logger},
		  dbrh    => $params{dbrh},
		  table  => $params{table},
		 };

      bless( $self, $package );

      return $self->_error('table object must be specified') unless ref($self->{table}) eq 'DBR::Config::Table';
      return $self->_error('dbrh object must be specified')   unless $self->{dbrh};

      return( $self );
}


sub where{
      my $self = shift;
      my %inwhere = @_;

      my $scope_id = $self->_getscope or return $self->_error('Failed to get calling scope');
      $self->_logDebug2("Scope ID is $scope_id");

      # Use caller information to determine selected fields
      my $table = $self->{table};
      my @and;
      foreach my $fieldname (keys %inwhere){

 	    my $field = $table->get_field( $fieldname ) or return $self->_error("invalid field $fieldname");

 	    my $value = $field->makevalue( $inwhere{ $fieldname } ) or return $self->_error("failed to build value object for $fieldname");

	    my $outfield = DBR::Query::Part::Compare->new(
							  field => $field,
							  value => $value
							 ) or return $self->_error('failed to create compare object');

	    push @and, $outfield;
      }

      my $outwhere = DBR::Query::Part::And->new(@and);

      my $query = DBR::Query->new(
				  logger => $self->{logger},
				  dbrh    => $self->{dbrh},
				  select => {
					     fields => scalar($table->fields)
					    },
				  tables => $table->name,
				  where  => $outwhere,
				 ) or return $self->_error('failed to create Query object');

      my $resultset = $query->execute() or return $self->_error('failed to execute');

      return $resultset;
}

#Fetch by Primary key
sub fetch{
      
}


sub _getscope{
      my $self = shift;

      my $offset = 1;

      my @parts;
      while($offset < 51){
	    my (undef,$file,$line) = caller($offset++);

	    if($file =~ /^\//){ # starts with Slash
		  $offset = 51; #everything is good
	    }else{
		  if ($file !~ /^\(eval/){ # If it's an eval, then we do another loop
			# Not an eval, just slap on the directory we are in and call it done
			$file = $ENV{'PWD'} . '/' . $file;
			$offset = 51;
		  }
	    }

	    push @parts, $file . '*' . $line;
      }

      my $ident = join('|',@parts);

      my $digest = md5_base64($ident);

      my $scope_id = $SCOPES{$digest}; # Check the cache!
      return $scope_id if $scope_id;

      my $dbrh = $self->{dbrh};

      my $table = $self->{table};
      my $instance = $table->conf_instance or return $self->_error('Failed to get conf instance');

      my $dbrh = $instance->connect or return $self->_error("Failed to connect to ${\$instance->name}");

      # If the insert fails, that means someone else has won the race condition, try try again
      my $try;
      while(++$try < 3){
	    #Yeahhh... using the old way for now, Don't you like absurd recursion? perhaps change this?
	    my $record = $dbrh->select(
				       -table => 'dbr_scopes',
				       -fields => 'scope_id',
				       -where => {digest => $digest},
				       -single => 1,
				      );

	    return $record->{scope_id} if $record;

	    my $scope_id = $dbrh->insert(
					 -table => 'dbr_scopes',
					 -fields => {
						     digest => $digest
						    },
					 -quiet => 1,
					);

	    return $scope_id if $scope_id;
      }

      return $self->_error('Something failed');
}
1;
