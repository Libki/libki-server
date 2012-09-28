-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Fri Sep 28 13:41:58 2012
-- 
;
SET foreign_key_checks=0;
--
-- Table: `clients`
--
CREATE TABLE `clients` (
  `id` integer NOT NULL auto_increment,
  `name` varchar(255) NOT NULL,
  `location` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `roles`
--
CREATE TABLE `roles` (
  `id` integer NOT NULL,
  `role` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `sessions`
--
CREATE TABLE `sessions` (
  `client_id` integer NOT NULL,
  `user_id` integer NOT NULL,
  `status` enum('active', 'locked') NOT NULL DEFAULT 'active',
  INDEX `sessions_idx_client_id` (`client_id`),
  INDEX `sessions_idx_user_id` (`user_id`),
  PRIMARY KEY (`client_id`, `user_id`),
  UNIQUE `client_id` (`client_id`),
  UNIQUE `user_id` (`user_id`),
  CONSTRAINT `sessions_fk_client_id` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `sessions_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `user_roles`
--
CREATE TABLE `user_roles` (
  `user_id` integer NOT NULL DEFAULT 0,
  `role_id` integer NOT NULL DEFAULT 0,
  INDEX `user_roles_idx_role_id` (`role_id`),
  INDEX `user_roles_idx_user_id` (`user_id`),
  PRIMARY KEY (`user_id`, `role_id`),
  CONSTRAINT `user_roles_fk_role_id` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `user_roles_fk_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `users`
--
CREATE TABLE `users` (
  `id` integer NOT NULL auto_increment,
  `username` varchar(255) NOT NULL,
  `password` text NOT NULL,
  `minutes` integer NOT NULL DEFAULT 0,
  `status` varchar(255) NOT NULL,
  `notes` text NOT NULL,
  `message` text,
  `is_troublemaker` enum('Yes', 'No') NOT NULL DEFAULT 'No',
  PRIMARY KEY (`id`),
  UNIQUE `username` (`username`)
) ENGINE=InnoDB;
SET foreign_key_checks=1