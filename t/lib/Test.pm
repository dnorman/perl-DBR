package t::lib::Test;

use Test::More;
use DBR;
use DBR::Util::Logger;
use DBR::Config::ScanDB;
use DBR::Config::SpecLoader;
use DBR::Config::Schema;
use File::Path;

our @EXPORT = qw(connect_ok setup_schema_ok);
our $VERSION = '1';

use base 'Exporter';

# Delete temporary files
sub clean {
	#unlink( 'test-subject-db.sqlite' );
	#unlink( 'test-config-db.sqlite'  );
}

# Clean up temporary test files both at the beginning and end of the
# test script.
BEGIN { clean() }
END   { clean() }

my $CONFDIR = 't/conf';

sub connectdb {
        my $attr = { @_ };
        my $dbfile = delete $attr->{dbfile} || ':memory:';
        my @params = ( "dbi:SQLite:dbname=$dbfile", '', '' );
        if ( %$attr ) {
                push @params, $attr;
        }
        my $dbh = DBI->connect( @params );
        return $dbh;
}

sub connect_ok {
        my $attr = { @_ };
        my $dbfile = delete $attr->{dbfile} || ':memory:';
        my @params = ( "dbi:SQLite:dbname=$dbfile", '', '' );
        if ( %$attr ) {
                push @params, $attr;
        }
        my $dbh = DBI->connect( @params );
        Test::More::isa_ok( $dbh, 'DBI::db' );
        return $dbh;
}

sub setup_schema_ok{
      my $testid = shift;

      my $sandbox = ready_sandbox ( $testid ) or return fail('Ready Sandbox');

      my $metadbh = connectdb    ( dbfile => "$sandbox/meta.sqlite" ) or return fail('Connect - Meta DB');
      load_sqlfile ( "$CONFDIR/dbr_schema_sqlite.sql", $metadbh )         or return fail('Load SQL file - Meta');
      setup_metadb( $sandbox, $metadbh ) or fail ('Set up Meta DB');
      $metadbh->disconnect();

      my $maindbh = connectdb    ( dbfile =>  "$sandbox/db.sqlite" )   or return fail ('Connect - Test DB');
      load_sqlfile ( "$CONFDIR/$testid/sql", $maindbh ) or return fail ('Load SQL file');
      $maindbh->disconnect();

      write_dbrconf( $sandbox ) or return fail ('Write DBR.conf');

      my $logger = new DBR::Util::Logger(-logpath => 'dbr_test.log', -logLevel => 'debug3')
	or return fail ('Logger');
      my $dbr    = new DBR(
			   -logger => $logger,
			   -conf   => "$sandbox/DBR.conf",
			   -admin => 1,
			   -fudge_tz => 1,
			  )
	or return fail('DBR library');

      my $conf_instance = $dbr->get_instance('dbrconf') or return fail( "No config found for confdb");
      my $scan_instance = $dbr->get_instance('test')    or return fail "No config found for scandb";

      my $scanner = DBR::Config::ScanDB->new(
					     session       => $dbr->session,
					     conf_instance => $conf_instance,
					     scan_instance => $scan_instance,
					    ) or return fail('Create ScanDB object');

      $scanner->scan() or return fail('Failed to scan DB');


      DBR::Config::Schema->load(
				session   => $dbr->session,
				schema_id => 1,
				instance  => $conf_instance,
			       ) or return fail("Failed to reload schema");


      my $loader = DBR::Config::SpecLoader->new(
						session       => $dbr->session,
						conf_instance => $conf_instance,
					       ) or return fail("Failed to create spec loader");


      my $spec = $loader->parse_file( "$CONFDIR/$testid/spec" ) or return fail( "Failed to open $CONFDIR/$testid/spec" );
      $loader->process_spec( $spec ) or return fail("Failed to process spec data");

      DBR::Config::Schema->load(
				session    => $dbr->session,
				schema_id => 1,
				instance  => $conf_instance,
			       ) or return fail( "Failed to reload schema" );


      Test::More::ok( 1, 'Setup Schema' );

	# returning DBR object to be used with test harnesses
	return $dbr;

}

sub ready_sandbox{
      my $testid = shift;
      my $sandbox = "t/sandbox/$testid";

      File::Path::rmtree( $sandbox ) if -e $sandbox;
      mkdir $sandbox or return 0;
      return $sandbox;
}

sub load_sqlfile{
      my $file = shift;
      my $dbh = shift;

      my $fh;
      open ($fh, "<$file") || return 0;
      my $buff;
      while (<$fh>){
	    $buff .= $_;
      }

      foreach my $part (split(';',$buff)){
	    next unless $part =~ /\S+/;
	    next if $part =~ /^\s*--/;
	    $dbh->do($part) or return 0;
      }

      return 1;
}

sub setup_metadb{
      my $sandbox = shift;
      my $dbh = shift;

      $dbh->do("INSERT INTO dbr_schemas (schema_id,handle) values (1,'test')") or return 0;
      $dbh->do("INSERT INTO dbr_instances (schema_id,handle,class,dbfile,module) values (1,'test','master','$sandbox/db.sqlite','SQLite')") or return 0;

      return 1;
}

sub write_dbrconf{
      my $sandbox = shift;
      my $fh;
      open ($fh, "> $sandbox/DBR.conf") or return 0;
      print $fh 'name=dbrconf; class=master; dbfile=' . $sandbox . '/meta.sqlite; type=SQLite; dbr_bootstrap=1';
      close $fh;

      return 1;
}


1;
