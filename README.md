# Libki Server

## Issues and bugs
If you have issues, please file them on the GitHub Libki server [bug tracker](https://github.com/Libki/libki-server/issues)

## For Developers
GitHub is currently the canonical source for Libki source code. Please make all pull requests through GitHub.

## Installation

### Create a user

For this basic, single instance installation, we will create a user named 'libki'

```bash
sudo adduser libki
```

### Install needed packages

```bash
sudo apt-get install curl perl git make build-essential 
```

### Download and install Libki and needed Perl modules

We will use local::lib for our installation, this means that all the Perl modules we need will be installed for the 'libki' user and will not affect any Debian installed Perl modules!

* Log in as that user
* Install cpanminus and local::lib
```bash
curl -L http://cpanmin.us | perl - -l ~/perl5 App::cpanminus local::lib
eval `perl -I ~/perl5/lib/perl5 -Mlocal::lib=~/perl5`
echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >> ~/.bashrc
```
* Install Module::Install
```bash
cpanm Module::Install
cpanm Module::Install::Catalyst
````
* Clone the Libki server git repository
```bash
git clone https://github.com/Libki/libki-server.git
```
* Enter the libki-server directory
```bash
cd libki-server
````
* Run the makefile script
```bash
perl Makefile.PL
make install
```
### Install and configure MySQL for Libki
* Install the mysql-server Debian package
```bash
sudo apt-get install mysql-server
```
* Create the Libki database
```sql
mysql -uroot -p
CREATE DATABASE libki;
CREATE USER 'libki'@'localhost' IDENTIFIED BY 'YOURPASSWORDHERE';
GRANT ALL PRIVILEGES ON libki.* TO 'libki'@'localhost';
FLUSH PRIVILEGES;
exit
```
* Copy of the example config file and edit it
```bash
sudo cp libki_local.conf.example libki_local.conf
sudo nano libki_local.conf
```
Change the database name, user and password to what you previously have specified. Enable or disable SIP by changing the parity bit.
* Run the database installer/updater
```bash
./installer/update_db.pl
```
This fills the Libki database with the necessary tables and other information.
* Create a superadmin user to log in to Libki as
```bash
./script/administration/create_user.pl -u *LIBKIADMINNAME* -p *LIBKIADMINPASSWORD* -s -m 999
```
This creates the Libki administrator. It also sets a password and minutes the user has. The login minutes must be given, but are irrelevant for an admin.
### Set up your init script
* Copy the init script template to init.d
```bash
sudo cp /home/libki/libki-server/init-script-template /etc/init.d/libki
sudo chmod +x /etc/init.d/libki
sudo update-rc.d libki defaults
```
The first line copies the file, the second makes it executable, and the final line tells your server to start at boot.
If you’ve followed the instructions closely so far, the init script should work out of the box for you.
By default, Libki is run via Starman as the backend, but you can switch to Gazelle by commenting the line enabling Starman and uncommenting the line enabling Gazelle. With a little modification it would be possible to use other backends as well, such as Starlet.
Starman is a very mature PSGI backend, whereas Gazelle is newer but appears to be higher performance.

### Set up your reverse proxy
* Install Apache
```bash
sudo apt-get install apache2
```
* Remove the default config
```bash
sudo rm /etc/apache2/sites-enabled/000-default.conf
```
* Create the file /etc/apache2/sites-available/libki.conf
```bash
sudo nano /etc/apache2/sites-available/libki.conf
```
Copy and paste the following into it:
```apache
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
<VirtualHost *:80>
    ServerName server.libki.org
    DocumentRoot /home/libki/libki-server
    <Proxy *>
        Order deny,allow
        Allow from allow
    </Proxy>
    ProxyPass        / http://localhost:3000/ retry=0
    ProxyPassReverse / http://localhost:3000/ retry=0
</VirtualHost>
```
Change server.libki.org to your actual domain
* Save and close the file
* Enable your new Libki config file
```bash
sudo a2ensite libki
```
* Enable mod_proxy and mod_proxy_http
```bash
sudo a2enmod proxy
sudo a2enmod proxy_http
```
* Restart apache
```bash
sudo service apache2 restart
```
### Set up the Libki cron jobs
```bash
sudo su - libki
crontab -e
```
Add in the following lines:
```
* * * * * perl ~/libki-server/script/cronjobs/libki.pl
0 0 * * * perl ~/script/cronjobs/libki_nightly.pl
```
The script libki.pl is run every minute and decrements logged in user's time among other tasks.
The second script, libki_nightly.pl, is run once per night to reset each user's allotted time for the day as well as other cleanup tasks.

* Set up automatic restarter
If you wish to have the Libki server restart itself in the case it dies for some reason, we can add an automatic restarter to the root user’s crontab
```bash
sudo su -
crontab -e
```
Add the following lines
```
* * * * * /etc/init.d/libki start
```

### Start Libki
```bash
sudo /etc/init.d/libki start
```

You can check to see if the daemon is running via
```bash
ps aux | grep libki
```

You should see a line similar to the following:
```bash
root     28326  0.0  0.3  10932  7132 ?        S    09:56   0:00 /usr/bin/perl /home/libki/perl5/bin/start_server --daemonize --port 3000 --pid-file /home/libki/libki.pid --status-file /home/libki/libki.status --log-file /home/libki/libki_server.log -- /home/libki/perl5/bin/plackup -I /home/libki/Libki/lib -I /home/libki/perl5/lib/perl5/ -s Starman --workers 2 --max-requests 50000 -E production -a /home/libki/Libki/libki.psgi
```

### Troubleshooting

You can now test to see if your server is running by using the cli web browser 'links'. If you don't have links installed you can installed it via the command
```bash
sudo apt-get install links
```
Now, open the Libki public page via:
```bash
links 127.0.0.1:80
```
If this loads the Libki login page, congrats! If you get an error, you can try bypassing the proxy and access the server directly on port 3000
```bash
links 127.0.0.1:3000
```

If this works, then you'll want to check your Apache error logs for the failure reason. If it does not work, you'll want to check the Libki server error log instead. It can be found at /home/libki/libki_server.log if you've followed this tutorial closely.

Authors:
Kyle M Hall kyle@kylehall.info
Christopher Vella, Commissioned by Calyx
