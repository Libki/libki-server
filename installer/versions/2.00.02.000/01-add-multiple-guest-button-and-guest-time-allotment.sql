
# Create the new settings for creating multiple guests at one time 
# GuestBatchCount - The number of guests to create when the Multiple Guest button is clicked
# GuestPassFile - The path to save the text file containing guest passes for printing
# GuestPassLine1 - The text for the first line of the guest pass (followed by the username)
# GuestPassLine2  - The text for the second line of the guest pass (followed by the password)
INSERT IGNORE INTO settings ( name, value ) VALUES ('GuestBatchCount', 40);
INSERT IGNORE INTO settings ( name, value ) VALUES ('GuestPassFile', '/mnt/share/guestpasses.txt');
INSERT IGNORE INTO settings ( name, value ) VALUES ('GuestPassLine1',  'Your Library            Username=  ' );
INSERT IGNORE INTO settings ( name, value ) VALUES ('GuestBatchCount', 'Computer Guest Pass     Password=   ');

# Create two new settings to allow guests to default to a different time limit than users 
# and give them the same amount as DefaultTimeAllowance to retain existing functionality.
INSERT IGNORE INTO settings ( name, value ) SELECT 'DefaultGuestTimeAllowance', value FROM settings WHERE name = 'DefaultTimeAllowance';
INSERT IGNORE INTO settings ( name, value ) SELECT 'DefaultGuestSessionTimeAllowance', value FROM settings WHERE name = 'DefaultSessionTimeAllowance';

# Update the version
UPDATE settings SET value = '2.00.02.000' WHERE name = "Version";
