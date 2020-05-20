-- MySQL dump 10.13  Distrib 5.7.27, for Linux (x86_64)
--
-- Host: localhost    Database: libki 
-- ------------------------------------------------------
-- Server version	5.7.27-0ubuntu0.18.04.1
--
-- This dump serves as a starting point for the Libki server.
--
-- ------------------------------------------------------

--
-- Current Database: `libki`
--

CREATE DATABASE IF NOT EXISTS `libki` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `libki`;

--
-- Table structure for table `client_age_limits`
--

CREATE TABLE `client_age_limits` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client` int(11) NOT NULL,
  `comparison` enum('eq','ne','gt','lt','le','ge') NOT NULL,
  `age` int(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_age_limits` (`instance`,`client`,`comparison`,`age`),
  KEY `client` (`client`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `clients`
--

CREATE TABLE `clients` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(191) NOT NULL,
  `location` varchar(191) DEFAULT NULL,
  `last_registered` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`instance`,`name`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `closing_hours`
--

CREATE TABLE `closing_hours` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `location` int(11) DEFAULT NULL,
  `day` enum('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday') DEFAULT NULL,
  `date` date DEFAULT NULL,
  `closing_time` time NOT NULL,
  PRIMARY KEY (`id`),
  KEY `location` (`location`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `jobs`
--

CREATE TABLE `jobs` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(191) NOT NULL,
  `data` mediumtext,
  `taken` varchar(191) DEFAULT NULL,
  `status` varchar(191) NOT NULL DEFAULT 'QUEUED',
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

--
-- Table structure for table `locations`
--

CREATE TABLE `locations` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(191) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_code` (`instance`,`code`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `login_sessions`
--

CREATE TABLE `login_sessions` (
  `id` char(72) NOT NULL,
  `session_data` mediumtext,
  `expires` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

--
-- Table structure for table `messages`
--

CREATE TABLE `messages` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `content` mediumtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `print_files`
--

CREATE TABLE `print_files` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `filename` mediumtext NOT NULL,
  `content_type` varchar(191) DEFAULT NULL,
  `data` longblob,
  `pages` int(4) DEFAULT NULL,
  `client_id` int(11) DEFAULT NULL,
  `client_name` varchar(191) NOT NULL,
  `client_location` varchar(191) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `username` varchar(191) NOT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `client_id` (`client_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB;

--
-- Table structure for table `print_jobs`
--

CREATE TABLE `print_jobs` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(191) NOT NULL,
  `status` varchar(191) NOT NULL,
  `data` mediumtext,
  `printer` varchar(191) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `print_file_id` int(11) DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `print_jobs_ibfk_1` (`print_file_id`)
) ENGINE=InnoDB;

--
-- Table structure for table `reservations`
--

CREATE TABLE `reservations` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `expiration` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `client_id` (`client_id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `roles`
--

CREATE TABLE `roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role` mediumtext,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4;

--
-- Table structure for table `sessions`
--

CREATE TABLE `sessions` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `client_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `status` enum('active','locked') NOT NULL DEFAULT 'active',
  `minutes` int(11) NOT NULL DEFAULT '0',
  `session_id` char(72) DEFAULT NULL,
  PRIMARY KEY (`client_id`,`user_id`),
  UNIQUE KEY `client_id` (`client_id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `settings`
--

CREATE TABLE `settings` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `name` varchar(191) NOT NULL,
  `value` mediumtext NOT NULL,
  PRIMARY KEY (`instance`,`name`)
) ENGINE=InnoDB;

--
-- Table structure for table `statistics`
--

CREATE TABLE `statistics` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(191) NOT NULL,
  `client_name` varchar(191) NOT NULL,
  `client_location` varchar(191) DEFAULT NULL,
  `action` varchar(191) DEFAULT NULL,
  `created_on` timestamp NULL DEFAULT NULL,
  `anonymized` tinyint(1) DEFAULT '0',
  `session_id` char(72) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB;

--
-- Table structure for table `user_roles`
--

CREATE TABLE `user_roles` (
  `user_id` int(11) NOT NULL DEFAULT '0',
  `role_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_id`,`role_id`),
  KEY `role_id` (`role_id`)
) ENGINE=InnoDB;

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(191) NOT NULL,
  `password` varchar(191) NOT NULL,
  `minutes_allotment` int(11) DEFAULT '0',
  `status` varchar(191) NOT NULL,
  `notes` mediumtext,
  `is_troublemaker` enum('Yes','No') NOT NULL DEFAULT 'No',
  `is_guest` enum('Yes','No') NOT NULL DEFAULT 'No',
  `birthdate` date DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_on` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `firstname` varchar(191) DEFAULT '',
  `lastname` varchar(191) DEFAULT '',
  `category` varchar(191) DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_username` (`instance`,`username`)
) ENGINE=InnoDB AUTO_INCREMENT=2;

-- ------------------------------------------------------
--
-- CONSTRAINTS
--
-- ------------------------------------------------------


--
-- Constraints for table 'client_age_limits'
--

ALTER TABLE `client_age_limits`
    ADD CONSTRAINT `client_age_limits_ibfk_1` FOREIGN KEY (`client`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table 'closing_hours'
--

ALTER TABLE `closing_hours`
    ADD CONSTRAINT `closing_hours_ibfk_1` FOREIGN KEY (`location`) REFERENCES `locations` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table 'messages'
--

ALTER TABLE `messages`
    ADD CONSTRAINT `messages_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table 'print_files'
--

ALTER TABLE `print_files`
    ADD CONSTRAINT `print_files_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    ADD CONSTRAINT `print_files_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table 'print_jobs'
--

ALTER TABLE `print_jobs`
    ADD CONSTRAINT `print_jobs_ibfk_1` FOREIGN KEY (`print_file_id`) REFERENCES `print_files` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
    ADD CONSTRAINT `print_jobs_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table 'reservations'
--

ALTER TABLE `reservations`
    ADD CONSTRAINT `reservations_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `reservations_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table 'sessions'
--

ALTER TABLE `sessions`
    ADD CONSTRAINT `sessions_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE,
    ADD CONSTRAINT `sessions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table 'user_roles'
--

ALTER TABLE `user_roles`
    ADD CONSTRAINT `user_roles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT `user_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- ------------------------------------------------------
--
-- Data insertion
--
-- ------------------------------------------------------


--
-- Data for table `roles`
--

INSERT INTO `roles` VALUES
    (1,'user'),
    (2,'admin'),
    (3,'superadmin');

--
-- Data for table `settings`
--

INSERT INTO `settings` VALUES
    ('','AutomaticTimeExtensionAt',''),
    ('','AutomaticTimeExtensionLength',''),
    ('','AutomaticTimeExtensionRenewal','0'),
    ('','AutomaticTimeExtensionUnless','this_reserved'),
    ('','AutomaticTimeExtensionUseAllotment','no'),
    ('','BatchGuestPassCustomCSS','body { /* default body style emulates a pre tag */\n    font-family: monospace;\n    white-space: pre;\n    display: block;\n    unicode-bidi: embed;\n}\n.guest-pass { /* each username and password is in a guest-pass span */\n    /* page-break-before: always; */ /* This will cause each pass to have a page break, good for use with receipt printers */\n}\n.guest-pass-username {} /* span containing the username label and the username itself */\n.guest-pass-username-label {} /* span containing the username label */\n.guest-pass-username-content {} /* span containing the username itself */\n.guest-pass-password {} /* span containing the password label and the password itself */\n.guest-pass-password-label {} /* span containing the password label */\n.guest-pass-password-content {} /* span containing the password itself */\n'),
    ('','BatchGuestPassPasswordLabel','Computer Guest Pass     Password=  '),
    ('','BatchGuestPassUsernameLabel','Your Library            Username=  '),
    ('','ClientBehavior','FCFS+RES'),('','CurrentGuestNumber','1'),
    ('','CustomJsAdministration',''),('','CustomJsPublic',''),
    ('','DataRetentionDays',''),
    ('','DefaultGuestSessionTimeAllowance','45'),
    ('','DefaultGuestTimeAllowance','45'),
    ('','DefaultSessionTimeAllowance','45'),
    ('','DefaultTimeAllowance','45'),
    ('','GuestBatchCount','40'),
    ('','PostCrashTimeout','5'),
    ('','PrintJobRetentionDays','0'),
    ('','ReservationShowUsername','0'),
    ('','ReservationTimeout','15'),
    ('','ShowFirstLastNames','1'),
    ('','ThirdPartyURL',''),
    ('','UserCategories',''),
    ('','Version','1.0.0');

