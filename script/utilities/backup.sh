#!/bin/bash

echo

if [[ $EUID -ne 0 ]]; then
  echo "This utility must be run as root."
  echo
  exit 1
fi

### VARIABLES, TEMP FILES AND FUNCTIONS

# Date and time in format YYMMDD_HH.MM
DATE=$(date +%y%m%d_%H.%M)

# Functions

function welcome {
  echo "Welcome to the Libki Server Backup Utility"
  echo "------------------------------------------"
  echo
}

function helptext {
  welcome

  echo "This will backup your server."
  echo
  echo "Backing up will temporarily shut down your server."
  echo "Don't run this while client computers are being in use."
  echo
}

function backup {
  # Stop the libki service
  service libki stop

  whileCounter=1

  # Check that service has stopped
  while (( $(ps -ef | grep -v grep | grep "libki" | wc -l) == 1 ))
  do
    if (( $whileCounter < 10 ))
    then
      sleep $whileCounter
      ((whileCounter++))
    else
      1>&2 echo "Unfortunately it wasn't possible to stop the Libki Server service."
      1>&2 echo "Please shut it down manually with 'service libki stop' and try again."
      echo
      exit 1
    fi
  done

  # Creates a backup folder if it doesn't exist
  mkdir -p /home/libki/backups

  # Create a tmp folder
  mkdir -p /tmp/libkibackup

  # Makes the database backup
  mysqldump libki > /tmp/libkibackup/db.sql

  # Backup the ini script
  cp /etc/init.d/libki /tmp/libkibackup/init

  # Makes the server backup
  cd /home/libki
  tar -pczf /tmp/libkibackup/libki-server.tar.gz libki-server

  # Merge the backups to one archive and move it to /home/libki/backups and remove the tmp folder
  cd /tmp/libkibackup
  tar -pczf /home/libki/backups/libki_backup_$DATE.tar.gz libki-server.tar.gz db.sql init
  cd ~
  rm -rf /tmp/libkibackup

  # Start the service again
  service libki start

  # Check that service has started
  while (( $(ps -ef | grep -v grep | grep "libki" | wc -l) == 0 ))
  do
    sleep 1
  done

  echo "Your Libki Server has been backed up to /home/libki/backups/libki_backup_$DATE.tar.gz"
  echo
}

### PROGRAM ###

### FLAG HANDLING ###

while [ ! $# -eq 0 ]; do
  case "$1" in
    --help | -h)
      helptext
      exit 0
      ;;
    --silent | -s)
      backup >/dev/null
      exit 0
      ;;
    *)
      welcome

      echo "Use --help for instructions."
      echo
      exit 0
      ;;
  esac
  break
done

backup

exit 0
