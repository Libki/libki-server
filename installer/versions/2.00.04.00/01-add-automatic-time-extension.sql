INSERT IGNORE INTO settings ( name, value ) VALUES ('AutomaticTimeExtensionLength', "");
INSERT IGNORE INTO settings ( name, value ) VALUES ('AutomaticTimeExtensionAt', "");
INSERT IGNORE INTO settings ( name, value ) VALUES ('AutomaticTimeExtensionUnless', 'this_reserved');

CREATE TABLE IF NOT EXISTS messages (
    id int(11) NOT NULL AUTO_INCREMENT,
    user_id int(11) NOT NULL,
    content text NOT NULL,
    PRIMARY KEY (id),
    KEY user_id (user_id)
) ENGINE=InnoDB;

ALTER TABLE messages
  ADD CONSTRAINT messages_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE;

# Update the version
UPDATE settings SET value = '2.00.04.000' WHERE name = "Version";
