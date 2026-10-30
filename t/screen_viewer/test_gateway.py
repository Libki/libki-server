# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
import hashlib, hmac, multiprocessing, os, tempfile, time, unittest
from unittest.mock import patch
from libki_token_plugin import LibkiTokenPlugin

def signed(secret, client, expiry, nonce):
    payload = f"{client}.{expiry}.{nonce}"
    return payload + "." + hmac.new(secret, payload.encode(), hashlib.sha256).hexdigest()

def try_token(args):
    path, token = args
    return LibkiTokenPlugin(path).lookup(token)

class GatewayTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.secret = b"test-only-not-a-deployed-key" * 2
        self.path = self.tmp.name + "/secret"
        with open(self.path, "wb") as f: f.write(self.secret)
        self.env = patch.dict(os.environ, {
            "LIBKI_VIEWER_CLIENT_NAME": "demo.pc.example",
            "LIBKI_VIEWER_TARGET_HOST": "192.0.2.10",
            "LIBKI_VIEWER_TARGET_PORT": "5901",
            "LIBKI_VIEWER_NONCE_DIR": self.tmp.name + "/nonces"})
        self.env.start()
        self.plugin = LibkiTokenPlugin(self.path)
    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()
    def token(self, client="demo.pc.example", delta=60, nonce="a"*32):
        return signed(self.secret, client, int(time.time())+delta, nonce)
    def test_dotted_name_and_replay(self):
        token = self.token()
        self.assertEqual(self.plugin.lookup(token), ("192.0.2.10",5901))
        self.assertIsNone(self.plugin.lookup(token))
    def test_rejections(self):
        good = self.token()
        for token in [None, "", "bad", self.token(client="other"), self.token(delta=-2),
                      self.token(delta=100), self.token(nonce="bad"),
                      good[:-1]+("0" if good[-1]!="0" else "1")]:
            with self.subTest(token_type=type(token).__name__):
                self.assertIsNone(self.plugin.lookup(token))
    def test_atomic_replay_across_workers(self):
        token = self.token(nonce="b"*32)
        with multiprocessing.get_context("fork").Pool(6) as pool:
            results = pool.map(try_token, [(self.path,token)]*12)
        self.assertEqual(sum(x is not None for x in results), 1)
    def test_nonce_storage_failure_is_closed(self):
        self.plugin._nonce_dir = self.tmp.name + "/does-not-exist"
        self.assertIsNone(self.plugin.lookup(self.token()))
    def test_invalid_target(self):
        for host in ["example.org", "256.2.3.4", "192.0.2.1:22"]:
            with patch.dict(os.environ, {"LIBKI_VIEWER_TARGET_HOST":host}):
                with self.assertRaises(ValueError): LibkiTokenPlugin(self.path)

if __name__ == "__main__": unittest.main()
