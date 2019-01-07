-- Foreign keys to login_sessions, need to survive deletion of login_sessions rows, so no constraint implemented
ALTER TABLE `sessions` ADD COLUMN `session_id` CHAR(72) NULL DEFAULT NULL;
