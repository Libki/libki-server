#!/bin/bash

PASS=`pwgen -B 8 1`

mysql -uroot -p <<MYSQL_SCRIPT
CREATE DATABASE libki;
CREATE USER 'libki'@'localhost' IDENTIFIED BY '$PASS';
GRANT ALL PRIVILEGES ON libki.* TO 'libki'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

cp /home/libki/libki-server/libki_local.conf.example /home/libki/libki-server/libki_local.conf

echo "MySQL user and database created."
echo "Database:   libki"
echo "Username:   libki"
echo "Password:   $PASS"
