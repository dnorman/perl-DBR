
DROP TABLE IF EXISTS `dbr_instances`;
CREATE TABLE `dbr_instances` (
  `instance_id` int(10) unsigned NOT NULL auto_increment,
  `schema_id` int(10) unsigned NOT NULL,
  `class` varchar(50) default NULL COMMENT 'query, master, etc...',
  `dbname` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `username` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `password` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `host` varchar(250) NOT NULL,
  `module` varchar(50) NOT NULL COMMENT 'Which DB Module to use',
  PRIMARY KEY  (`instance_id`),
  KEY `fk_dbr_instances-dbr_schemas` (`schema_id`),
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `dbr_schemas`;
CREATE TABLE `dbr_schemas` (
  `schema_id` int(10) unsigned NOT NULL auto_increment,
  `handle` varchar(50) default NULL,
  `display_name` varchar(50) default NULL,
  `definition_mode` tinyint(1) NOT NULL default '1' COMMENT 'Determines whether dbr uses table & field defs',
  PRIMARY KEY  (`schema_id`),
  UNIQUE KEY `handle` (`handle`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `dbr_tables`;
CREATE TABLE `dbr_tables` (
  `table_id` int(10) unsigned NOT NULL auto_increment,
  `schema_id` int(10) unsigned NOT NULL,
  `name` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `display_name` varchar(250) default NULL,
  `is_cachable` tinyint(1) NOT NULL,
  PRIMARY KEY  (`table_id`),
  KEY `fk_dbr_table-dbr_schema` (`schema_id`),
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `dbr_fields`;
CREATE TABLE `dbr_fields` (
  `field_id` int(10) unsigned NOT NULL auto_increment,
  `table_id` int(10) unsigned NOT NULL,
  `name` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `data_type` tinyint(3) unsigned NOT NULL,
  `is_nullable` tinyint(1) default NULL,
  `is_signed` tinyint(1) default NULL,
  `max_value` int(10) unsigned NOT NULL,
  `trans_id` tinyint(1) default NULL,
  `display_name` varchar(250) default NULL,
  `is_pkey` tinyint(1) default NULL,
  `index_type` tinyint(1) default NULL,
  PRIMARY KEY  (`field_id`),
  KEY `fk_dbr_fields-dbr_tables` (`table_id`),
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


CREATE TABLE dbr_field_translators (
  `trans_id` int(10) unsigned NOT NULL auto_increment,
  `name`   varchar(250) default NULL,
  `module` varchar(250) default NULL,
  `sortval` int default NULL,
  PRIMARY KEY  (trans_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


CREATE TABLE dbr_scopes (
  scope_id int unsigned NOT NULL auto_increment,
  digest char(32),
  PRIMARY KEY  (scope_id),
  KEY (digest)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE dbr_fielduse (
  row_id int unsigned NOT NULL auto_increment,
  scope_id int unsigned NOT NULL,
  field_id int unsigned NOT NULL,
  PRIMARY KEY  (row_id),
  KEY (scope_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


CREATE TABLE `enum` (
  `enum_id` int unsigned NOT NULL auto_increment,
  `handle` varchar(250) default NULL COMMENT 'ideally a unique key',
  `name`   varchar(250) default NULL,
  override_id int unsigned,
  PRIMARY KEY (enum_id),
  KEY (handle)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE enum_map (
  `row_id`   int unsigned NOT NULL auto_increment,
  `field_id` int unsigned NOT NULL,
  `enum_id`  int unsigned NOT NULL,
  `sortval`  int default NULL,
  PRIMARY KEY  (`row_id`),
  KEY (field_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE enum_legacy_map (
  `row_id` int(10) unsigned NOT NULL auto_increment,
  `context` varchar(250) default NULL,
  `field`   varchar(250) default NULL,
  `enum_id` int unsigned NOT NULL,
  `sortval` int default NULL,
  PRIMARY KEY  (row_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
