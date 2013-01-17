-- Convert schema '/home/libki/Libki/script/utilities/../../sql/_source/deploy/2/001-auto.yml' to '/home/libki/Libki/script/utilities/../../sql/_source/deploy/3.00.00.00/001-auto.yml':;

;
BEGIN;

;
CREATE TEMPORARY TABLE clients_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255) NOT NULL,
  location varchar(255),
  last_registered timestamp
);

;
INSERT INTO clients_temp_alter SELECT id, name, location, last_registered FROM clients;

;
DROP TABLE clients;

;
CREATE TABLE clients (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255) NOT NULL,
  location varchar(255),
  last_registered timestamp
);

;
CREATE UNIQUE INDEX name02 ON clients (name);

;
INSERT INTO clients SELECT id, name, location, last_registered FROM clients_temp_alter;

;
DROP TABLE clients_temp_alter;

;
CREATE TEMPORARY TABLE statistics_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  client_name varchar(255) NOT NULL,
  client_location varchar(255),
  action enum NOT NULL,
  when timestamp
);

;
INSERT INTO statistics_temp_alter SELECT id, username, client_name, client_location, action, when FROM statistics;

;
DROP TABLE statistics;

;
CREATE TABLE statistics (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  client_name varchar(255) NOT NULL,
  client_location varchar(255),
  action enum NOT NULL,
  when timestamp
);

;
INSERT INTO statistics SELECT id, username, client_name, client_location, action, when FROM statistics_temp_alter;

;
DROP TABLE statistics_temp_alter;

;
CREATE TEMPORARY TABLE users_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  password TEXT NOT NULL,
  minutes integer NOT NULL DEFAULT 0,
  status varchar(255) NOT NULL,
  notes text NOT NULL,
  message text NOT NULL,
  is_troublemaker enum NOT NULL DEFAULT 'No',
  is_guest enum NOT NULL DEFAULT 'No'
);

;
INSERT INTO users_temp_alter SELECT id, username, password, minutes, status, notes, message, is_troublemaker, is_guest FROM users;

;
DROP TABLE users;

;
CREATE TABLE users (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  password TEXT NOT NULL,
  minutes integer NOT NULL DEFAULT 0,
  status varchar(255) NOT NULL,
  notes text NOT NULL,
  message text NOT NULL,
  is_troublemaker enum NOT NULL DEFAULT 'No',
  is_guest enum NOT NULL DEFAULT 'No'
);

;
CREATE UNIQUE INDEX username02 ON users (username);

;
INSERT INTO users SELECT id, username, password, minutes, status, notes, message, is_troublemaker, is_guest FROM users_temp_alter;

;
DROP TABLE users_temp_alter;

;
DROP TABLE dbix_class_deploymenthandler_versions;

;

COMMIT;

