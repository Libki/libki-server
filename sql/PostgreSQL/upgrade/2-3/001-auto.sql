-- Convert schema '/home/libki/Libki/script/utilities/../../sql/_source/deploy/2/001-auto.yml' to '/home/libki/Libki/script/utilities/../../sql/_source/deploy/3/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE statistics DROP COLUMN clientname;

;
ALTER TABLE users DROP COLUMN test1;

;
ALTER TABLE users DROP COLUMN test2;

;
ALTER TABLE statistics ADD COLUMN client_name character varying(255) NOT NULL;

;
ALTER TABLE statistics ADD COLUMN client_location character varying(255);

;
ALTER TABLE clients ALTER COLUMN last_registered DROP NOT NULL
ALTER TABLE clients ALTER COLUMN last_registered DROP DEFAULT;

;
ALTER TABLE statistics ALTER COLUMN when DROP NOT NULL
ALTER TABLE statistics ALTER COLUMN when DROP DEFAULT;

;
DROP TABLE dbix_class_deploymenthandler_versions CASCADE;

;

COMMIT;

