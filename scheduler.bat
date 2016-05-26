REM Schedules cronjobs

schtasks /create /sc minute /mo 1 /tn "Libki timer" /tr "C:\libki-server\win_scheduler\libki.bat" /ru System
schtasks /create /sc daily /st 00:00:00 /tn "Libki nightly" /tr "C:\libki-server\win_scheduler\libki_nightly.bat" /ru System
schtasks /create /sc onstart /tn "Libki server on boot" /tr "C:\libki-server\win_scheduler\libki_server.bat" /ru System

REM Adds log file

mkdir C:\home\libki\libki-server

copy /y nul C:\home\libki\libki-server\libki.log