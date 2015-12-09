INSERT IGNORE INTO settings ( name, value ) VALUES ('CustomJsAdministration', "");
INSERT IGNORE INTO settings ( name, value ) VALUES ('CustomJsPublic', "");

# Update the version
UPDATE settings SET value = '2.00.06.000' WHERE name = "Version";
