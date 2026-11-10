# Viewer validation

The initial contribution is a technical preview. Automated tests use synthetic contexts, database objects, API responses and RFB targets; they do not establish live-workstation approval behavior.

## Automated validation on 2026-10-30

Against upstream master `6acf2d1327efcae92fda3509163a9a1da54b99f2` plus this contribution:

- 34 Perl assertions passed, covering configuration, signatures, authorization, instance isolation, request headers, notice/audit failures and token output.
- Five gateway tests passed, including concurrent replay across worker processes.
- A real websockify process passed loopback handshake/rejection checks with a synthetic RFB target and no token URLs in captured logs.
- Chromium loaded the complete noVNC dependency tree; dialog checks passed for view-only mode, disconnect, cancellation during token fetch, switching clients and cancellation during module import.
- The administration template parsed, and both new Perl modules passed POD syntax and coverage checks.

These checks used an existing Libki runtime image for Perl dependencies and a freshly built gateway image. The full upstream Docker build/database integration workflow has not yet been run for this branch.

## Repeat the focused checks

From the repository root, with Libki's Perl dependencies installed:

~~~sh
prove -Ilib t/screen_viewer.t
~~~

Gateway tests use a real websockify process against a loopback fake RFB target and include concurrent nonce replay checks. Neither command connects to a workstation:

~~~sh
docker build -t libki-viewer:preview docker/screen-viewer
docker run --rm --network none -v "$PWD:/source:ro" --entrypoint python libki-viewer:preview -m unittest discover -s /source/t/screen_viewer -p test_gateway.py
docker run --rm --network none -v "$PWD:/source:ro" --entrypoint python libki-viewer:preview /source/t/screen_viewer/run_gateway_runtime.py
~~~

The browser check requires Python Playwright with Chromium, the installed noVNC assets, and compatible Bootstrap 4/jQuery assets named `jquery.js`, `bootstrap.js`, and `bootstrap-4.0.0.min.css`. Every browser request is intercepted; no workstation is accessed. The test loads the complete real noVNC module separately, then uses a synthetic RFB implementation to check the actual dialog's startup/close behavior.

~~~sh
python3 t/screen_viewer/browser_viewer.py . /path/to/test-assets
~~~

## Workstation acceptance before deployment

These checks have not been performed on a live workstation for this upstream adaptation:

- Accept a request and verify the intended demonstration screen appears.
- Reject a request and let another time out; neither may reveal the screen.
- Repeat on active, locked and logged-out desktops.
- Attempt keyboard, mouse, clipboard and file-transfer operations using the browser and a separate VNC test client; confirm endpoint restrictions.
- Check unauthorized direct connections are rejected by the workstation firewall.
- Confirm administrator/instance permissions, patron notices and database audit records in an actual Libki installation.
- Check HTTPS/origin handling and that token-bearing URLs do not appear anywhere in proxy or gateway logs.
- Verify nonce persistence after restart, clock synchronization, active-session shutdown and rollback.

Disabling the feature stops new requests, not existing viewing connections. See [security boundaries](SECURITY.md).
