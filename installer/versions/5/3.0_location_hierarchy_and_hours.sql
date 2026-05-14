ALTER TABLE locations
    ADD COLUMN parent_id INT(11) NULL AFTER id,
    ADD CONSTRAINT fk_locations_parent
        FOREIGN KEY (parent_id)
        REFERENCES locations(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE;

CREATE TABLE `location_hours` (
    `instance` varchar(32) NOT NULL DEFAULT '',
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `location_id` int(11) NOT NULL,
    `day_of_week` SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    `open_time` TIME NOT NULL,
    `close_time` TIME NOT NULL,
    `reservable` BOOLEAN DEFAULT FALSE,
    UNIQUE(location_id, day_of_week, open_time, close_time),
    PRIMARY KEY (`id`),
    CONSTRAINT fk_location_hours_location
        FOREIGN KEY (`location_id`)
        REFERENCES `locations`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
CREATE INDEX idx_hours_lookup ON location_hours(location_id, day_of_week);

CREATE TABLE `location_hours_exceptions` (
    `instance` varchar(32) NOT NULL DEFAULT '',
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `location_id` int(11) NOT NULL,
    `description` TEXT NULL,
    `service_date` DATE NOT NULL,
    `is_closed` BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(location_id, service_date),
    PRIMARY KEY (`id`),
    CONSTRAINT fk_location_hours_exceptions_location
        FOREIGN KEY (`location_id`)
        REFERENCES `locations`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);
CREATE INDEX idx_exception_lookup  ON location_hours_exceptions(location_id, service_date);

CREATE TABLE `location_hours_exception_intervals` (
    `instance` varchar(32) NOT NULL DEFAULT '',
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `exception_id` int(11) NOT NULL,
    `open_time` TIME NOT NULL,
    `close_time` TIME NOT NULL,
    `reservable` BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (`id`),
    CONSTRAINT fk_location_hours_exception_intervals_exception
        FOREIGN KEY (`exception_id`)
        REFERENCES `location_hours_exceptions`(`id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

ALTER TABLE `clients`
    ADD COLUMN location_id INT(11) NULL AFTER location,
    ADD CONSTRAINT fk_client_location
        FOREIGN KEY (location_id)
        REFERENCES locations(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE;

UPDATE clients c
LEFT JOIN locations l
  ON l.code = c.location
SET c.location_id = l.id;

ALTER TABLE `clients`
    DROP COLUMN location;

ALTER TABLE `allotments`
    ADD COLUMN location_id INT(11) NULL AFTER location,
    ADD CONSTRAINT fk_allotment_location
        FOREIGN KEY (location_id)
        REFERENCES locations(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE;

UPDATE allotments a
LEFT JOIN locations l
  ON l.code = a.location
SET a.location_id = l.id;

ALTER TABLE allotments
    DROP PRIMARY KEY,
    ADD COLUMN id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST,
    ADD UNIQUE KEY uq_allotments_user_location (
        user_id,
        location_id
    ),
    DROP COLUMN location;