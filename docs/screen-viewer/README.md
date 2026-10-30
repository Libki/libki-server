# Optional staff screen viewer (technical preview)

An administrator can select **View screen** for the configured workstation, choose a reason, and request a view-only browser connection. Libki queues a patron notice when there is an active session and records the request. The workstation VNC server must separately enforce local approval and reject input and file transfers.

The feature defaults to disabled. This initial contribution supports one explicitly configured workstation and Libki instance with a dedicated gateway. It adds no database migration. Existing installations retain their behavior until an administrator configures and enables it.

## Setup and boundaries

- [Installation](INSTALL.md): assets, endpoint controls, secrets, gateway, and reverse proxy.
- [Security boundaries](SECURITY.md): authorization, replay protection, transport, logging, and shutdown limits.
- [Validation](VALIDATION.md): repeatable automated checks and required workstation acceptance.

This server contribution is independent of the optional Windows client indicator. It includes no City deployment configuration, credentials, database records, or private repository history.

## Appearance

The preview request dialog uses demonstration data:

![Preview request dialog using demonstration data](https://raw.githubusercontent.com/jhansen123456/libkimods/aaa37ca302da9cb1566a09d891cbd21260d46c36/docs/images/staff-view-request-demo.png)

These two examples show the existing City deployment. Patron details are obscured; library branding and workstation names are retained with permission. That deployment has additional customizations and multiple workstations; these images illustrate appearance and do not show the exact scope or prove the consent configuration of this single-workstation preview.

![Staff sessions with View screen buttons](https://raw.githubusercontent.com/jhansen123456/libkimods/aaa37ca302da9cb1566a09d891cbd21260d46c36/docs/images/staff-sessions-view-screen.png)

![Empty public computer login screen inside the staff viewer](https://raw.githubusercontent.com/jhansen123456/libkimods/aaa37ca302da9cb1566a09d891cbd21260d46c36/docs/images/public-computer-login-in-viewer.png)

## Licenses

The new Libki server code, gateway plugin, and supporting scripts are AGPL-3.0-or-later. The optional runtime dependencies retain their own licenses: noVNC is principally MPL-2.0 with additional notices shipped by its asset installer, pako is MIT, and websockify is LGPL-3.0. The gateway image includes the websockify distribution and its license metadata.
