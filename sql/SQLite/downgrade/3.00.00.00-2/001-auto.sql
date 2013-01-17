-- Convert schema '/home/libki/Libki/script/utilities/../../sql/_source/deploy/3.00.00.00/001-auto.yml' to '/home/libki/Libki/script/utilities/../../sql/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE dbix_class_deploymenthandler_versions (
  id INTEGER PRIMARY KEY NOT NULL,
  version varchar(50) NOT NULL,
  ddl text,
  upgrade_sql text
);

;
CREATE UNIQUE INDEX dbix_class_deploymenthandler_versions_version ON dbix_class_deploymenthandler_versions (version);

;
CREATE TEMPORARY TABLE clients_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255) NOT NULL,
  location varchar(255),
  last_registered timestamp NOT NULL DEFAULT current_timestamp
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
  last_registered timestamp NOT NULL DEFAULT current_timestamp
);

;
CREATE UNIQUE INDEX name04 ON clients (name);

;
INSERT INTO clients SELECT id, name, location, last_registered FROM clients_temp_alter;

;
DROP TABLE clients_temp_alter;

;
CREATE TEMPORARY TABLE statistics_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  clientname varchar(255) NOT NULL,
  action enum NOT NULL,
  when timestamp NOT NULL DEFAULT current_timestamp
);

;
INSERT INTO statistics_temp_alter SELECT id, username, clientname, action, when FROM statistics;

;
DROP TABLE statistics;

;
CREATE TABLE statistics (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  clientname varchar(255) NOT NULL,
  action enum NOT NULL,
  when timestamp NOT NULL DEFAULT current_timestamp
);

;
INSERT INTO statistics SELECT id, username, clientname, action, when FROM statistics_temp_alter;

;
DROP TABLE statistics_temp_alter;

;
ALTER TABLE users ADD COLUMN test1 integer NOT NULL;

;
ALTER TABLE users ADD COLUMN test2 integer NOT NULL;

;

COMMIT;

