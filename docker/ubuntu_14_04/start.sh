#!/bin/bash

/etc/init.d/mysql restart
su -c "perl $LIBKI_HOME/libki-server/script/libki_server.pl -p 8810" -l libki
