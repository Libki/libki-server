# Staff Microsoft Entra single sign-on — draft contribution

Optional staff authentication for one Microsoft Entra workforce tenant.
When enabled, /administration/login starts Microsoft sign-in automatically.
An existing Microsoft browser session can provide SSO, subject to tenant policy.
Patron authentication is unchanged. No Libki client modification is required.

This is a proposal for upstream review. The deployment-specific version has been
used at Clinton Public Library, Iowa. This portable export includes additional
session and error-handling changes and has not had a live Entra acceptance test.
Deployment experience does not validate this exact export.

## Authorization

The OIDC dependency handles authorization-code exchange, state, nonce, PKCE S256,
signature, issuer, audience, timestamps and authorized-party validation.
Libki then requires the configured tenant ID, an object ID, and an explicit role
or configured group assignment. Email and display name never grant access.

| Entra app-role value | Libki roles | Purpose |
| --- | --- | --- |
| Libki.Staff | admin | Normal staff administration |
| Libki.Admin | admin, superadmin | Full administration |

Administrator assignments win when both levels match. Optional group IDs can
grant either level as well; leave them unset when using only app roles.
Group-overage claims without a matching app role are denied. No Microsoft Graph
group lookup is performed. An assigned guest in the configured tenant can qualify;
manage eligible identities through enterprise application assignments.

Accounts use entra-<object-id> in the current Libki instance. Their random initial
password is not provided to staff, and the administration password route rejects
that namespace. Local accounts are never converted into Entra accounts. Locally
disabled Entra accounts remain disabled. Managed admin and superadmin roles are
reconciled on sign-in, including removal of superadmin on downgrade. Other Libki
roles are unchanged.

## Prerequisites

Install dependencies using the project's cpanfile or Makefile.PL workflow and a
compatible Perl runtime. Tested here: Perl 5.40.1, Catalyst::Plugin::OIDC 1.05 and
OIDC::Client 1.08.

Use HTTPS, a fixed trusted staff hostname, and the existing server-side DBIC
session store. At the reverse proxy, reject unexpected Host values and replace
forwarding headers from untrusted clients; redirect URLs use the request base.
Set secure, HttpOnly session cookies and a SameSite policy compatible with the
authorization-code callback. Restrict database/session-store access. Disable
Catalyst/OIDC debug logging and exclude callback query strings and request bodies
from proxy/application access logs.

Outbound TLS access to Microsoft's discovery, signing-key and token endpoints is
required. Enabled startup needs discovery access; failure prevents startup.
Maintain a tested way to disable SSO and restart, as well as a local recovery
account, for outages that prevent startup.

## Entra registration

1. Register a **single-tenant** application in your workforce directory.
2. Add a **Web** redirect URI:
   https://staff.example.org/oidc/entra/callback
   using your trusted staff origin instead of the example. Use an exact URI;
   do not enable implicit token grants or public-client flows.
3. Define enabled user app roles with values **Libki.Staff** and **Libki.Admin**.
   Assign staff through the enterprise application's Users and groups page.
   Enable **Assignment required** as an additional restriction.
4. Create a client secret and inject its **value** into the server environment
   as **OIDC_ENTRA_SECRET**. Never commit it. Track expiration and rotate using
   your deployment's secret-management process.
5. Set your tenant and application IDs. Apply MFA and Conditional Access through
   tenant policy as appropriate. Libki does not independently enforce MFA.

Only openid, profile and email scopes are requested. This implementation does not
call Microsoft Graph or request offline_access.

References:
- [Register an application](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)
- [Define and assign app roles](https://learn.microsoft.com/en-us/entra/identity-platform/howto-add-app-roles-in-apps)
- [Group claims and app roles](https://learn.microsoft.com/en-us/security/zero-trust/develop/configure-tokens-group-claims-app-roles)
- [Catalyst OIDC integration](https://metacpan.org/pod/Catalyst::Plugin::OIDC)

## Settings

These are synthetic examples, not a usable tenant registration:

~~~text
LIBKI_ENTRA_ENABLED=1
LIBKI_ENTRA_TENANT_ID=11111111-2222-4333-8444-555555555555
LIBKI_ENTRA_CLIENT_ID=aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee
LIBKI_ENTRA_ADMIN_APP_ROLE=Libki.Admin
LIBKI_ENTRA_STAFF_APP_ROLE=Libki.Staff
~~~

Supply OIDC_ENTRA_SECRET separately. Optional group settings default to empty:

~~~text
LIBKI_ENTRA_ADMIN_GROUP_ID=
LIBKI_ENTRA_STAFF_GROUP_ID=
~~~

For group fallback, configure Entra to issue group object IDs in the ID token
and set the corresponding GUIDs. Prefer app roles to avoid group overage.
Invalid tenant/client/nonempty group IDs or missing required credentials fail
at startup. With LIBKI_ENTRA_ENABLED unset or false, normal local staff login
remains and no tenant registration is required.

The registration is process-wide, not per Libki instance. Keep the tenant fixed:
shadow usernames contain the object ID, not the tenant ID. A tenant migration
requires an account and role review. Local libki.conf settings can override
defaults; never add mocked identities or weaken OIDC verification in production.

## Sessions, logout and recovery

/administration/login/emergency keeps existing local password login available.
Protect those accounts under your password and access policy; this route is not
protected by Entra MFA or Conditional Access. Credentials are accepted through
POST. Recovery logins are audited.

The session ID changes at authentication. After a verified identity becomes a
Libki session, provider tokens and outstanding authorization state are removed.
The normal Libki inactivity timeout applies, and protected administration
requests end Entra sessions at the original ID-token expiration.

Entra role removal or account disable is **not continuous revocation**: an
existing session can persist until that boundary. Locally disabling an account
blocks its next Entra login; this export does not add a per-request database
disable check. For immediate revocation, invalidate affected Libki sessions.

Logout destroys the Libki session and shows a signed-out page. It does not sign
out of Microsoft globally. On shared computers, end the Microsoft browser
session separately; choosing Sign in again can reuse it.

The session helper clears the cached DBIC row delegate after ID rotation because
Session::Store::DBIC 0.14 retains the deleted row object. Compatibility with other
session-store versions merits upstream review.

## Validation and review boundaries

After installing dependencies, run from the repository root:

~~~sh
prove -l t/entra_authorization.t t/entra_config.t t/entra_sync.t t/entra_controller.t t/entra_oidc.t
~~~

Tests exercise configuration failures, role mapping, account collision/disable,
privilege downgrade, login/recovery/logout/expiry, and generic error handling.
Controller and provisioning tests use test doubles. OIDC tests use the actual
dependency with an ephemeral RSA key and synthetic metadata: valid and invalid
signatures, issuer, audience, nonce, timestamps, authorized party, PKCE and
unknown state. No network or real tenant credentials are needed.

Still required before adopting this exact export: live test-tenant sign-in and
callback with the deployed proxy, database session persistence across requests,
account/role changes, shared-browser logout, and identity-provider outage
recovery. These end-to-end behaviors are outside the automated tests.

## Export provenance

Prepared against upstream 6acf2d1327efcae92fda3509163a9a1da54b99f2.
Only selected server authentication changes were exported. No private Git
history, tenant configuration, production credentials, staff accounts, database
contents, logs, or City network configuration are included. Test identities,
email addresses and IP addresses are synthetic examples.

Compared with the deployed implementation, this export preserves disabled
accounts, removes raw provider-error diagnostics, consumes stored identities
once, bounds staff sessions to token expiry, requires POST for local credentials,
and adds a signed-out page. These adaptations also need maintainer acceptance.
The screen-viewer contribution is separate.
