# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Add basic prometheus metrics for counting sessions, clients and logins ( in addition to default metrics )

## [4.4.0] [r22.11]
### Added
- Add logging of actions of Admin Client API ( restart clients, turn off clients, modify time, etc )
- Added auto-release option for print management, can be set on a per-printer basis
- Log when a user or group of users is deleted
### Changed
- Move internet connectivity sites list to a server side setting

## [4.3.0] [r22.08]
### Added
- Client will now disable ability for patron to log in if the client is disabled from the server 
- Add Libki Print Manager support for print management
- Add setting to control if administrators can view user print job files
- Add ability to choose how to display user for first reservation
- Add installer for Debian Bullseye
- Add ability to select date and time format for display
- Hide option to turn on clients unless wake on lan mac address have been defined
- Add ability for patron to 'resume' a session they were in if the computer has crashed instead of logging out
- Add ability to auto-prefix cardnumbers entered by patrons
- Add client name to the 'Make reservation' dialog
- Add logging to database with built in log viewer
- Add ability to use a template for guess passes using Template Toolkit syntax
- Add automatic print dialog for batch guest passes
- Add ability to change both session and allotment minutes at the same time from the Clients table "Modify time" button
- Add the ability to send a Qt Style Sheet to the Libki client so it can be given custom styling easily
- Add ability to set custom text for Terms of Service on the message and in the "Show Details" section
- Libki server automatically redirects to login page when the patron is logged out via a timeout
- Add ability to select a printer at release time for web-based self service
- Added automatic dark mode. If your broswer is set to dark mode, Libki will honor it.
### Fixed
- Users getting incorrect session times when logging in before a reservation #210
- Fix age limit bug
- Disallow invalid hour/minute selections based on current sessions
- Fix ReservationShowDisabled = Disabled acting like ReservationShowDisabled = Anonymous
- Prevent SIP auth from deleting local users by checking the user's creation_source field
- Make completed print jobs selected printer updated in web print release if changed elsewhere
- Fixed closing hours calculation for automatic shutdown
- Make client behavior without reservations hide the reservation column, not the session minutes column
### Removed
- Removed Google Cloud Print support for print management

## [4.2.4] [r20.11]
### Added
- Add users.creation_source field to tell how a given user was created ( local, SIP, LDAP, etc )
- Add ability to have separate minutes allotments per-location for each user
- Add ability to remotely shutdown, restart, and wake-on-lan clients
- Add ability to set a gap between reservations to give librarians time to disinfect computers between uses
- Add Norwegian translation

### Changed
- Removed use of local unixtime for calculations, resolves issues where the server timezone differs from the Libki timezone
- Users can no longer delete themselves #162
- Add the possibility to use the client for sending wake on LAN packets
- Administrator can now place a reservation for a patron that's never been authenticated when using SIP #192

## [4.2.3] - 2020-05-28
### Added
- Add ability for a user to temporarily lock session. This feature is off by default and is enabled via a server setting. Requires Libki client 2.2.0 or later.

## [4.2.3] - 2020-05-28
### Changed
- Switch clients table to new DataTables api to reference columns by key/value in order to:
- Enable translation of client statuses ( Online, Offline, Suspended )

## [4.2.2] - 2020-05-28
### Changed
- Changed styling of the table toolbars

## [4.2.1] - 2020-05-28
### Added
- Add the ability to set a user category for guests.

## [4.2.0] - 2020-05-27
### Added
- Add ability to remotely log a Libki client in as a guest from the admin interface. Feature requires client version 2.1.0 or later.
### Changed
- Updated Swedish translation for the new remote unlock feature.

## [4.1.1] - 2020-05-27
### Changed
- Updated Swedish translation.

## [4.1.0] - 2020-05-20
### Added
- Add client status field. Rather than delete clients from the database when they no longer respond, the new client status field is set to "offline" which is functionally equivilent. Clients may also be suspended to take them out of use without shutting down the Libki client. New buttons have been added to toggle between suspended and online, and to delete offline clients permanently.

## [4.0.1] - 2020-05-06
### Added
- Add ability to set expiration for troublemaker setting, adds modal with build in notes editor ( for existing user notes ).
- Begin using semantic versioning for Libki Server ( version has been fixed at 0.01 since the move to Perl Catalyst ).
- Bump server version to 4.0.0 to indicate breaking changes with r19.08. Before this, Libki Server was considered to be on version 3 since the addition of multi-tenancy.
- Update install.sh to support Ubuntu 20.04
### Removed
- Removed the system setting GuestPassFile from the database, the feature hasn't existed for a long time now. It was replaced with the ability to print batch guest passes on demand directly from the web browser.

## [4.0.0] - 2020-05-05
### Changed
- Release last version of Libki Server 0.01 as part of Libki r20.05.
