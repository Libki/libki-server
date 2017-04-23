#!/bin/bash
if [[ $EUID -ne 0 ]]; then
  echo "This must be run as root" 2>&1
  exit 1
else
  rm /etc/apache2/sites-enabled/000-default.conf
  cp /home/libki/libki-server/reverse_proxy.config /etc/apache2/sites-available/libki.conf
  a2ensite libki
  a2enmod proxy
  a2enmod proxy_http
fi

