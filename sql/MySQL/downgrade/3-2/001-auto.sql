-- Convert schema '/home/libki/Libki/script/utilities/../../sql/_source/deploy/3/001-auto.yml' to '/home/libki/Libki/script/utilities/../../sql/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `dbix_class_deploymenthandler_versions` (
  id integer NOT NULL auto_increment,
  version varchar(50) NOT NULL,
  ddl text,
  upgrade_sql text,
  PRIMARY KEY (id),
  UNIQUE dbix_class_deploymenthandler_versions_version (version)
);

;
SET foreign_key_checks=1;

;
ALTER TABLE clients CHANGE COLUMN last_registered last_registered timestamp NOT NULL DEFAULT current_timestamp;

;
ALTER TABLE statistics DROP COLUMN client_name,
                       DROP COLUMN client_location,
                       ADD COLUMN clientname varchar(255) NOT NULL,
                       CHANGE COLUMN when when timestamp NOT NULL DEFAULT current_timestamp;

;
ALTER TABLE users ADD COLUMN test1 integer NOT NULL,
                  ADD COLUMN test2 integer NOT NULL;

;

COMMIT;

