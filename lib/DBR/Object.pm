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

      # Use caller information to determine selected fields
      my @caller = caller(0);my @caller1 = caller(1);
      use Data::Dumper;
      print STDERR Dumper(\@caller,\@caller1);


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

use Digest::MD5 qw(md5_base64);


sub test {
      my $self = shift;
      return $self->_caller;

}

sub _caller{
      my $offset = 1;

      my @parts;
      while($offset){
	    my (undef,$file,$line) = caller($offset++);

	    if($file =~ /^\//){ # starts with Slash
		  $offset = 0; #everything is good
	    }else{
		  if ($file !~ /^\(eval/){ # If it's an eval, then we do another loop
			# Not an eval, just slap on the directory we are in and call it done
			$file = $ENV{'PWD'} . '/' . $file;
			$offset = 0;
		  }
	    }

	    push @parts, $file . '*' . $line;
      }

      my $ident = join('|',@parts);

      return $ident;
      #return md5_base64($ident);

}
1;
