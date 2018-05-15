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

FROM debian:stretch-slim

MAINTAINER Kyle M Hall <kyle@kylehall.info>

# Install needed packages
RUN apt-get update -y \
    && apt-get -y install \
       git \
       vim \
       build-essential \
       perl \
       cpanminus \
# DBD::mysql
       default-libmysqlclient-dev \
# Net::Google::DataAPI::Auth::OAuth2
       libxml2-dev \
       libssl-dev \
       libexpat1-dev \
    && rm -rf /var/cache/apt/archives/* \
    && rm -rf /var/lib/api/lists/*

COPY . /app
WORKDIR /app

RUN cpanm -n Module::Install
RUN cpanm -n --installdeps .

COPY docker/files/log4perl.conf /app/log4perl.conf
COPY docker/files/libki_local.conf /app/libki_local.conf

ENV PERL5LIB /app/lib

CMD plackup -s Gazelle --port 3000 --max-reqs-per-child 50000 -E production -a /app/libki.psgi
