-- Convert schema '/home/libki/Libki/script/developer_utilities/../../sql/_source/deploy/2/001-auto.yml' to '/home/libki/Libki/script/developer_utilities/../../sql/_source/deploy/1/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE users DROP COLUMN test1;

;
ALTER TABLE users DROP COLUMN test2;

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

