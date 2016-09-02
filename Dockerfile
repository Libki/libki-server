FROM perl:5.24

RUN apt-get update && apt-get -y install anacron cpanminus cron rsyslog

COPY cpanfile /tmp/
RUN cpanm -n --installdeps /tmp/

COPY docker/cron.minute /etc/cron.d/libkiminutes
COPY docker/cron.daily /etc/cron.daily/libkidailyreset
COPY docker/startup.sh /etc/

RUN chmod 644 /etc/cron.d/libkiminutes && chmod 755 /etc/cron.daily/libkidailyreset /etc/startup.sh

CMD ["/etc/startup.sh"]
