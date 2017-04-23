#!/bin/bash

(crontab -l ; cat /home/libki/libki-server/cron)| crontab -
