# Libki Server

## Contributing

If you discover issues, please, add them to the GitHub Libki server [bug tracker](https://github.com/Libki/libki-server/issues).

GitHub is currently the canonical source for the Libki source code.
Please, make [pull requests](https://help.github.com/articles/about-pull-requests/) through GitHub.

## Getting started

### A Docker-based quick setup

* [Install Docker Engine.](https://docs.docker.com/engine/installation/)
* [Install Docker Compose.](https://docs.docker.com/compose/install/)

```bash
git clone https://github.com/Libki/libki-server.git
cd libki-server/
cp libki_local.conf.example libki_local.conf
patch <docker/libki_local.conf.patch
docker-compose up -d
docker-compose exec libki perl /libki/installer/update_db.pl
docker-compose exec libki perl /libki/script/administration/create_user.pl -u libkiadmin -p some_password -s -m 999
```

Visit `localhost:8080/administration` in your browser to log in as `libkiadmin` with the password `some_password`!

#### To start Libki later

If Libki stops for any reason, just re-launch the Docker containers.

```bash
cd libki-server/
docker-compose up -d
```

After the initial install, this command will only take a couple seconds.

## The more complete Docker-based setup

For this setup, the Libki source code will be copied into a global folder.

```
sudo mkdir -p /var/libki/app
sudo chown $USER:$USER /var/libki/app
git clone https://github.com/Libki/libki-server.git /var/libki/app
```

Before building the containers, update the configuration files.

In `libki_local.conf`, point to the Docker-ized MySQL database.

```
<connect_info>
  dsn  dbi:mysql:database=libki;host=libki_mysql
  ...
```

Make sure the MySQL credentials in `docker-compose.yml` match those in `libki_local.conf`.

Then launch the container and go get some coffee while it builds.

```
docker-compose up -d
```

If you're importing an existing database, do that now.

```
docker cp ./dump-of-libki.sql libki_mysql:/tmp/dbdump.sql
docker-compose exec mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -h localhost libki < /tmp/dbdump.sql'
```

Update the database, whether you imported or not.

```
docker-compose exec libki perl /libki/installer/update_db.pl
```

If you didn't import a database, create an admin user.

```
docker-compose exec libki perl /libki/script/administration/create_user.pl -u libkiadmin -p some_password -s -m 999
```

Now we are going to fine-tune our setup.

First setup Libki as a service, so we can use, `service libki [status|start|stop|restart]` to interact with Libki.
This init script expects the Libki project to be at `/var/libki/app`.

```
sudo cp docker/libki /etc/init.d/
sudo chmod 755 /etc/init.d/libki
sudo chown root:root /etc/init.d/libki
```

Next, have the system check every minute to make sure Libki is running, and start it if needed.
This cron script also expects the Libki project to be at `/var/libki/app`.

```
sudo cp docker/ensure_libki_running /etc/cron.d/
sudo chown root:root /etc/cron.d/ensure_libki_running
```

Finally, set an automatic backup to run each day at noon.
The backup files will be stored in `/var/libki`.

```
sudo cp docker/backup_libki /etc/cron.d/
sudo chown root:root /etc/cron.d/backup_libki
```

## Manual Installation

This guide is tested on Debian Jessie (8.7).

### Login as root

Start by switching your user to root if you're not already.

```bash
su
```

### Create a user

For this basic, single instance installation, we will create a user named 'libki'.

```bash
adduser libki
```

### Install needed packages

```bash
apt-get install curl perl git make build-essential unzip mysql-server pwgen -y
```

### Download and install Libki and needed Perl modules

We will use local::lib for our installation, this means that all the Perl modules we need will be installed for the 'libki' user and will not affect any Debian installed Perl modules!

* Log in as the libki user

```bash
su - libki
```

* Clone the Libki server git repository

```bash
git clone https://github.com/libki/libki-server.git
```

* Enter the libki-server directory

```bash
cd libki-server
```

* Setup log files, Perl and install Libki's Perl dependencies from CPAN

```bash
./script/setup/basic_setup.sh
```

Before you continue, log out of the libki user and log back in.
This makes sure Perl is functioning properly.
 

```bash
exit
su - libki
cd libki-server
```  

* Create the Libki database by running the setup script below

Enter your MySQL root password when prompted.

```bash
./script/setup/mysql_setup.sh
```

Write down that password - you will need it in a second.

* Open the config file and edit it

```bash
nano libki_local.conf
```

Change the password to what you got from the Mysql setup script. 

Enable or disable SIP by changing the parity bit. It's disabled by default, and if you're not connecting it to an ILS (integrated library system such as Koha) there's no need to change this.

* Run the database installer/updater

```bash
./installer/update_db.pl
```

This fills the Libki database with the necessary tables and other information.

* Create a superadmin user to log in to Libki as

```bash
./script/administration/create_user.pl -u *LIBKIADMINNAME* -p *LIBKIADMINPASSWORD* -s
```

This creates a Libki user, sets its password and makes it administrator.

### Set up your init script

First exit your libki user and go back to your root account.

```bash
exit
```

* Copy the init script template to /etc/init.d. This makes Libki run at boot.

```bash
cp /home/libki/libki-server/init-script-template /etc/init.d/libki
update-rc.d libki defaults
```

By default, Libki is run via Starman as the backend, but you can switch to Gazelle by commenting the line enabling Starman and uncommenting the line enabling Gazelle.
With a little modification it would be possible to use other backends as well, such as Starlet.
Starman is a very mature PSGI backend, whereas Gazelle is newer but appears to be higher performance.

### Set up the Libki cron jobs

* Switch back to the libki account, so you can setup the Libki cron jobs.

```bash
su - libki
cd libki-server
./script/setup/cronjob_setup.sh
```

* Now you're done as the libki user for a while.

```bash
exit
```

### Start Libki

```bash
service libki start
```

You can check to see if the daemon is running via

```bash
ps aux | grep libki
```

You should see a line similar to the following:

```bash
root     28326  0.0  0.3  10932  7132 ?        S    09:56   0:00 /usr/bin/perl /home/libki/perl5/bin/start_server --daemonize --port 3000 --pid-file /home/libki/libki.pid --status-file /home/libki/libki.status --log-file /home/libki/libki_server.log -- /home/libki/perl5/bin/plackup -I /home/libki/Libki/lib -I /home/libki/perl5/lib/perl5/ -s Starman --workers 2 --max-requests 50000 -E production -a /home/libki/Libki/libki.psgi
```

### OPTIONAL: Set up automatic restarter

If you wish to have the Libki server restart itself in the case it dies for some reason, we can add an automatic restarter to the root user’s crontab.

```bash
crontab -e
```

Add the following line

```
* * * * * /etc/init.d/libki start
```

At this point, the libki server setup is complete. You can go ahead and use it by visiting http://YOUR_SERVERS_IP_ADDRESS:3000/ now if you want to. 
If you, however, want to run it at port 80 (i.e. don't having to write in :3000 and simplify accessing a server that's not on your internal network and so on), You will want to setup a reverse proxy.

### OPTIONAL: Set up your reverse proxy

Make sure you're logged in as root. 

* Install Apache

```bash
apt-get install apache2
```

* Navigate to the libki-server directory

```bash
cd /home/libki/libki-server
```

* Run the apache_setup.sh script

This disables the old default conf, copies reverse_proxy.config to Apache's folder and enables both the Libki reverse proxy and the needed modules..

```bash
./script/setup/apache_setup.sh
```

* Restart apache

```bash
service apache2 restart
```

### Troubleshooting

You can now test to see if your server is running by using the cli web browser 'links'.
If you don't have links installed you can installed it via the command

```bash
sudo apt-get install links
```

Now, open the Libki public page via:

```bash
links 127.0.0.1:80
```

If this loads the Libki login page, congrats!
If you get an error, you can try bypassing the proxy and access the server directly on port 3000.

```bash
links 127.0.0.1:3000
```

If this works, then you'll want to check your Apache error logs for the failure reason.
If it does not work, you'll want to check the Libki server error log instead.
It can be found at /home/libki/libki_server.log if you've followed this tutorial closely.

### Documentation Authors

* Kyle M Hall kyle@kylehall.info
* Christopher Vella chris@calyx.net.au
* Luke Fritz ldfritz@gmail.com
* Erik Öhrn erik.ohrn@gmail.com
