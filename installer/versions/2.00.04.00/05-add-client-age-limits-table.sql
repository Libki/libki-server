CREATE TABLE IF NOT EXISTS `client_age_limits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client` int(11) NOT NULL,
  `comparison` enum('eq','ne','gt','lt','le','ge') NOT NULL,
  `age` int(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_age_limits` (`client`,`comparison`,`age`),
  KEY `client` (`client`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;


ALTER TABLE `client_age_limits`
  ADD CONSTRAINT `client_age_limits_ibfk_1` FOREIGN KEY (`client`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
