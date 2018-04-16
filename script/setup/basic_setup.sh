#!/bin/bash

touch /home/libki/libki.log
touch /home/libki/libki_server.log

curl -L http://cpanmin.us | perl - -l /home/libki/perl5 App::cpanminus local::lib
eval `perl -I ~/perl5/lib/perl5 -Mlocal::lib=/home/libki/perl5`
echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >> /home/libki/.bashrc
cpanm -n Module::Install
cpanm -n --installdeps .
