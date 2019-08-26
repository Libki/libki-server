#!/bin/bash

echo

if [[ $EUID -ne 0 ]]; then
  echo "This utility must be run as root."
  echo
  exit 1
fi

### Help text ###

function welcome {
  echo "Welcome to the Libki Server Update Utility"
  echo "------------------------------------------"
  echo
}

function helptext {
  welcome

  echo "This will update your Libki Server installation."
  echo
  echo "If used without a flag, the program will run in an interactive default."
  echo
  echo "Flags"
  echo
  echo "    --help, -h        This help text"
  echo "    --silent, -s      Run the program non-interactively."
  echo "                      It will automatically install the latest update."
  echo "                      This is for when running automatic updates."
  echo
}

### Main function ###

function updater () {
  welcome

  echo "This will temporarily make your server unavailable, so it's best to run it while no clients are in use."
  echo
  echo "Do you wish to update your current server?"

  if ! { [ "$1" == "-s" ] || [ "$1" == "--silent" ]; }
  then
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
    done
  fi

  ## Stop service
  service libki stop

  whileCounter=1

  # Wait for the service to stop
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

  dbVersion=r$(mysql libki -N -e "SELECT value FROM settings WHERE name='Release';")

  # If there's no Release in the database, set it to 19.08
  # (latest release without Release)
  if [ $dbVersion == "r" ]
  then
    mysql libki -e "INSERT INTO settings VALUES ('', 'Release', '19.08');"
    dbVersion=r$(mysql libki -N -e "SELECT value FROM settings WHERE name='Release';")
  fi

  possibleOnlineVersion=r$(date +%y.%m)

  declare -a availableOnlineVersions

  # Setup version comparison
  oldIFS=$IFS
  IFS="."

  read -ra ONLINE <<< $possibleOnlineVersion
  read -ra DB <<< $dbVersion

  IFS=$oldIFS

  oy=${ONLINE[0]}
  oy=${oy#?}
  om=${ONLINE[1]}
  online=$oy$om

  dy=${DB[0]}
  dy=${dy#?}
  dm=${DB[1]}
  db=$dy$dm

  # Version comparison
  if (( $db==$online ))
  then
    echo
    echo "The latest release is already installed!"
    echo
    exit 0
  fi

  echo
  echo "Backing up your current server..."
  libki-backup

  echo "Checking for updates..."
  echo

  # Get available online versions
  while (( $db < $online ))
  do
    # Increase dbVersion with one month before checking if that release is available
    if [[ $dm == "0"* ]]
    then
      dm=${dm#?}
    fi

    dm=$((dm+1))

    if (( $dm == 13 ))
    then
      dm=1
      dy=$((dy+1))
    fi

    if (( $dm < 10 ))
    then
      dm=0$dm
    fi

    checkOnlineVersion=r$dy.$dm

    # Check if dbVersion + 1 month exists in the github archive
    if ( wget -T 10 -O/dev/null -q https://github.com/Libki/libki-server/archive/$checkOnlineVersion.tar.gz )
    then
      availableOnlineVersions+=($checkOnlineVersion)
    fi

    # Update comparison value for next loop run
    db=$dy$dm
  done

  echo "The following versions are available for download."
  echo
  echo "You can check the changelog for every version at"
  echo "https://github.com/Libki/libki-server/releases"
  echo

  for version in "${availableOnlineVersions[@]}"
  do
    echo "Version: "$version
  done

  echo
  echo "Which version would you like to update to?"
  echo

  chosenVersion=0

  mkdir -p /tmp/libkiupdate

  if ! { [ "$1" == "-s" ] || [ "$1" == "--silent" ]; }
  then
    select option in ${availableOnlineVersions[@]}
    do
      case $option in
        $option)
          wget -q https://github.com/Libki/libki-server/archive/$option.tar.gz -O /tmp/libkiupdate/download.tar.gz
          chosenVersion=$option
          break
          ;;
        *)
          echo "That's an invalid choice."
          ;;
      esac
    done
  else
    wget -q https://github.com/Libki/libki-server/archive/${availableOnlineVersions[-1]}.tar.gz -O /tmp/libkiupdate/download.tar.gz
    chosenVersion=${availableOnlineVersions[-1]}
  fi

  # Download the update, unpack it,
  # copy it over the old server files, update db and perl modules
  # and finally replace the init script
  cd /tmp/libkiupdate
  tar -xzf download.tar.gz
  mv libki-server* libki-server
  cp -r libki-server /home/libki/
  chown -R libki:libki /home/libki/libki-server
  cd /home/libki/libki-server
  perl -X installer/update_db.pl
  cpanm -n --installdeps .

  port=$(sed -n '/PORT=/p' /etc/init.d/libki)
  port=$(echo $port | tr -d -c 0-9)

  cp /home/libki/libki-server/init-script-template /etc/init.d/libki
  sed -i "s/3000/$port/g" /etc/init.d/libki
  systemctl daemon-reload

  # Update Release in db to the new release
  chosenVersion=${chosenVersion#?}
  echo "UPDATE settings SET value = '$chosenVersion' WHERE name='Release';" > tmp.sql
  mysql libki < tmp.sql
  rm tmp.sql

  # Remove update files
  cd ~/
  rm -rf /tmp/libkiupdate

  #Start service again
  service libki start
  while (( $(ps -ef | grep -v grep | grep "libki" | wc -l) == 0 ))
  do
    sleep 1
  done


  echo
  echo "Congratulations!"
  echo "The Libki Server is now updated to version r$chosenVersion."
  echo

  cp /home/libki/libki-server/script/utilities/backup.sh /usr/local/bin/libki-backup
  cp /home/libki/libki-server/script/utilities/restore.sh /usr/local/bin/libki-restore
  cp /home/libki/libki-server/script/utilities/translate.sh /usr/local/bin/libki-translate
  cp /home/libki/libki-server/script/utilities/update.sh /usr/local/bin/libki-update
}

##### PROGRAM #####

### FLAG HANDLING ###

while [ ! $# -eq 0 ]; do
  case "$1" in
    --help | -h)
      helptext
      exit
      ;;
    --silent | -s)
      updater $1 >/dev/null
      exit
      ;;
    *)
      welcome

      echo "Use --help for instructions."
      echo
      exit 1
      ;;
  esac
  break
done

updater

exit 0
