-- Convert schema '/home/libki/Libki/script/developer_utilities/../../sql/_source/deploy/2/001-auto.yml' to '/home/libki/Libki/script/developer_utilities/../../sql/_source/deploy/1/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE clients CHANGE COLUMN last_registered last_registered timestamp;

;
ALTER TABLE statistics CHANGE COLUMN when when timestamp;

;
ALTER TABLE users DROP COLUMN test1,
                  DROP COLUMN test2;

;
DROP TABLE dbix_class_deploymenthandler_versions;

;

COMMIT;

