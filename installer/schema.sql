/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.5.29-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: libki-mariadb    Database: libki
-- ------------------------------------------------------
-- Server version	12.1.2-MariaDB-ubu2404

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `allotments`
--

DROP TABLE IF EXISTS `allotments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `allotments` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `user_id` int(11) NOT NULL,
  `location` varchar(191) NOT NULL,
  `minutes` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`,`location`),
  CONSTRAINT `allotments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `client_age_limits`
--

DROP TABLE IF EXISTS `client_age_limits`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `client_age_limits` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client` int(11) NOT NULL,
  `comparison` enum('eq','ne','gt','lt','le','ge') NOT NULL,
  `age` int(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_age_limits` (`instance`,`client`,`comparison`,`age`),
  KEY `client` (`client`),
  KEY `instance` (`instance`),
  CONSTRAINT `client_age_limits_ibfk_1` FOREIGN KEY (`client`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `clients`
--

DROP TABLE IF EXISTS `clients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `clients` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(191) NOT NULL,
  `location` varchar(191) DEFAULT NULL,
  `status` varchar(191) DEFAULT 'online',
  `type` varchar(191) DEFAULT NULL,
  `ipaddress` varchar(191) DEFAULT NULL,
  `macaddress` varchar(191) DEFAULT NULL,
  `hostname` varchar(191) DEFAULT NULL,
  `last_registered` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`instance`,`name`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `closing_hours`
--

DROP TABLE IF EXISTS `closing_hours`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `closing_hours` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `location` int(11) DEFAULT NULL,
  `day` enum('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday') DEFAULT NULL,
  `date` date DEFAULT NULL,
  `closing_time` time NOT NULL,
  PRIMARY KEY (`id`),
  KEY `location` (`location`),
  KEY `instance` (`instance`),
  CONSTRAINT `closing_hours_ibfk_1` FOREIGN KEY (`location`) REFERENCES `locations` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(191) NOT NULL,
  `data` mediumtext DEFAULT NULL,
  `taken` varchar(191) DEFAULT NULL,
  `status` varchar(191) NOT NULL DEFAULT 'QUEUED',
  `created_on` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_on` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `locations`
--

DROP TABLE IF EXISTS `locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `locations` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `code` varchar(191) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_code` (`instance`,`code`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `login_sessions`
--

DROP TABLE IF EXISTS `login_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `login_sessions` (
  `id` char(72) NOT NULL,
  `session_data` mediumtext DEFAULT NULL,
  `expires` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `logs`
--

DROP TABLE IF EXISTS `logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `instance` varchar(32) DEFAULT '',
  `created_on` datetime NOT NULL DEFAULT current_timestamp(),
  `pid` varchar(10) NOT NULL DEFAULT '',
  `hostname` varchar(100) NOT NULL DEFAULT '',
  `level` varchar(10) NOT NULL DEFAULT '',
  `message` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `created_on_idx` (`created_on`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `messages` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `content` mediumtext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `instance` (`instance`),
  CONSTRAINT `messages_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `print_files`
--

DROP TABLE IF EXISTS `print_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `print_files` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `filename` mediumtext NOT NULL,
  `content_type` varchar(191) DEFAULT NULL,
  `data` longblob DEFAULT NULL,
  `pages` int(4) DEFAULT NULL,
  `client_id` int(11) DEFAULT NULL,
  `client_name` varchar(191) NOT NULL,
  `client_location` varchar(191) DEFAULT NULL,
  `client_type` varchar(191) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `username` varchar(191) NOT NULL,
  `created_on` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_on` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `client_id` (`client_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `print_files_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `print_files_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `print_jobs`
--

DROP TABLE IF EXISTS `print_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `print_jobs` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(191) NOT NULL,
  `status` varchar(191) NOT NULL,
  `copies` int(3) DEFAULT NULL,
  `data` mediumtext DEFAULT NULL,
  `printer` varchar(191) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `print_file_id` int(11) DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_on` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `released_on` timestamp NULL DEFAULT NULL,
  `queued_on` datetime DEFAULT NULL,
  `queued_to` varchar(191) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `print_jobs_ibfk_1` (`print_file_id`),
  CONSTRAINT `print_jobs_ibfk_1` FOREIGN KEY (`print_file_id`) REFERENCES `print_files` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `print_jobs_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `reservations`
--

DROP TABLE IF EXISTS `reservations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `reservations` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `client_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `begin_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `instance` (`instance`),
  KEY `reservations_ibfk_1` (`client_id`),
  CONSTRAINT `reservations_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `reservations_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role` mediumtext DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `client_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `status` enum('active','locked') NOT NULL DEFAULT 'active',
  `minutes` int(11) NOT NULL DEFAULT 0,
  `session_id` char(72) DEFAULT NULL,
  PRIMARY KEY (`client_id`,`user_id`),
  UNIQUE KEY `client_id` (`client_id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `instance` (`instance`),
  CONSTRAINT `sessions_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE,
  CONSTRAINT `sessions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `settings`
--

DROP TABLE IF EXISTS `settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `settings` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `name` varchar(191) NOT NULL,
  `value` mediumtext NOT NULL,
  PRIMARY KEY (`instance`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `statistics`
--

DROP TABLE IF EXISTS `statistics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `statistics` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(191) DEFAULT NULL,
  `client_name` varchar(191) DEFAULT NULL,
  `client_location` varchar(191) DEFAULT NULL,
  `client_type` varchar(191) DEFAULT NULL,
  `action` varchar(191) DEFAULT NULL,
  `created_on` timestamp NULL DEFAULT NULL,
  `anonymized` tinyint(1) DEFAULT 0,
  `session_id` char(72) DEFAULT NULL,
  `info` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`info`)),
  PRIMARY KEY (`id`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `transactions`
--

DROP TABLE IF EXISTS `transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `instance` varchar(32) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `user_id` int(11) NOT NULL,
  `provider` varchar(32) NOT NULL,
  `provider_payment_id` varchar(128) DEFAULT NULL,
  `amount_cents` int(11) NOT NULL,
  `currency` char(3) NOT NULL DEFAULT 'USD',
  `status` varchar(32) NOT NULL,
  `notes` longtext CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_on` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_provider_payment` (`instance`,`provider`,`provider_payment_id`),
  KEY `user_transactions_ibfk_1` (`user_id`),
  KEY `idx_instance_user` (`instance`,`user_id`),
  KEY `idx_instance_status` (`instance`,`status`),
  KEY `idx_created_on` (`created_on`),
  CONSTRAINT `user_transactions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `user_roles`
--

DROP TABLE IF EXISTS `user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_roles` (
  `user_id` int(11) NOT NULL DEFAULT 0,
  `role_id` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`,`role_id`),
  KEY `role_id` (`role_id`),
  CONSTRAINT `user_roles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `user_roles_ibfk_2` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(191) NOT NULL,
  `password` varchar(191) NOT NULL,
  `status` varchar(191) NOT NULL,
  `notes` mediumtext DEFAULT NULL,
  `is_troublemaker` enum('Yes','No') NOT NULL DEFAULT 'No',
  `troublemaker_until` datetime DEFAULT NULL,
  `is_guest` enum('Yes','No') NOT NULL DEFAULT 'No',
  `birthdate` date DEFAULT NULL,
  `created_on` datetime NOT NULL DEFAULT current_timestamp(),
  `updated_on` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `firstname` varchar(191) DEFAULT '',
  `lastname` varchar(191) DEFAULT '',
  `category` varchar(191) DEFAULT '',
  `creation_source` varchar(191) DEFAULT NULL,
  `gratis_print_balance` int(11) NOT NULL DEFAULT 0 COMMENT 'Number of free prints remaining; represents pages or cents depending on system settings',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_username` (`instance`,`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-02-11 10:59:54
