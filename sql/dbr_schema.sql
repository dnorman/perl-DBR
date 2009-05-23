-- MySQL dump 10.11
--
-- Host: daniel    Database: dbr
-- ------------------------------------------------------
-- Server version	5.0.77

--
-- Table structure for table `dbr_field_map`
--

CREATE TABLE `dbr_field_map` (
  `map_id` int(10) unsigned NOT NULL,
  `relationship_id` int(10) unsigned NOT NULL,
  `from_field_id` int(10) unsigned NOT NULL,
  `to_field_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`map_id`),
  KEY `fk_fieldmap_relationship` (`relationship_id`),
  KEY `fk_fieldmap_from_field` (`from_field_id`),
  KEY `fk_fieldmap_to_field` (`to_field_id`),
  CONSTRAINT `fk_fieldmap_relationship` FOREIGN KEY (`relationship_id`) REFERENCES `dbr_relationships` (`relationship_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_fieldmap_from_field` FOREIGN KEY (`from_field_id`) REFERENCES `dbr_fields` (`field_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_fieldmap_to_field` FOREIGN KEY (`to_field_id`) REFERENCES `dbr_fields` (`field_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
);

--
-- Table structure for table `dbr_fields`
--

CREATE TABLE `dbr_fields` (
  `field_id` int(10) unsigned NOT NULL,
  `table_id` int(10) unsigned NOT NULL,
  `name` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `data_type` tinyint(3) unsigned NOT NULL,
  `is_nullable` tinyint(1) default NULL,
  `is_signed` tinyint(1) default NULL,
  `max_value` int(10) unsigned NOT NULL,
  `display_name` varchar(250) default NULL,
  `is_pkey` tinyint(1) default '0',
  `index_type` tinyint(1) default NULL,
  `trans_id` tinyint(3) unsigned default NULL,
  PRIMARY KEY  (`field_id`),
  KEY `fk_dbr_fields-dbr_tables` (`table_id`),
  CONSTRAINT `fk_dbr_fields-dbr_tables` FOREIGN KEY (`table_id`) REFERENCES `dbr_tables` (`table_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
);

--
-- Table structure for table `dbr_fielduse`
--

CREATE TABLE `dbr_fielduse` (
  `row_id` int(10) unsigned NOT NULL,
  `scope_id` int(10) unsigned NOT NULL,
  `field_id` int(10) unsigned NOT NULL,
  PRIMARY KEY  (`row_id`),
  UNIQUE KEY `scope_id` (`scope_id`,`field_id`)
);

--
-- Table structure for table `dbr_instances`
--

CREATE TABLE `dbr_instances` (
  `instance_id` int(10) unsigned NOT NULL,
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
);

--
-- Table structure for table `dbr_relationships`
--

CREATE TABLE `dbr_relationships` (
  `relationship_id` int(10) unsigned NOT NULL,
  `to_name` varchar(45) NOT NULL COMMENT 'forward name of this relationship',
  `from_name` varchar(45) NOT NULL COMMENT 'reverse name of this relationship',
  `from_table_id` int(10) unsigned NOT NULL,
  `to_table_id` int(10) unsigned NOT NULL,
  `type` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY  (`relationship_id`),
  KEY `fk_relationship_from_table` (`from_table_id`),
  KEY `fk_relationship_to_table` (`to_table_id`),
  CONSTRAINT `fk_relationship_from_table` FOREIGN KEY (`from_table_id`) REFERENCES `dbr_tables` (`table_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `fk_relationship_to_table` FOREIGN KEY (`to_table_id`) REFERENCES `dbr_tables` (`table_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
);

--
-- Table structure for table `dbr_schemas`
--

CREATE TABLE `dbr_schemas` (
  `schema_id` int(10) unsigned NOT NULL,
  `handle` varchar(50) default NULL,
  `display_name` varchar(50) default NULL,
  `definition_mode` tinyint(1) NOT NULL default '1' COMMENT 'Determines whether dbr uses table & field defs',
  PRIMARY KEY  (`schema_id`),
  UNIQUE KEY `handle` (`handle`)
);

--
-- Table structure for table `dbr_scopes`
--

CREATE TABLE `dbr_scopes` (
  `scope_id` int(10) unsigned NOT NULL,
  `digest` char(32) default NULL,
  PRIMARY KEY  (`scope_id`),
  UNIQUE KEY `digest_2` (`digest`),
  KEY `digest` (`digest`)
);

--
-- Table structure for table `dbr_tables`
--

CREATE TABLE `dbr_tables` (
  `table_id` int(10) unsigned NOT NULL,
  `schema_id` int(10) unsigned NOT NULL,
  `name` varchar(250) character set latin1 collate latin1_bin NOT NULL,
  `display_name` varchar(250) default NULL,
  `is_cachable` tinyint(1) NOT NULL,
  PRIMARY KEY  (`table_id`),
  KEY `fk_dbr_table-dbr_schema` (`schema_id`),
  CONSTRAINT `fk_dbr_table-dbr_schema` FOREIGN KEY (`schema_id`) REFERENCES `dbr_schemas` (`schema_id`) ON DELETE NO ACTION ON UPDATE NO ACTION
);

--
-- Table structure for table `enum`
--

CREATE TABLE `enum` (
  `enum_id` int(10) unsigned NOT NULL,
  `handle` varchar(250) default NULL COMMENT 'ideally a unique key',
  `name` varchar(250) default NULL,
  `override_id` int(10) unsigned default NULL,
  PRIMARY KEY  (`enum_id`),
  KEY `handle` (`handle`)
);

--
-- Table structure for table `enum_legacy_map`
--

CREATE TABLE `enum_legacy_map` (
  `row_id` int(10) unsigned NOT NULL,
  `context` varchar(250) default NULL,
  `field` varchar(250) default NULL,
  `enum_id` int(10) unsigned NOT NULL,
  `sortval` int(11) default NULL,
  PRIMARY KEY  (`row_id`)
);

--
-- Table structure for table `enum_map`
--

CREATE TABLE `enum_map` (
  `row_id` int(10) unsigned NOT NULL,
  `field_id` int(10) unsigned NOT NULL,
  `enum_id` int(10) unsigned NOT NULL,
  `sortval` int(11) default NULL,
  PRIMARY KEY  (`row_id`),
  KEY `field_id` (`field_id`)
);


-- Dump completed on 2009-05-22 22:08:22
