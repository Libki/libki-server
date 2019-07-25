#!/bin/bash

echo

### VARIABLES, TEMP FILES AND FUNCTIONS

# Date and time in format YYMMDD_HH.MM
DATE=$(date +%y%m%d_%H.%M)

# Fetch password from libki_local.conf
PASSLINE=$(sed -n '5p' < /home/libki/libki-server/libki_local.conf)

PASSWORD=${PASSLINE:18:-1}

# Creates a temp config file to suppress warning messages
{
  echo "[client]"
  echo "user = libki"
  echo "password = $PASSWORD"
} >> /home/libki/mysql_tmp.cnf

# Functions

function helptext {
  echo "Welcome to the Libki Server Database Backup."
  echo
  echo "This will restore backup your database."
  echo
  echo "If used without a flag, the program will run in an interactive default."
  echo
  echo "Flags"
  echo
  echo "    --help, -h        This help text"
  echo "    --silent, -s      Run the program non-interactively."
  echo "                      This is for when running automatic backups."
  echo
}

### FLAG HANDLING ###

while [ ! $# -eq 0 ]; do
  case "$1" in
    --help | -h)
      helptext
      exit
      ;;
    --silent | -s)
      # See program code further down for comments
      mkdir -p /home/libki/backups
      mysqldump --defaults-extra-file=/home/libki/mysql_tmp.cnf libki > /home/libki/backups/db_$DATE.sql
      rm /home/libki/mysql_tmp.cnf
      exit
      ;;
    *)
      echo "Welcome to the Libki Server Database Backup."
      echo
      echo "Use --help for instructions."
      exit 1
      ;;
  esac
  shift
done

### PROGRAM ###

echo "Welcome to the Libki Server backup program"
echo
echo "It's best to run this before opening hours so all accounts have their correct time allotment."
echo
echo "Do you wish to make a backup of your current server?"

select ANSWER in "Yes" "No"; do
  case "$ANSWER" in
    Yes )
      break
    ;;
    No )
      exit 1
    ;;
    * )
      echo
      echo "You must choose 1 (Yes) or 2 (No)"
      continue
  esac
  break
done


# Creates a backup folder if it doesn't exist
mkdir -p /home/libki/backups

# Makes the backup
mysqldump --defaults-extra-file=/home/libki/mysql_tmp.cnf libki > /home/libki/backups/db_$DATE.sql

# Deletes the temp file
rm /home/libki/mysql_tmp.cnf

echo
echo "Your database has been backed up to /home/libki/backups/db_$DATE.sql"
echo

exit 0
