ALTER TABLE `settings` MODIFY COLUMN `value` text NOT NULL;

CREATE TABLE `print_files` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `filename` text NOT NULL,
  `content_type` varchar(255) DEFAULT NULL,
  `data` blob,
  `pages` int(4) DEFAULT NULL,
  `client_id` int(11) DEFAULT NULL,
  `client_name` varchar(255) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `username` varchar(255) NOT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `client_id` (`client_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `print_files_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `print_files_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `print_jobs` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) NOT NULL, 
  `data` TEXT DEFAULT NULL,
  `printer` varchar(255) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `print_file_id` int(11) DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `print_jobs_ibfk_1` FOREIGN KEY (`print_file_id`) REFERENCES `print_files` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `print_jobs_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
