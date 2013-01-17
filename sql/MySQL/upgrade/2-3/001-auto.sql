-- Convert schema '/home/libki/Libki/script/utilities/../../sql/_source/deploy/2/001-auto.yml' to '/home/libki/Libki/script/utilities/../../sql/_source/deploy/3/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE clients CHANGE COLUMN last_registered last_registered timestamp;

;
ALTER TABLE statistics DROP COLUMN clientname,
                       ADD COLUMN client_name varchar(255) NOT NULL,
                       ADD COLUMN client_location varchar(255),
                       CHANGE COLUMN when when timestamp;

;
ALTER TABLE users DROP COLUMN test1,
                  DROP COLUMN test2;

;
DROP TABLE dbix_class_deploymenthandler_versions;

;

COMMIT;

