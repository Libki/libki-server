CREATE TABLE `logs` (
  `id` int(11) NOT NULL auto_increment,
  `instance` varchar(32) NULL DEFAULT '',
  `created_on` datetime NOT NULL default CURRENT_TIMESTAMP,
  `pid` varchar(10) NOT NULL default '',
  `hostname` varchar(100) NOT NULL default '',
  `level` varchar(10) NOT NULL default '',
  `message` text NOT NULL default '',
  PRIMARY KEY  (`id`),
  KEY `created_on_idx` (`created_on`)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;
