-- 
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Thu Nov  8 13:23:49 2012
-- 
;
--
-- Table: clients
--
CREATE TABLE "clients" (
  "id" serial NOT NULL,
  "name" character varying(255) NOT NULL,
  "location" character varying(255),
  "last_registered" timestamp DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "name" UNIQUE ("name")
);

;
--
-- Table: dbix_class_deploymenthandler_versions
--
CREATE TABLE "dbix_class_deploymenthandler_versions" (
  "id" serial NOT NULL,
  "version" character varying(50) NOT NULL,
  "ddl" text,
  "upgrade_sql" text,
  PRIMARY KEY ("id"),
  CONSTRAINT "dbix_class_deploymenthandler_versions_version" UNIQUE ("version")
);

;
--
-- Table: roles
--
CREATE TABLE "roles" (
  "id" serial NOT NULL,
  "role" text,
  PRIMARY KEY ("id")
);

;
--
-- Table: sessions
--
CREATE TABLE "sessions" (
  "client_id" integer NOT NULL,
  "user_id" integer NOT NULL,
  "status" character varying DEFAULT 'active' NOT NULL,
  PRIMARY KEY ("client_id", "user_id"),
  CONSTRAINT "client_id" UNIQUE ("client_id"),
  CONSTRAINT "user_id" UNIQUE ("user_id")
);
CREATE INDEX "sessions_idx_client_id" on "sessions" ("client_id");
CREATE INDEX "sessions_idx_user_id" on "sessions" ("user_id");

;
--
-- Table: settings
--
CREATE TABLE "settings" (
  "name" character varying(255) NOT NULL,
  "value" character varying(255) NOT NULL,
  PRIMARY KEY ("name")
);

;
--
-- Table: statistics
--
CREATE TABLE "statistics" (
  "id" serial NOT NULL,
  "username" character varying(255) NOT NULL,
  "clientname" character varying(255) NOT NULL,
  "action" character varying NOT NULL,
  "when" timestamp DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY ("id")
);

;
--
-- Table: user_roles
--
CREATE TABLE "user_roles" (
  "user_id" integer DEFAULT 0 NOT NULL,
  "role_id" integer DEFAULT 0 NOT NULL,
  PRIMARY KEY ("user_id", "role_id")
);
CREATE INDEX "user_roles_idx_role_id" on "user_roles" ("role_id");
CREATE INDEX "user_roles_idx_user_id" on "user_roles" ("user_id");

;
--
-- Table: users
--
CREATE TABLE "users" (
  "id" serial NOT NULL,
  "username" character varying(255) NOT NULL,
  "password" text NOT NULL,
  "minutes" integer DEFAULT 0 NOT NULL,
  "status" character varying(255) NOT NULL,
  "notes" text NOT NULL,
  "message" text NOT NULL,
  "is_troublemaker" character varying DEFAULT 'No' NOT NULL,
  "is_guest" character varying DEFAULT 'No' NOT NULL,
  "test1" integer NOT NULL,
  "test2" integer NOT NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "username" UNIQUE ("username")
);

;
--
-- Foreign Key Definitions
--

;
ALTER TABLE "sessions" ADD FOREIGN KEY ("client_id")
  REFERENCES "clients" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "sessions" ADD FOREIGN KEY ("user_id")
  REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "user_roles" ADD FOREIGN KEY ("role_id")
  REFERENCES "roles" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

;
ALTER TABLE "user_roles" ADD FOREIGN KEY ("user_id")
  REFERENCES "users" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE;

