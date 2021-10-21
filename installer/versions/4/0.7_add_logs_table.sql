CREATE TABLE `logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` datetime NOT NULL DEFAULT current_timestamp(),
  `pid` varchar(10) NOT NULL DEFAULT '',
  `hostname` varchar(100) NOT NULL DEFAULT '',
  `level` varchar(10) NOT NULL DEFAULT '',
  `message` text NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `log_date_idx` (`date`)
) ENGINE=InnoDB CHARACTER SET utf8 COLLATE utf8_unicode_ci;
