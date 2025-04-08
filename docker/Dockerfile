# Libki Kiosk Management System
# Copyright (C) 2018 Kyle M Hall <kyle@kylehall.info>
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

# Start with the previous image for speed,
# it has all the dependencies installed already
FROM bitnami/minideb:bullseye

LABEL maintainer="Kyle M Hall <kyle@kylehall.info>"

ENV LIBKI_SERVER_PORT 3000
ENV LIBKI_MAX_WORKERS 4

# Install needed packages
RUN install_packages \
    imagemagick \
    curl \
    build-essential \
    perl \
    cpanminus \
    libdbd-mysql-perl \
    libimage-magick-perl \
    # for cpanm --installdeps .
    libmodule-install-perl \
    # for DBD::mysql
    default-libmysqlclient-dev \
    # Net::CUPS
    libcups2-dev \
    libcupsfilters-dev \
    # Needed to count pages in encrypted PDFs
    poppler-utils \
    # Print uploads filetype detection
    shared-mime-info \
    # For cli access to the database
    mariadb-client \
    # for https support in PDF conversion services
    liblwp-protocol-https-perl

RUN sed -i '/disable ghostscript format types/,+6d' /etc/ImageMagick-6/policy.xml

COPY . /app
WORKDIR /app

RUN cpanm -n --installdeps . && rm -rf /root/.cpanm

COPY docker/files/log4perl.conf /app/log4perl.conf
COPY docker/files/libki_local.conf /app/libki_local.conf
COPY docker/files/bashrc /root/.bashrc

ENV PERL5LIB /app/lib

CMD ./installer/update_db.pl && plackup -s Gazelle --port ${LIBKI_SERVER_PORT} --max-reqs-per-child 50000 --max-workers ${LIBKI_MAX_WORKERS} -E production -a /app/libki.psgi
