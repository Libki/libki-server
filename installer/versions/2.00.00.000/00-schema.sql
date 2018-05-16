SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

--
-- Table structure for table 'clients'
--

CREATE TABLE IF NOT EXISTS clients (
  id int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8 NOT NULL,
  location varchar(255) CHARACTER SET utf8 DEFAULT NULL,
  last_registered timestamp NULL DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

--
-- Table structure for table 'reservations'
--

CREATE TABLE IF NOT EXISTS reservations (
  id int(11) NOT NULL AUTO_INCREMENT,
  client_id int(11) NOT NULL,
  user_id int(11) NOT NULL,
  expiration datetime DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY client_id (client_id),
  UNIQUE KEY user_id (user_id)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

--
-- Table structure for table 'roles'
--

CREATE TABLE IF NOT EXISTS roles (
  id int(11) NOT NULL AUTO_INCREMENT,
  role text,
  PRIMARY KEY (id)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

--
-- Table structure for table 'sessions'
--

CREATE TABLE IF NOT EXISTS sessions (
  client_id int(11) NOT NULL,
  user_id int(11) NOT NULL,
  `status` enum('active','locked') CHARACTER SET utf8 NOT NULL DEFAULT 'active',
  PRIMARY KEY (client_id,user_id),
  UNIQUE KEY client_id (client_id),
  UNIQUE KEY user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table 'settings'
--

CREATE TABLE IF NOT EXISTS settings (
  `name` varchar(255) CHARACTER SET utf8 NOT NULL,
  `value` varchar(255) CHARACTER SET utf8 NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table 'statistics'
--

CREATE TABLE IF NOT EXISTS statistics (
  id int(11) NOT NULL AUTO_INCREMENT,
  username varchar(255) NOT NULL,
  client_name varchar(255) NOT NULL,
  client_location varchar(255) DEFAULT NULL,
  `action` enum('LOGIN','LOGOUT') NOT NULL,
  `when` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

--
-- Table structure for table 'users'
--

CREATE TABLE IF NOT EXISTS users (
  id int(11) NOT NULL AUTO_INCREMENT,
  username varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  minutes int(11) NOT NULL DEFAULT '0',
  `status` varchar(255) NOT NULL,
  notes text NOT NULL DEFAULT '',
  message text CHARACTER SET utf8 NOT NULL,
  is_troublemaker enum('Yes','No') NOT NULL DEFAULT 'No',
  is_guest enum('Yes','No') NOT NULL DEFAULT 'No',
  PRIMARY KEY (id),
  UNIQUE KEY username (username)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

--
-- Table structure for table 'user_roles'
--

CREATE TABLE IF NOT EXISTS user_roles (
  user_id int(11) NOT NULL DEFAULT '0',
  role_id int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (user_id,role_id),
  KEY role_id (role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Constraints for table `reservations`
--
ALTER TABLE `reservations`
  ADD CONSTRAINT reservations_ibfk_1 FOREIGN KEY (client_id) REFERENCES `clients` (id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT reservations_ibfk_2 FOREIGN KEY (user_id) REFERENCES `users` (id) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `sessions`
--
ALTER TABLE `sessions`
  ADD CONSTRAINT sessions_ibfk_1 FOREIGN KEY (client_id) REFERENCES `clients` (id) ON DELETE CASCADE,
  ADD CONSTRAINT sessions_ibfk_2 FOREIGN KEY (user_id) REFERENCES `users` (id) ON DELETE CASCADE;

--
-- Constraints for table `user_roles`
--
ALTER TABLE `user_roles`
  ADD CONSTRAINT user_roles_ibfk_1 FOREIGN KEY (user_id) REFERENCES `users` (id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT user_roles_ibfk_2 FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE ON UPDATE CASCADE;

