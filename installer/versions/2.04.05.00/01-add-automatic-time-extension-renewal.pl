$dbh->do(q|
    INSERT IGNORE INTO settings (instance, name, value ) SELECT DISTINCT(instance), 'AutomaticTimeExtensionRenewal', 0 FROM settings;
|);
