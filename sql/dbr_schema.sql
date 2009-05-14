
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
  CONSTRAINT `fk_dbr_instances-dbr_schemas` FOREIGN KEY (`schema_id`) REFERENCES `dbr_schemas` (`schema_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `dbr_schemas`;
CREATE TABLE `dbr_schemas` (
  `schema_id` int(10) unsigned NOT NULL auto_increment,
  `handle` varchar(50) default NULL,
  `display_name` varchar(50) default NULL,
  `definition_mode` tinyint(1) NOT NULL default '1' COMMENT 'Determines whether dbr uses table & field defs',
  `enum_scheme` tinyint(3) unsigned NOT NULL COMMENT 'None, Code hook or procedure',
  `enum_call` varchar(50) default NULL,
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
  CONSTRAINT `fk_dbr_table-dbr_schema` FOREIGN KEY (`schema_id`) REFERENCES `dbr_schemas` (`schema_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `dbr_fields`;
CREATE TABLE `dbr_fields` (
  `field_id` int(10) unsigned NOT NULL auto_increment,
  `table_id` int(10) unsigned NOT NULL,
  `name` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `field_type` tinyint(3) unsigned NOT NULL,
  `is_nullable` tinyint(1) default NULL,
  `is_signed` tinyint(1) default NULL,
  `is_enum` tinyint(1) default NULL,
  `enum_param` varchar(250) default NULL COMMENT 'parameters to pass to your enum engine',
  `max_value` int(10) unsigned NOT NULL,
  `display_name` varchar(250) default NULL,
  `is_pkey` tinyint(1) default NULL,
  `index_type` tinyint(1) default NULL,
  PRIMARY KEY  (`field_id`),
  KEY `fk_dbr_fields-dbr_tables` (`table_id`),
  CONSTRAINT `fk_dbr_fields-dbr_tables` FOREIGN KEY (`table_id`) REFERENCES `dbr_tables` (`table_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
