$dbh->do(q|
    INSERT IGNORE INTO settings ( instance, name, value )
    SELECT DISTINCT(instance), 'PrintJobRetentionDays', '0' FROM settings
|);
