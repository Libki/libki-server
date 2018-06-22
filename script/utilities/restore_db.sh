#!/bin/bash

echo

### VARIABLES, TEMP FILES AND FUNCTIONS ###

# Fetch password from libki_local.conf

PASSLINE=$(sed -n '5p' < /home/libki/libki-server/libki_local.conf)

PASSWORD=${PASSLINE:18:-1}

# Creates a temp config file to suppress warning messages
{
  echo "[client"]
  echo "user = libki"
  echo "password = $PASSWORD"
} >> /home/libki/mysql_tmp.cnf

# Create temp mysql script to avoid user input
{
  echo "DROP DATABASE libki;"
  echo "CREATE DATABASE libki;"
} >> /home/libki/mysql_tmp_script.sql

# Functions

function helptext {
  echo "Welcome to the Libki Server Database Restorer."
  echo
  echo "This will restore your database to the backup you choose."
  echo "It will therefore also delete your current database."
  echo
  echo "Usage:"
  echo "Run the program with the database backup of your choice"
  echo "as an argument."
  echo
  echo "Example: libki-restore /home/libki/backups/db_170422_17.53.sql"
  echo
  echo "Flags"
  echo "    -h, --help        This help text"
  echo
}

# If no file was passed as an argument
if [ -z "$1" ]; then
  echo "Welcome to the Libki Server Database Restorer."
  echo
  echo "Use --help for instructions."
  echo
  exit 1
fi

### FLAG HANDLING ###

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  helptext
  exit 0
fi

if [ $# -gt 1 ]; then
  echo "Welcome to the Libki Server Database Restorer."
  echo
  echo "You can only use one argument."
  echo
  echo
  exit 1
fi

# Some simple file checks
if [ ! -f "$1" ]; then
  echo "Welcome to the Libki Server Database Restorer."
  echo
  echo "The backup you selected doesn't exist. Please try again. Use --help for instructions."
  exit 1
fi

if [[ ! "$1" = *.sql ]]; then
  echo "Welcome to the Libki Server Database Restorer."
  echo
  echo "Your file doesn't seem to be a sql file. Please try again. Use --help for instructions."
  exit 1
fi

# Start of program
echo "Welcome to the Libki Server Database Restorer."
echo
echo "This will restore your database to the backup you choose."
echo "It will therefore also delete your current database."
echo
echo "Do you wish to continue?"

select ANSWER in "Yes" "No"; do
  case "$ANSWER" in
    Yes )
      break
      ;;
    No )
      exit 0
      ;;
    * )
      echo
      echo "You must choose 1 (Yes) or 2 (No)"
      continue
  esac
  break
done

# Run the temp mysql script
mysql --defaults-extra-file=/home/libki/mysql_tmp.cnf < /home/libki/mysql_tmp_script.sql

# Enter contents of backup into the db
mysql --defaults-extra-file=/home/libki/mysql_tmp.cnf libki < "$1"

# Remove temp files
rm /home/libki/mysql_tmp.cnf
rm /home/libki/mysql_tmp_script.sql

echo
echo "Your backup has now been entered into your Libki database."
echo

exit 0
