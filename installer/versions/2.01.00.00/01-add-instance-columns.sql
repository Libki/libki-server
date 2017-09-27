ALTER TABLE client_age_limits
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);
ALTER TABLE client_age_limits DROP KEY unique_age_limits;
ALTER TABLE client_age_limits ADD UNIQUE KEY unique_age_limits (instance, client, comparison, age);

ALTER TABLE clients
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);
ALTER TABLE clients DROP KEY name;
ALTER TABLE clients ADD UNIQUE KEY name (instance, name);

ALTER TABLE closing_hours
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);

ALTER TABLE locations
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);
ALTER TABLE locations DROP KEY code;
ALTER TABLE locations ADD UNIQUE KEY unique_code (instance, code);

ALTER TABLE messages
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);

ALTER TABLE reservations
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);

-- Skipping roles, not real use of location there

ALTER TABLE sessions
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);

ALTER TABLE settings
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST;
ALTER TABLE settings
    DROP PRIMARY KEY,
    ADD PRIMARY KEY(instance, name);

ALTER TABLE statistics
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST,
    ADD INDEX (instance);

ALTER TABLE users
    ADD instance VARCHAR(32) NULL DEFAULT NULL FIRST;
ALTER TABLE users DROP KEY username;
ALTER TABLE users ADD UNIQUE KEY unique_username (instance, username);
