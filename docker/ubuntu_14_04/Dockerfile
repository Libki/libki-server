# Libki Kiosk Management System
# Copyright (C) 2012  Kyle M Hall <kyle@kylehall.info>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# Pull base image
# ---------------
FROM ubuntu:14.04

# Maintainer
# ----------
MAINTAINER Anoop Vijayan <maniankara@gmail.com>

# Environment variables
ENV LIBKI_HOME=/home/libki

# Install needed packages
RUN apt-get update && apt-get install -y git-core mysql-server perl build-essential libdatetime-perl libdatetime-format-dateparse-perl git mysql-server

# Start some mandatory services
# RUN  update-rc.d mysql defaults

# Add the user and set the password
RUN useradd -d $LIBKI_HOME -m -p libki -s /bin/bash libki

# Support files
COPY *.sql *.tar.gz *.sh $LIBKI_HOME/

# Fetch the source
RUN su -c 'cd $LIBKI_HOME; git clone https://bitbucket.org/libki-kms/libki-server.git' libki

# Install CPAN and all necessary modules
RUN tar -zxvf $LIBKI_HOME/*.tar.gz

# MySQL libki setup
RUN /etc/init.d/mysql restart && mysql < $LIBKI_HOME/libki_mysql_root_setup.sql && mysql -u libki -plibki < $LIBKI_HOME/libki_mysql_setup.sql
RUN sed -e s/USERNAME/libki/g -e s/PASSWORD/libki/g $LIBKI_HOME/libki-server/libki_local.conf.example > $LIBKI_HOME/libki-server/libki_local.conf 

# Run libki scripts
RUN /etc/init.d/mysql restart && su -c 'cd $LIBKI_HOME/libki-server && perl ./installer/update_db.pl && ./script/administration/create_user.pl -u admin -p admin -s -m 999' libki 
CMD ["bash", "/home/libki/start.sh"]

# launch
#CMD ["su","-c","'$LIBKI_HOME/libki-server/script/libki_server.pl", "-p", "8810'", "libki"]
