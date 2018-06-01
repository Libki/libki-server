#!/bin/bash

# Update and install packages
apt-get update
apt-get upgrade -y
apt-get install sudo openssl curl perl git make build-essential unzip mysql-server pwgen ntp libmysqlclient-dev libxml-parser-perl libxml-libxml-perl cpanminus -y

# Auto-created passwords
USERPASS=$(pwgen -B 8 1)
DBPASS=$(pwgen -B 8 1)

# Add libki user
useradd -m -p $(openssl passwd -1 $USERPASS) libki

# Copies the folder to /home/libki
mkdir /home/libki/libki-server
cp * /home/libki/libki-server -R
chown libki:libki /home/libki/libki-server -R

# Install cpan perl modules globally
cpanm -n Module::Install
cpanm -n --installdeps .

export PERL5LIB=$PERL5LIB:/home/libki/libki-server/lib

# Create log files, change ownership to libki
touch /var/log/libki/libki.log
touch /var/log/libki/libki_server.log

chown libki:libki /var/log/libki/libki.log
chown libki:libki /var/log/libki/libki_server.log

# Create libki database and database user
mysql <<MYSQL_SCRIPT
CREATE DATABASE libki;
CREATE USER 'libki'@'localhost' IDENTIFIED BY '$DBPASS';
GRANT ALL PRIVILEGES ON libki.* TO 'libki'@'localhost';
FLUSH PRIVILEGES
MYSQL_SCRIPT

# Edit config file to contain database password
sed -i "s/PASSWORD/$DBPASS/g" /home/libki/libki-server/libki_local.conf

# Install the database
perl /home/libki/libki-server/installer/update_db.pl

# Create administrator user
read -p "Creating the admin user for Libki. Please enter your desired username: " ADMINUSERNAME

while true; do
     read -s -p "Please enter your desired password: " ADMINPASSWORD
     echo
     read -s -p "Please enter your desired password again: " ADMINPASSWORD2
     echo
     [ "$ADMINPASSWORD" = "$ADMINPASSWORD2" ] && break
     echo "Your passwords did not match. Please try again."
done

perl /home/libki/libki-server/scripts/administration/create_user.pl -u $ADMINUSERNAME -p $ADMINPASSWORD -s

# Add the cronjobs
cat libkicron | crontab -u libki -
cat rootcron | crontab -


# Set up the Libki service and ask user for what port to run it on
cp /home/libki/libki-server/init-script-template /etc/init.d/libki

read -p "What port would you like to run Libki on? If you want to use a reverse proxy, this must be set to default. (Default is 3000) " -i "3000" -e PREFERREDPORT

sed -i "s/3000/$PREFERREDPORT/g" /etc/init.d/libki

update-rc.d libki defaults

# Reverse proxy setup
read -p "Would you like to set up a reverse proxy, so the Libki server can be accessed via a domain name rather than an IP adress? If you answer no, you will still be able to access the Libki server via the server's IP adress? " PROXYANSWER

case "$PROXYANSWER" in
  [yY][eE][sS]|[yY])

    # Install Apache
    apt-get install apache2 -y

    # Copy the config file
    rm /etc/apache2/sites-enabled/000-default.conf
    cp /home/libki/libki-server/reverse_proxy.config /etc/apache2/sites-available/libki.conf

    # Set domain name
    read -p "What domain name do you wish to use? " DOMAINNAME

    sed -i "s/libki.server.org/$DOMAINNAME/g" /etc/apache2/sites-available/libki.conf
    sed -i "s/3000/$PREFERREDPORT/g" /etc/apache2/sites-available/libki.conf

    # Enables the new site
    a2ensite libki
    a2enmod proxy
    a2enmod proxy_http
    ;;
  [nN][oO]|[nN])
    ;;
esac

# If proxy was setup, store domain. If not, store ip. Combine with PREFERREDPORT to a complete URL.
if [ -z ${DOMAINNAME} ]; then
  URL="http://$DOMAINNAME/administration"
else
  if [ $PREFERREDPORT="80" ]; then
    URL="http://localhost/administration"
  else
    URL="http://localhost:$PREFERREDPORT/administration"
  fi
fi

# Starting the Libki service
service libki start

# Starting the Apache service
if [ -z ${DOMAINNAME} ]; then
  service apache2 start
fi

# Report all settings
echo
echo "Congratulations!"
echo
echo "Your Libki server is now installed and up and running."
echo
echo "Here are all your settings. Be sure to write them down somewhere safe."
echo
echo "Your server username: libki"
echo "Your server password: $USERPASS"
echo
echo "Your database username: libki"
echo "Your database password: $DBPASS"
echo "Your database name: libki"
echo
echo "Your Libki administrator account username: $ADMINUSERNAME"
echo "Your Libki administrator account password: $ADMINPASSWORD"
echo
echo "Your log files are located in /var/log/libki/"
echo
echo "Your server can be reached on the following address:"
echo "$URL"
