package DBR::Sandbox;

use strict;
use DBR;
use DBR::Util::Logger;
use DBR::Config::ScanDB;
use DBR::Config::SpecLoader;
use DBR::Config::Schema;
use Scalar::Util 'blessed';
use File::Path;
use Carp;

sub import {
    my $pkg = shift;
    my %params = @_;
    my $dbr;

    my ($callpack, $callfile, $callline) = caller;

    if( $params{schema} ){
        DBR::Sandbox->provision( %params );
    }

}

my ($CONFDIR) = grep {-d $_ } ('schemas','example/schemas','../example/schemas');

sub provision{
    my $package = shift if blessed($_[0]) || $_[0] eq __PACKAGE__;
    my %params = @_;
    
    my $schema = $params{schema} or confess "schema is required";
    
    my $sandbox = '_sandbox/' . $params{schema};
    my $dbrconf = $params{writeconf} || "$sandbox/DBR.conf";
    
    
    _ready_sandbox ( $sandbox );
    
    my $metadb = _sqlite_connect( dbfile => "$sandbox/dbrconf.sqlite" );
    my $maindb = _sqlite_connect( dbfile => "$sandbox/db.sqlite" );
    
    _load_sqlfile ( "$CONFDIR/dbr_schema_sqlite.sql", $metadb );
    _load_sqlfile ( "$CONFDIR/$schema/sql", $maindb );
    
    _setup_metadb ( $sandbox, $schema, $metadb );
    
    $metadb->disconnect();
    $maindb->disconnect();
    
    _write_dbrconf( $sandbox, $dbrconf );
    
    my $logger = new DBR::Util::Logger( -logpath => '_sandbox/sandbox_setup.log', -logLevel => 'debug3' ) or die "logger create failed";
    my $dbr = new DBR(
        -logger   => $logger,
        -conf     => $dbrconf,
        -admin    => 1,
        -fudge_tz => 1,
    ) or die 'failed to create dbr object';
    
    my $conf_instance = $dbr->get_instance('dbrconf') or die "No config found for confdb";
    
    my $loader = DBR::Config::SpecLoader->new(
                      session       => $dbr->session,
                      conf_instance => $conf_instance,
                      dbr           => $dbr,
                    ) or die "Failed to create spec loader";
    
    my $spec = $loader->parse_file( "$CONFDIR/$schema/spec" ) or die "Failed to open $CONFDIR/$schema/spec";

    $loader->process_spec( $spec ) or die "Failed to process spec data";

    # returning DBR object to be used with test harnesses
    return $dbr;

}

sub _ready_sandbox{
    my $sandbox = shift;

    File::Path::rmtree( $sandbox ) if -e $sandbox;
    mkpath $sandbox or confess "failed to ready sandbox '$sandbox'";
}

sub _sqlite_connect {
        my $attr = { @_ };
        my $dbfile = delete $attr->{dbfile} || ':memory:';
        my @params = ( "dbi:SQLite:dbname=$dbfile", '', '' );
        if ( %$attr ) {
                push @params, $attr;
        }
        my $dbh = DBI->connect( @params );
        return $dbh;
}

sub _load_sqlfile{
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

sub _setup_metadb{
    my $sandbox = shift;
    my $schema  = shift;
    my $dbh = shift;

    $dbh->do("INSERT INTO dbr_schemas (schema_id,handle) values (1,'$schema')") or return 0;
    $dbh->do("INSERT INTO dbr_instances (schema_id,handle,class,dbfile,module) values (1,'$schema','master','$sandbox/db.sqlite','SQLite')") or return 0;

    return 1;
}

sub _write_dbrconf{
    my $sandbox = shift;
    my $dbrconf = shift;
    my $fh;
    open ($fh, "> $dbrconf") or return 0;
    print $fh "name=dbrconf; class=master; dbfile=$sandbox/dbrconf.sqlite;type=SQLite; dbr_bootstrap=1";
    close $fh;

    return 1;
}


1;
