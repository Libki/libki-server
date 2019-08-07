$dbh->do(q|
    INSERT IGNORE INTO settings (instance, name, value ) SELECT DISTINCT(instance), 'RenewTimeAllotment', 0 FROM settings;
|);
