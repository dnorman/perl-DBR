use ExtUtils::MakeMaker;
use strict;

my $headurl = '$HeadURL: https://perl-dbr.googlecode.com/svn/trunk/lib/DBR.pm $';
my ($rev) = '$Rev:$' =~ /(\d+)/;
my ($tag) = $headurl =~ /\/svn\/(?:tags|branches)?\/?(.*?)\//;
if($tag eq 'trunk'){
      $tag .= '_' . $rev;
}

my $version = $tag || 'unknown';



WriteMakefile(
	      NAME            => 'DBR',
	      VERSION         => $version,
	      PREREQ_PM       => {
				  'Carp'               => 0,
				  'Class::Std'         => 0,
				  'Clone'              => 0,
				  'Curses::UI'         => 0,
				  'Data::Dumper'       => 0,
				  'DateTime::TimeZone' => 0,
				  'DBD::SQLite'        => '1.20',
				  'DBI'                => 0,
				  'Digest::MD5'        => 0,
				  'Error'              => 0,
				  'FileHandle'         => 0,
				  'POSIX'              => 0,
				  'Scalar::Util'       => 0,
				  'Symbol'             => 0,
				  'Time::HiRes'        => 0,
				  'Time::ParseDate'    => 0,
				 },

	     );
