# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
"""One-use, allow-listed token routing for the Libki screen viewer."""

import hashlib
import hmac
import os
import re
import time

from websockify.token_plugins import BasePlugin


CLIENT_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
NONCE_RE = re.compile(r"^[0-9a-f]{32}$")
SIGNATURE_RE = re.compile(r"^[0-9a-f]{64}$")


class LibkiTokenPlugin(BasePlugin):
    """Validate a short-lived HMAC token and return a fixed target.

    Targets are supplied by the operator at container start. The browser can
    select only an allow-listed client name; it can never provide a hostname
    or port. A nonce is consumed on first successful lookup to prevent replay.
    """

    def __init__(self, secret_path):
        super().__init__(secret_path)
        with open(secret_path, "rb") as secret_file:
            self._secret = secret_file.read().rstrip(b"\r\n")
        if not 32 <= len(self._secret) <= 4096:
            raise ValueError("viewer HMAC secret length is outside the allowed range")

        client_name = os.environ.get("LIBKI_VIEWER_CLIENT_NAME", "")
        target_host = os.environ.get("LIBKI_VIEWER_TARGET_HOST", "")
        target_port = os.environ.get("LIBKI_VIEWER_TARGET_PORT", "")
        if not CLIENT_RE.fullmatch(client_name):
            raise ValueError("invalid allow-listed viewer client name")
        if not re.fullmatch(r"(?:\d{1,3}\.){3}\d{1,3}", target_host):
            raise ValueError("viewer target must be an IPv4 address")
        octets = [int(value) for value in target_host.split(".")]
        if any(value > 255 for value in octets):
            raise ValueError("invalid viewer target IPv4 address")
        if not target_port.isdigit() or not 1024 <= int(target_port) <= 65535:
            raise ValueError("invalid viewer target port")

        self._targets = {client_name: (target_host, int(target_port))}
        nonce_dir = os.environ.get(
            "LIBKI_VIEWER_NONCE_DIR", "/tmp/libki-viewer-nonces"
        )
        if not os.path.isabs(nonce_dir) or len(nonce_dir) > 255:
            raise ValueError("viewer nonce directory must be an absolute path")
        os.makedirs(nonce_dir, mode=0o700, exist_ok=True)
        os.chmod(nonce_dir, 0o700)
        self._nonce_dir = nonce_dir

    def _consume_nonce(self, nonce, now):
        """Atomically consume a nonce across websockify worker processes."""
        stale_before = now - 120
        try:
            for entry in os.scandir(self._nonce_dir):
                if not NONCE_RE.fullmatch(entry.name):
                    continue
                try:
                    if entry.stat(follow_symlinks=False).st_mtime < stale_before:
                        os.unlink(entry.path)
                except FileNotFoundError:
                    pass

            nonce_path = os.path.join(self._nonce_dir, nonce)
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
            flags |= getattr(os, "O_NOFOLLOW", 0)
            nonce_fd = os.open(nonce_path, flags, 0o600)
            os.close(nonce_fd)
            return True
        except FileExistsError:
            return False
        except OSError:
            # Replay protection is a security boundary; fail closed if the
            # private tmpfs cannot atomically record the nonce.
            return False

    def lookup(self, token):
        try:
            client_name, expires_text, nonce, signature = token.rsplit(".", 3)
            if not CLIENT_RE.fullmatch(client_name):
                return None
            if not NONCE_RE.fullmatch(nonce) or not SIGNATURE_RE.fullmatch(signature):
                return None
            target = self._targets.get(client_name)
            if target is None:
                return None

            expires = int(expires_text)
            now = int(time.time())
            # Tokens are valid for one minute. Reject timestamps far in the
            # future even if signed, limiting damage from a clock mistake.
            if expires < now or expires > now + 90:
                return None

            payload = f"{client_name}.{expires}.{nonce}".encode("ascii")
            expected = hmac.new(self._secret, payload, hashlib.sha256).hexdigest()
            if not hmac.compare_digest(expected, signature):
                return None

            if not self._consume_nonce(nonce, now):
                return None

            return target
        except (AttributeError, TypeError, ValueError):
            return None
