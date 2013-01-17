-- Convert schema '/home/libki/Libki/script/developer_utilities/../../sql/_source/deploy/1/001-auto.yml' to '/home/libki/Libki/script/developer_utilities/../../sql/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;

;
ALTER TABLE users ADD COLUMN test1 integer NOT NULL,
                  ADD COLUMN test2 integer NOT NULL;

;

COMMIT;

