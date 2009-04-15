#!/usr/bin/perl

use lib '/dj/tools/apollo-utils/lib'; # fix this

use ApolloUtils::Logger;
use ApolloUtils::DBR;
use strict;


my $logger = new ApolloUtils::Logger(-logpath => '/dj/logs/dbr_test.log', -logLevel => 'debug3');
my $dbr = new ApolloUtils::DBR(
			       -logger => $logger,
			       -conf   => '/dj/data/DBR.conf',
			      );

my $scandb = $ARGV[0];

my $db = 'dbrconf';
my $schema_id = 1;

my $tables = scan_tables($dbr,$dbr) || die "failed to scan tables";

#use Data::Dumper;
#print STDERR Dumper($tables);

foreach my $table (@{$tables}){
      my $desc = desc_table($dbr,$dbr,$table) || die "failed to describe table";

      update_table($dbr,$dbr,$desc,$table)|| die "failed to update table" ;

}


sub scan_tables{
      my $self = shift;
      my $dbr = shift;

      my $dbh = $dbr->connect($scandb,'dbh') || die "failed to connect";
      return $self->_error('failed to prepare statement') unless
	my $sth = $dbh->prepare("SHOW TABLES;");

      my $rowct = $sth->execute();

      return $self->_error('failed to execute statement') unless defined($rowct);

      my @tables;
      if ($rowct) {
	    while (my $row = $sth->fetchrow_arrayref()) {
		  push @tables, $row->[0];
	    }
      }

      $sth->finish();

      return \@tables;
}

sub desc_table{
      my $self = shift;
      my $dbr = shift;
      my $table = shift;

      my $dbh = $dbr->connect($scandb,'dbh') || die "failed to connect";

      return $self->_error('failed to prepare statement') unless
	my $sth = $dbh->prepare("describe $table");

      my $rowct = $sth->execute();

      return $self->_error('failed to execute statement') unless defined($rowct);

      my @rows;
      if ($rowct) {
	    while (my $row = $sth->fetchrow_hashref()) {
		  push @rows, $row;
	    }
      }

      $sth->finish();

      return \@rows;
}

sub update_table{
      my $self = shift;
      my $dbr = shift;
      my $desc = shift;
      my $name = shift;

      my $dbh = $dbr->connect($db) || die "failed to connect to DBRdb";

      return $self->_error('failed to select from dbr_tables') unless
	my $tables = $dbh->select(
				  -table  => 'dbr_tables',
				  -fields => 'table_id schema_id name',
				  -where  => {
					      schema_id => ['d',$schema_id],
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
						   schema_id => ['d',$schema_id],
						   name      => $name,
						  }
				      );
      }

      update_fields($dbr,$dbr,$desc,$table_id) || return $self->_error('Failed to update fields');

      return 1;
}


sub update_fields{
      my $self = shift;
      my $dbr = shift;
      my $desc = shift;
      my $table_id = shift;

      my $dbh = $dbr->connect($db) || die "failed to connect to DBRdb";

      return $self->_error('failed to select from dbr_fields') unless
	my $records = $dbh->select(
				  -table  => 'dbr_fields',
				  -fields => 'field_id table_id name field_type is_nullable is_signed max_value',
				  -where  => {
					      table_id  => ['d',$table_id]
					     }
				 );

      my %fieldmap;
      map {$fieldmap{$_->{name}} = $_} @{$records};

      my %datatypes = (
		       bigint    => { id => 1, bits => 64},
		       int       => { id => 2, bits => 32},
		       mediumint => { id => 3, bits => 24},
		       smallint  => { id => 4, bits => 16},
		       tinyint   => { id => 5, bits => 8},
		       bool      => { id => 6, bits => 1},
		       float     => { id => 7, bits => 1},
		       double    => { id => 8, bits => 1},
		       varchar   => { id => 9 },
		       char      => { id => 10 },
		       text      => { id => 11 },
		       mediumtext=> { id => 12 },
		       blob      => { id => 13 },
		       longblob  => { id => 14 },
		       mediumblob=> { id => 15 },
		       tinyblob  => { id => 16 },
		       enum      => { id => 17 }, # I loathe mysql enums
		      );


      foreach my $field (@{$desc}){
	    my $name     = $field->{Field};
	    my $record = $fieldmap{$name};

	    my $rawtype = $field->{Type};

	    my ($type,$size,$other,$flags) = 
	      #               type       (opt           size or other       opt)     flags
	      $rawtype =~ /^([a-z]*) \s* (?:      \((?: (\d+) | (.*?) )\)      )? \s*([a-z\s]*)?$/ix;
	    
	    use Data::Dumper;
	    print STDERR Dumper($field,[$type,$size,$other,$flags]);
	    my $typeref = $datatypes{lc($type)} || return $self->_error("Unrecognized data type '$type'");

	    my $ref = {
		       is_nullable => ['d',  (uc($field->{Null}) eq 'YES')?1:0   ],
		       is_signed   => ['d',  ($flags =~ /unsigned/i)?0:1         ],
		       field_type  => ['d',  $typeref->{id}                      ],
		       max_value   => ['d',  $size || 0                          ],
		      };

	    if($record){ # update
		  return $self->_error('failed to insert into dbr_tables') unless
		    $dbh->update(
				 -table  => 'dbr_fields',
				 -fields => $ref,
				 -where  => { field_id => ['d',$record->{field_id}] },
				);
	    }else{
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


      foreach my $name (keys %fieldmap){
	    my $record = $fieldmap{$name};

	    return $self->_error('failed to delete from dbr_tables') unless
	      $dbh->delete(
			   -table  => 'dbr_fields',
			   -where  => { field_id => ['d',$record->{field_id}] },
			  );
      }

#           {
#             'Extra' => '',
#             'Type' => 'int(10) unsigned',
#             'Field' => 'giftcert_id',
#             'Default' => undef,
#             'Null' => 'YES',
#             'Key' => ''
#           },



      return 1;
}


