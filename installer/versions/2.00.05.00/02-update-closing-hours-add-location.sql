ALTER TABLE closing_hours
    ADD location INT( 11 ) NULL DEFAULT NULL AFTER id,
    ADD INDEX ( location );

ALTER TABLE closing_hours ADD FOREIGN KEY ( location ) REFERENCES locations ( id ) ON DELETE CASCADE ON UPDATE CASCADE;

