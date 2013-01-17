-- Convert schema '/home/libki/Libki/script/utilities/../../sql/_source/deploy/3.00.00.00/001-auto.yml' to '/home/libki/Libki/script/utilities/../../sql/_source/deploy/2/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "dbix_class_deploymenthandler_versions" (
  "id" serial NOT NULL,
  "version" character varying(50) NOT NULL,
  "ddl" text,
  "upgrade_sql" text,
  PRIMARY KEY ("id"),
  CONSTRAINT "dbix_class_deploymenthandler_versions_version" UNIQUE ("version")
);

;
ALTER TABLE statistics DROP COLUMN client_name;

;
ALTER TABLE statistics DROP COLUMN client_location;

;
ALTER TABLE statistics ADD COLUMN clientname character varying(255) NOT NULL;

;
ALTER TABLE users ADD COLUMN test1 integer NOT NULL;

;
ALTER TABLE users ADD COLUMN test2 integer NOT NULL;

;
ALTER TABLE clients ALTER COLUMN last_registered SET NOT NULL
ALTER TABLE clients ALTER COLUMN last_registered SET DEFAULT current_timestamp;

;
ALTER TABLE statistics ALTER COLUMN when SET NOT NULL
ALTER TABLE statistics ALTER COLUMN when SET DEFAULT current_timestamp;

;

COMMIT;

