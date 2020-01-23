#!/bin/bash

echo

if [[ $EUID -ne 0 ]]; then
  echo "This utility must be run as root."
  echo
  exit 1
fi

# Functions

function welcome {
  echo "Welcome to the Libki Server Restore Utility"
  echo "-------------------------------------------"
  echo
}

function helptext {
  welcome

  echo "This will restore your server installation to the backup you choose. Because of that, it will also delete your current server."
  echo
  echo "Usage:"
  echo "Run the program with the server backup of your choice as an argument."
  echo
  echo "Example: libki-restore /home/libki/backups/libki_backup_170422_17.53.tar.gz"
  echo
  echo "Flags"
  echo "    -h, --help        This help text"
  echo
}

# If no file was passed as an argument
if [ -z "$1" ]; then
  welcome

  echo "Use --help for instructions."
  echo
  exit 0
fi

### FLAG HANDLING ###

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  helptext
  exit 0
fi

if [ $# -gt 1 ]; then
  welcome

  echo "You can only use one argument."
  echo
  exit 1
fi

# Some simple file checks
if [ ! -f "$1" ]; then
  welcome

  echo "The backup you selected doesn't exist. Please try again. Use --help for instructions."
  echo
  exit 1
fi

if [[ ! "$1" = *.tar.gz ]]; then
  welcome

  echo "Your file doesn't seem to be a *.tar.gz file. Please try again. Use --help for instructions."
  echo
  exit 1
fi

# Start of program
welcome

echo "This will restore your server installation to the backup you choose. Because of that, it will also delete your current server."
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

# Stop the libki service
service libki stop

whileCounter=1

while (( $(ps -ef | grep -v grep | grep "libki" | wc -l) == 1 ))
do
  if (( $whileCounter < 10 ))
  then
    sleep $whileCounter
    whileCounter++
  else
    1>&2 echo "Unfortunately it wasn't possible to stop the Libki Server service."
    1>&2 echo "Please shut it down manually with 'service libki stop' and try again."
    echo
    exit 1
  fi
done

### Backup setup ###

# Make tmp folder and copy the backup there
mkdir -p /tmp/libkirestore
cd /tmp/libkirestore
cp $1 .

# Open the main tar
tar -pxzf $1

### Database restoration ###

# Create temp mysql script to avoid user input
{
  echo "DROP DATABASE libki;"
  echo "CREATE DATABASE libki DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
} >> /tmp/mysql_tmp_script.sql

# Run the temp mysql script
mysql < /tmp/mysql_tmp_script.sql

# Enter contents of backup into the db
mysql libki < db.sql

# Remove temp files
rm /tmp/mysql_tmp_script.sql

### Server restoration ###

# Remove /home/libki/libki-server and restore libki-server
rm -rf /home/libki/libki-server
tar -pxzf libki-server.tar.gz
mv libki-server /home/libki
chown -R libki:libki /home/libki/libki-server

### INIT RESTORATION ###
mv init /etc/init.d/libki
systemctl daemon-reload

# Delete the tmp folder
cd ~
rm -rf /tmp/libkirestore

# Start the service again
service libki start

# Wait for the service to start
while (( $(ps -ef | grep -v grep | grep "libki" | wc -l) == 0 ))
do
  sleep 1
done

echo
echo "Your backup has now been restored."
echo

exit 0
