$dbh->do(q|
  ALTER TABLE `users`
    ADD `firstname` varchar(255) DEFAULT '',
    ADD `lastname`  varchar(255) DEFAULT '',
    ADD `category`  varchar(255) DEFAULT '';
|);
