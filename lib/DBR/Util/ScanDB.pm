# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Util::ScanDB;

use Data::Dumper;
use strict;
use base 'DBR::Common';
use DBR::Config::Field;

sub new {
      my( $package ) = shift;
      my %params = @_;
      my $self = {
		  logger   => $params{logger},
		  conf_instance => $params{conf_instance},
		  scan_instance => $params{scan_instance},
		 };

      bless( $self, $package );

      return $self->_error('logger object must be specified')   unless $self->{logger};
      return $self->_error('conf_instance object must be specified')   unless $self->{conf_instance};
      return $self->_error('scan_instance object must be specified')   unless $self->{scan_instance};

      $self->{schema_id} = $self->{scan_instance}->schema_id or
	return $self->_error('Cannot scan an instance that has no schema');

      return( $self );
}

sub scan{
      my $self = shift;

      my %params;
      my $tables = $self->scan_tables() || die "failed to scan tables";

      print STDERR Dumper($tables);

      foreach my $table (@{$tables}){
       	    my $fields = $self->scan_fields($table) or return $self->_error( "failed to describe table" );

	    $self->update_table($fields,$table) or return $self->_error("failed to update table");
      }

      return 1;
}


sub scan_tables{
      my $self = shift;
      my $dbh = $self->{scan_instance}->connect('dbh') || die "failed to connect to scanned db";

      return $self->_error('failed to prepare statement') unless
	my $sth = $dbh->table_info;

      my @tables;
      while (my $row = $sth->fetchrow_hashref()) {
	    my $name = $row->{TABLE_NAME} or return $self->_error('Table entry has no name!');

	    if($row->{TABLE_TYPE} eq 'TABLE'){
		  push @tables, $name;
	    }
      }

      $sth->finish();

      return \@tables;
}

sub scan_fields{
      my $self = shift;
      my $table = shift;

      my $dbh = $self->{scan_instance}->connect('dbh') || die "failed to connect to scanned db";

      return $self->_error('failed to prepare statement') unless
	my $sth = $dbh->column_info( undef, undef, $table, undef );

      my @rows;
      while (my $row = $sth->fetchrow_hashref()) {
	    push @rows, $row;
      }

      $sth->finish();

      return \@rows;
}

sub update_table{
      my $self   = shift;
      my $fields = shift;
      my $name   = shift;

      my $dbh = $self->{conf_instance}->connect || die "failed to connect to config db";

      return $self->_error('failed to select from dbr_tables') unless
 	my $tables = $dbh->select(
 				  -table  => 'dbr_tables',
 				  -fields => 'table_id schema_id name',
 				  -where  => {
 					      schema_id => ['d',$self->{schema_id}],
 					      name      => $name,
 					     }
 				 );

      my $table = $tables->[0];

      my $table_id;
      if($table){ # update
 	    $table_id = $table->{table_id};
      }else{
 	    return $self->_error('failed to insert into dbr_tables') unless
 	      $table_id = $dbh->insert(
 				       -table  => 'dbr_tables',
 				       -fields => {
 						   schema_id => ['d',$self->{schema_id}],
 						   name      => $name,
 						  }
 				      );
      }

      $self->update_fields($fields,$table_id) or return $self->_error('Failed to update fields');

      return 1;
}


sub update_fields{
      my $self = shift;
      my $fields = shift;
      my $table_id = shift;

      my $dbh = $self->{conf_instance}->connect || die "failed to connect to config db";

      return $self->_error('failed to select from dbr_fields') unless
 	my $records = $dbh->select(
				   -table  => 'dbr_fields',
				   -fields => 'field_id table_id name data_type is_nullable is_signed max_value',
				   -where  => {
					       table_id  => ['d',$table_id]
					      }
				  );

      my %fieldmap;
      map {$fieldmap{$_->{name}} = $_} @{$records};

      foreach my $field (@{$fields}) {
 	    my $name = $field->{'COLUMN_NAME'} or return $self->_error('No COLUMN_NAME is present');
	    my $type = $field->{'TYPE_NAME'}   or return $self->_error('No TYPE_NAME is present'  );
	    my $size = $field->{'COLUMN_SIZE'};

	    my $nullable = $field->{'NULLABLE'};
	    return $self->_error('No NULLABLE is present'  ) unless defined($nullable);

	    my $pkey = $field->{'mysql_is_pri_key'};
	    my $extra = $field->{'mysql_type_name'};

	    my $is_signed = 0;
	    if(defined $extra){
		  $is_signed = ($extra =~ / unsigned/i)?0:1
	    }

	    my $typeid = DBR::Config::Field->get_type_id($type) or $self->_error( "Invalid type $type" );

 	    my $record = $fieldmap{$name};

 	    my $ref = {
 		       is_nullable => ['d',  $nullable ? 1:0 ],
 		       is_signed   => ['d',  $is_signed      ],
 		       data_type   => ['d',  $typeid         ],
 		       max_value   => ['d',  $size || 0      ],
 		      };

	    if(defined($pkey)){
		  $ref->{is_pkey} = ['d',  $pkey ? 1:0  ],
	    }

 	    if ($record) {	# update
 		  return $self->_error('failed to insert into dbr_tables') unless
 		    $dbh->update(
 				 -table  => 'dbr_fields',
 				 -fields => $ref,
 				 -where  => { field_id => ['d',$record->{field_id}] },
 				);
 	    } else {
 		  $ref->{name}     = $name;
 		  $ref->{table_id} = ['d', $table_id ];

 		  return $self->_error('failed to insert into dbr_tables') unless
 		    my $field_id = $dbh->insert(
 						-table  => 'dbr_fields',
 						-fields => $ref,
 					       );
 	    }

 	    delete $fieldmap{$name};

      }

      foreach my $name (keys %fieldmap) {
 	    my $record = $fieldmap{$name};

 	    return $self->_error('failed to delete from dbr_tables') unless
 	      $dbh->delete(
 			   -table  => 'dbr_fields',
 			   -where  => { field_id => ['d',$record->{field_id}] },
 			  );
      }

      return 1;
}

1;
