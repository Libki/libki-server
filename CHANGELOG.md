# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Add users.creation_source field to tell how a given user was created ( local, SIP, LDAP, etc )
- Add ability to have separate minutes allotments per-location for each user
- Add ability to remotely shutdown, restart, and wake-on-lan clients

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
