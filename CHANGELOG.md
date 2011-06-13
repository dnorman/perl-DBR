perl-DBR CHANGE LOG
===

1.3 - Released 05/23/2011
---
  - consolidated test case and example schemas
  - created DBR::Sandbox to manage them
  - dramatically cleaned up / trimmed example scripts
  - hopefully fixed a minor issue causing cpantesters to fail

1.2 - Released 05/20/2011
---
  - merged commonref_rowcache
    Allows for read-ahead for record objects that are already retrieved.
    In past versions, read-ahead was only enabled if inside the while( $r = $rs->next ) loop
  - merged cross_schema_relationships
    Allows for relationships to be defined and used across schemas.
  - merged datetime_field
    For those who use the datetime data type, there is salvation
  - merged export_connect
    adds the use_exceptions flag on DBR->new
    also adds a new syntax for using DBR in your libraries:
    In your base class:
       use DBR (conf => '/path/to/conf_file.conf', app => 'myapp', logpath => '/path/to/logfile.log');
    Then elsewhere:
       use DBR ( app => 'myapp', use_exceptions => 1 ); 
       my $db = dbr_connect('schema-name');
       ...

1.1
---

1.1rc8
---
  merged 1.1_features

1.1rc7
---
  merged pre_1.1

1.0
1.0.7-final
1.0.7rc7

HERE BE DRAGONS
