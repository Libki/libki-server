-- MariaDB dump 10.19  Distrib 10.5.18-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: libki-mariadb    Database: libki
-- ------------------------------------------------------
-- Server version	10.3.5-MariaDB-10.3.5+maria~jessie

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `allotments`
--

LOCK TABLES `allotments` WRITE;
/*!40000 ALTER TABLE `allotments` DISABLE KEYS */;
/*!40000 ALTER TABLE `allotments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `client_age_limits`
--

LOCK TABLES `client_age_limits` WRITE;
/*!40000 ALTER TABLE `client_age_limits` DISABLE KEYS */;
/*!40000 ALTER TABLE `client_age_limits` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `clients`
--

LOCK TABLES `clients` WRITE;
/*!40000 ALTER TABLE `clients` DISABLE KEYS */;
/*!40000 ALTER TABLE `clients` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `closing_hours`
--

LOCK TABLES `closing_hours` WRITE;
/*!40000 ALTER TABLE `closing_hours` DISABLE KEYS */;
/*!40000 ALTER TABLE `closing_hours` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `jobs`
--

LOCK TABLES `jobs` WRITE;
/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `locations`
--

LOCK TABLES `locations` WRITE;
/*!40000 ALTER TABLE `locations` DISABLE KEYS */;
/*!40000 ALTER TABLE `locations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `login_sessions`
--

LOCK TABLES `login_sessions` WRITE;
/*!40000 ALTER TABLE `login_sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `login_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `logs`
--

LOCK TABLES `logs` WRITE;
/*!40000 ALTER TABLE `logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `messages`
--

LOCK TABLES `messages` WRITE;
/*!40000 ALTER TABLE `messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `print_files`
--

LOCK TABLES `print_files` WRITE;
/*!40000 ALTER TABLE `print_files` DISABLE KEYS */;
/*!40000 ALTER TABLE `print_files` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `print_jobs`
--

LOCK TABLES `print_jobs` WRITE;
/*!40000 ALTER TABLE `print_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `print_jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `reservations`
--

LOCK TABLES `reservations` WRITE;
/*!40000 ALTER TABLE `reservations` DISABLE KEYS */;
/*!40000 ALTER TABLE `reservations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'user'),(2,'admin'),(3,'superadmin');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `settings`
--

LOCK TABLES `settings` WRITE;
/*!40000 ALTER TABLE `settings` DISABLE KEYS */;
INSERT INTO `settings` VALUES ('','AutomaticTimeExtensionAt',''),('','AutomaticTimeExtensionLength',''),('','AutomaticTimeExtensionRenewal','0'),('','AutomaticTimeExtensionUnless','this_reserved'),('','AutomaticTimeExtensionUseAllotment','no'),('','BatchGuestPassCustomCSS','body { /* default body style emulates a pre tag */\n    font-family: monospace;\n    white-space: pre;\n    display: block;\n    unicode-bidi: embed;\n}\n.guest-pass { /* each username and password is in a guest-pass span */\n    /* page-break-before: always; */ /* This will cause each pass to have a page break, good for use with receipt printers */\n}\n.guest-pass-username {} /* span containing the username label and the username itself */\n.guest-pass-username-label {} /* span containing the username label */\n.guest-pass-username-content {} /* span containing the username itself */\n.guest-pass-password {} /* span containing the password label and the password itself */\n.guest-pass-password-label {} /* span containing the password label */\n.guest-pass-password-content {} /* span containing the password itself */\n'),('','BatchGuestPassPasswordLabel','Computer Guest Pass     Password=  '),('','BatchGuestPassTemplate','<html>\n  <head>\n    <style type=\"text/css\">[% batch_guest_pass_custom_css %]</style>\n  </head>\n  <body>\n    [% FOREACH g IN guests %]\n      <p class=\"guest-pass\">\n        <p class=\"guest-pass-username\">\n          <span class=\"guest-pass-username-label\">[% batch_guest_pass_username_label %]</span><span class=\"guest-pass-username-content\">[% g.username %]</span>\n        </p>\n        <p class=\"guest-pass-password\">\n          <span class=\"guest-pass-password-label\">[% batch_guest_pass_password_label %]</span><span class=\"guest-pass-password-content\">[%g. password %]</span>\n        </p>\n      </p>\n      <br/>\n    [% END %]\n  </body>\n</html>'),('','BatchGuestPassUsernameLabel','Your Library            Username=  '),('','ClientBehavior','FCFS+RES'),('','CurrentGuestNumber','1'),('','CustomJsAdministration',''),('','CustomJsPublic',''),('','DataRetentionDays',''),('','DefaultGuestSessionTimeAllowance','45'),('','DefaultGuestTimeAllowance','45'),('','DefaultSessionTimeAllowance','45'),('','DefaultTimeAllowance','45'),('','DisplayReservationStatusWithin','60'),('','GuestBatchCount','40'),('','MinimumReservationMinutes','5'),('','PostCrashTimeout','5'),('','PrintJobRetentionDays','0'),('','ReservationShowUsername','RSD'),('','ReservationTimeout','15'),('','ShowFirstLastNames','1'),('','ThirdPartyURL',''),('','UserCategories',''),('','Version','4.1.1');
/*!40000 ALTER TABLE `settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `statistics`
--

LOCK TABLES `statistics` WRITE;
/*!40000 ALTER TABLE `statistics` DISABLE KEYS */;
/*!40000 ALTER TABLE `statistics` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `user_roles`
--

LOCK TABLES `user_roles` WRITE;
/*!40000 ALTER TABLE `user_roles` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2023-03-07  9:40:54
