# Security boundaries

## What this package checks

The token action requires a logged-in administrator from the requested Libki instance, a match to the explicitly configured viewer instance, an exact configured HTTPS Origin, a custom request header, an allowlisted client name, and a recognized reason. Requests fail without issuing a token if the patron notice or audit write fails.

The gateway verifies a signed HMAC token and a fixed configured target. A token expires 60 seconds after issuance and its nonce is consumed once across worker processes. Gateway clocks must be synchronized with Libki. The additional 90-second future-time bound limits accepted clock skew; it is not the configured token lifetime.

**Expiration limits connection startup, not viewing duration.** An accepted connection can remain open until it disconnects. Disabling the Libki feature, logging out of Libki, or changing the signing key does not revoke an already established connection.

The browser sets noVNC's view-only mode. Closing or replacing the dialog invalidates pending startup and disconnects its viewer.

## What the endpoint must enforce

The VNC server must independently require local approval, reject on timeout, reject remote keyboard/mouse input, disable file transfers, and accept network connections only from the gateway. This package cannot verify those settings from the web application.

An authorized administrator receives the view-only VNC password in the token response. Browser developer tools can reveal it. The password is not an authorization boundary against that administrator; network restrictions, the endpoint's view-only account, and local consent remain essential. Never reuse this password elsewhere.

No token mode bypasses consent in this public package. All reason choices use the same workflow.

## Transport and logs

Require HTTPS/WSS for staff browsers. Protect the gateway-to-VNC connection separately; classic RFB is not encrypted here. Never expose the raw gateway or VNC port publicly.

Tokens appear in WebSocket URLs. Suppress request URLs and raw-token errors at every proxy and gateway layer. Do not enable traffic recording or websockify debug logging. The included entry point disables websockify log output for this reason.

The application records staff identity, client name, reason, request time, session ID, and requester address in its database. Apply the site's normal access and retention rules to that operational audit. A request record is not proof of successful consent or a completed viewing session.

## Deployment limits

This preview supports one client mapping and one gateway instance. Persist nonce state across restarts; do not share an unsuitable filesystem or run independent gateway replicas that each accept the same nonce. Requests are not rate-limited by this patch; apply a suitable per-user or per-source request limit in your authenticated access layer to avoid repeated consent prompts.

Review dependency versions before deployment. Pinning improves reproducibility; it is not a promise that those versions are free of vulnerabilities.
