#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
"""End-to-end WebSocket test for the Libki view-only gateway container."""

import base64
import hashlib
import hmac
import os
import socket
import struct
import time


HOST = os.environ.get("VIEWER_TEST_HOST", "127.0.0.1")
PORT = int(os.environ.get("VIEWER_TEST_PORT", "6080"))
SECRET_PATH = os.environ.get("VIEWER_TEST_SECRET", "/run/secrets/viewer-test")


def signed_token(secret, client, nonce):
    expires = int(time.time()) + 60
    payload = f"{client}.{expires}.{nonce}"
    signature = hmac.new(secret, payload.encode("ascii"), hashlib.sha256).hexdigest()
    return f"{payload}.{signature}"


def connect(token):
    connection = socket.create_connection((HOST, PORT), timeout=5)
    websocket_key = base64.b64encode(os.urandom(16)).decode("ascii")
    request = (
        f"GET /?token={token} HTTP/1.1\r\n"
        f"Host: {HOST}:{PORT}\r\n"
        "Connection: Upgrade\r\n"
        "Upgrade: websocket\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        f"Sec-WebSocket-Key: {websocket_key}\r\n"
        "Sec-WebSocket-Protocol: binary\r\n\r\n"
    )
    connection.sendall(request.encode("ascii"))
    response = b""
    while b"\r\n\r\n" not in response:
        chunk = connection.recv(4096)
        if not chunk:
            break
        response += chunk
    return connection, response


def read_binary_frame(connection, buffered):
    payload_buffer = buffered.split(b"\r\n\r\n", 1)[1]

    def read_exact(length):
        nonlocal payload_buffer
        while len(payload_buffer) < length:
            chunk = connection.recv(4096)
            if not chunk:
                raise AssertionError("WebSocket closed before the RFB banner arrived")
            payload_buffer += chunk
        value, payload_buffer = payload_buffer[:length], payload_buffer[length:]
        return value

    first, second = read_exact(2)
    assert first & 0x0F == 0x02, f"expected binary frame, got opcode {first & 0x0F}"
    assert second & 0x80 == 0, "server frames must not be masked"
    length = second & 0x7F
    if length == 126:
        length = struct.unpack("!H", read_exact(2))[0]
    elif length == 127:
        length = struct.unpack("!Q", read_exact(8))[0]
    return read_exact(length)


def assert_rejected(token, description):
    try:
        connection, response = connect(token)
    except (ConnectionResetError, BrokenPipeError):
        return
    try:
        assert not response.startswith(b"HTTP/1.1 101"), f"{description} was accepted"
    finally:
        connection.close()


def main():
    with open(SECRET_PATH, "rb") as secret_file:
        secret = secret_file.read().rstrip(b"\r\n")

    token = signed_token(secret, "demo.pc.example", "1" * 32)
    connection, response = connect(token)
    try:
        assert response.startswith(b"HTTP/1.1 101"), response.decode("latin-1")
        banner = read_binary_frame(connection, response)
        assert banner == b"RFB 003.008\n", banner
    finally:
        connection.close()

    assert_rejected(token, "replayed token")
    assert_rejected(
        signed_token(secret, "other.pc.example", "2" * 32),
        "non-allow-listed token",
    )
    tampered = signed_token(secret, "demo.pc.example", "3" * 32)
    tampered = tampered[:-1] + ("0" if tampered[-1] != "0" else "1")
    assert_rejected(tampered, "tampered token")
    print("viewer gateway runtime assertions passed")


if __name__ == "__main__":
    main()
