#!/bin/sh

printf "\n$(date +"%Y-%m-%d %H:%M:%S")\tcontainer starting\n"
printf "$(date +"%Y-%m-%d %H:%M:%S")\tcron starting\n"
service rsyslog start
service cron restart
service anacron start
#cron -f &
printf "$(date +"%Y-%m-%d %H:%M:%S")\tweb server\n"
start_server --port 3000 \
             --pid-file /libki/libki.pid \
             --status-file /libki/libki.status \
             --log-file /libki/libki_server.log \
             -- plackup \
             -I /libki/lib \
             -s Starman \
             --workers 2 \
             --max-requests 50000 \
             -E production \
             -a /libki/libki.psgi
