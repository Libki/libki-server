# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
"""Isolated gateway protocol check: loopback fake RFB target, no real desktop."""
import os, socket, socketserver, subprocess, sys, tempfile, threading, time
from pathlib import Path
import gateway_runtime

class Target(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.sendall(b"RFB 003.008\n")
        self.request.settimeout(2)
        try: self.request.recv(1024)
        except TimeoutError: pass

with tempfile.TemporaryDirectory() as directory:
    secret = Path(directory) / "hmac"
    secret.write_bytes(b"test-only-loopback-key-" * 3)
    target = socketserver.ThreadingTCPServer(("127.0.0.1",0),Target)
    threading.Thread(target=target.serve_forever,daemon=True).start()
    with socket.socket() as reserve:
        reserve.bind(("127.0.0.1",0)); port=reserve.getsockname()[1]
    env={**os.environ,"LIBKI_VIEWER_CLIENT_NAME":"demo.pc.example",
         "LIBKI_VIEWER_TARGET_HOST":"127.0.0.1",
         "LIBKI_VIEWER_TARGET_PORT":str(target.server_address[1]),
         "LIBKI_VIEWER_NONCE_DIR":directory+"/nonces"}
    entry=Path(__file__).resolve().parents[2]/"docker/screen-viewer/run_gateway.py"
    proc=subprocess.Popen([sys.executable,str(entry),
        "--token-plugin=libki_token_plugin.LibkiTokenPlugin",
        "--token-source="+str(secret),"127.0.0.1:"+str(port)],
        env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    try:
        for _ in range(100):
            try:
                with socket.create_connection(("127.0.0.1",port),.1): break
            except OSError:
                if proc.poll() is not None: raise AssertionError("gateway stopped")
                time.sleep(.05)
        else: raise AssertionError("gateway startup timeout")
        gateway_runtime.HOST="127.0.0.1"
        gateway_runtime.PORT=port
        gateway_runtime.SECRET_PATH=str(secret)
        gateway_runtime.main()
    finally:
        proc.terminate()
        logs=proc.communicate(timeout=10)[0]
        target.shutdown();target.server_close()
        assert b"?token=" not in logs and b"demo.pc.example." not in logs, "token leaked to log"
