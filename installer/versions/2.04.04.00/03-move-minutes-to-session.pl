$dbh->do(q{
    ALTER TABLE sessions ADD COLUMN minutes int(11) NOT NULL DEFAULT 0 AFTER status;
});
$dbh->do(q{
    ALTER TABLE users DROP COLUMN minutes;
});
