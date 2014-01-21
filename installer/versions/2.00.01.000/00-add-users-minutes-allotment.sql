# Defines a 'total mintues' amount as compared to a 'session' minutes amount for users.minutes
ALTER TABLE users ADD minutes_allotment int(11) DEFAULT 0 AFTER password;

# Create the new setting DefaultSessionTimeAllowance and give it the same amount as DefaultTimeAllowance
# to retain existing functionality.
INSERT IGNORE INTO settings ( name, value ) SELECT 'DefaultSessionTimeAllowance', value FROM settings WHERE name = 'DefaultTimeAllowance';

# Update the version
UPDATE settings SET value = '2.00.01.000' WHERE name = "Version";
