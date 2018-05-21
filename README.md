# Libki Server

## Contributing

If you discover issues, please, add them to the GitHub Libki server [bug tracker](https://github.com/Libki/libki-server/issues).

GitHub is currently the canonical source for the Libki source code.
Please, make [pull requests](https://help.github.com/articles/about-pull-requests/) through GitHub.

## Getting started

## Manual Installation

This guide is tested on Debian Jessie (8.10).

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

First, update and upgrade your server.
```bash
apt-get update
apt-get upgrade
```

Then, we'll install the needed packages.
```bash
apt-get install curl perl git make build-essential unzip mysql-server pwgen ntp -y
```

### Download and install Libki and needed Perl modules

We will use local::lib for our installation, this means that all the Perl modules we need will be installed for the 'libki' user and will not affect any Debian installed Perl modules!

* Log in as the libki user

```bash
su - libki
```

* Set up PERL5LIB

```bash
echo 'export PERL5LIB=$PERL5LIB:/home/libki/libki-server/lib' >> ~/.bashrc
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

* Set up logger

```bash
cp log4perl.conf.example log4perl.conf
nano log4perl.conf
```

Point the logger to the log file you'd like to use, and make sure it's writable.

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
### OPTIONAL: Configuring Libki to authenticate against a SIP server

To enable SIP authentication, you will need to edit your libki_local.conf and add a section like this:
```
<SIP>
    enable 1
    host ils.mylibrary.org
    port 6001
    location LIB
    username libki_sipuser
    password PassW0rd
    terminator CR
    require_sip_auth 0
    enable_split_messages 0
    fee_limit 5.00 # Can be either a fee amount, or a SIP2 field that defines the fee limit ( e.g. CC ), delete for no fee limit
    deny_on charge_privileges_denied    # You can set SIP2 patron status flags which will deny patrons the ability to log in
    deny_on recall_privileges_denied    # You can set as many or as few as you want. Delete these if you don't want to deny patrons.
    deny_on excessive_outstanding_fines # The full listing is defined in the SIP2 protocol specification
    deny_on_field AB:This is the reason we are daying you  # You can require arbitrary SIP fields to have a value of Y for patrons to be allowed to log in.
                                                           # The format of the setting is Field:Message
</SIP>
```

The SIP section requires the following parameters:
* enable: Set to 1 to enable SIP auth, 0 to disable it.
* host: The SIP server's IP or FQDN.
* port: The port that SIP server listens on.
* location: The SIP location code that matches the sip login.
* username: The username for the SIP account to use for transactions.
* password: The password for the SIP accouant to use for transactions.
* terminator: This is either CR or CRLF depending on the SIP server. Default is CR
* require_sip_auth: Does this SIP server require a message 93 login before it can be used? If so this should be set to 1 and the username/password fields should be populated. This should be set to 1 for Koha.
* enable_split_message: IF thie server supports split messages you can enable this. This should be set to 0 for Koha.
* fee_limit: As notated, this can be a set number or a SIP field to check. If the fee limit is exceeded, the user login will be denied.
* deny_on: This can be repeated to deny logins based on the patron information flags detailed in the SIP2 protocol specification.
* deny_on_field: This can be repeated to deny logins if the Specified field does not have a value of "Y".

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
