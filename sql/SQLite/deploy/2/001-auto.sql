-- 
-- Created by SQL::Translator::Producer::SQLite
-- Created on Thu Nov  8 13:23:49 2012
-- 

;
BEGIN TRANSACTION;
--
-- Table: clients
--
CREATE TABLE clients (
  id INTEGER PRIMARY KEY NOT NULL,
  name varchar(255) NOT NULL,
  location varchar(255),
  last_registered timestamp NOT NULL DEFAULT current_timestamp
);
CREATE UNIQUE INDEX name ON clients (name);
--
-- Table: dbix_class_deploymenthandler_versions
--
CREATE TABLE dbix_class_deploymenthandler_versions (
  id INTEGER PRIMARY KEY NOT NULL,
  version varchar(50) NOT NULL,
  ddl text,
  upgrade_sql text
);
CREATE UNIQUE INDEX dbix_class_deploymenthandler_versions_version ON dbix_class_deploymenthandler_versions (version);
--
-- Table: roles
--
CREATE TABLE roles (
  id INTEGER PRIMARY KEY NOT NULL,
  role text
);
--
-- Table: sessions
--
CREATE TABLE sessions (
  client_id integer NOT NULL,
  user_id integer NOT NULL,
  status enum NOT NULL DEFAULT 'active',
  PRIMARY KEY (client_id, user_id),
  FOREIGN KEY(client_id) REFERENCES clients(id),
  FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE INDEX sessions_idx_client_id ON sessions (client_id);
CREATE INDEX sessions_idx_user_id ON sessions (user_id);
CREATE UNIQUE INDEX client_id ON sessions (client_id);
CREATE UNIQUE INDEX user_id ON sessions (user_id);
--
-- Table: settings
--
CREATE TABLE settings (
  name varchar(255) NOT NULL,
  value varchar(255) NOT NULL,
  PRIMARY KEY (name)
);
--
-- Table: statistics
--
CREATE TABLE statistics (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  clientname varchar(255) NOT NULL,
  action enum NOT NULL,
  when timestamp NOT NULL DEFAULT current_timestamp
);
--
-- Table: user_roles
--
CREATE TABLE user_roles (
  user_id integer NOT NULL DEFAULT 0,
  role_id integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY(role_id) REFERENCES roles(id),
  FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE INDEX user_roles_idx_role_id ON user_roles (role_id);
CREATE INDEX user_roles_idx_user_id ON user_roles (user_id);
--
-- Table: users
--
CREATE TABLE users (
  id INTEGER PRIMARY KEY NOT NULL,
  username varchar(255) NOT NULL,
  password TEXT NOT NULL,
  minutes integer NOT NULL DEFAULT 0,
  status varchar(255) NOT NULL,
  notes text NOT NULL,
  message text NOT NULL,
  is_troublemaker enum NOT NULL DEFAULT 'No',
  is_guest enum NOT NULL DEFAULT 'No',
  test1 integer NOT NULL,
  test2 integer NOT NULL
);
CREATE UNIQUE INDEX username ON users (username);
COMMIT