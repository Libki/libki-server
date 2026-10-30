"""Isolated upload/worker regressions. No adapter, printer, or production DB."""
import importlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch


class Quantities(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for key, directory in (("STATE", "state"), ("INCOMING", "incoming"), ("NORMALIZED", "normalized")):
            os.environ[f"MOBILEPRINT_{key}_DIR"] = str(self.root / directory)
        os.environ["MOBILEPRINT_CARD_KEY_FILE"] = str(self.root / "key")
        from cryptography.fernet import Fernet
        (self.root / "key").write_bytes(Fernet.generate_key())
        import common
        self.common = importlib.reload(common)
        self.common.initialize_database()

    def tearDown(self):
        self.temporary.cleanup()

    def client(self):
        from fastapi.testclient import TestClient
        import app
        self.app = importlib.reload(app)
        return TestClient(self.app.app)

    def upload(self, quantities=None, count=2, legacy="1", mode="color"):
        data = {"phone_number": "2025550147", "destination": "main", "print_mode": mode, "copies": legacy}
        if quantities is not None:
            data["file_copies"] = quantities
        return self.client().post("/jobs", data=data, files=[("documents", (f"test-{i}.txt", b"Synthetic test")) for i in range(count)], follow_redirects=False)

    def test_per_file_quantities_and_retention(self):
        self.assertEqual(self.upload(["2", "5"]).status_code, 303)
        with self.common.connect() as db:
            job = dict(db.execute("SELECT * FROM jobs").fetchone())
            values = [r[0] for r in db.execute("SELECT copies FROM job_files ORDER BY ordinal")]
        self.assertEqual(values, [2, 5])
        self.assertEqual(job["copies"], 1)
        self.assertEqual(job["expires_at"] - job["created_at"], 172800)

    def test_invalid_quantities_and_file_counts(self):
        for values in (["0", "1"], ["100", "1"], ["1.5", "1"], ["-1", "1"], ["", "1"], ["1"], ["1", "2", "3"]):
            self.assertEqual(self.upload(values).status_code, 400, values)
        self.assertEqual(self.upload(["1"] * 6, count=6).status_code, 400)
        with self.common.connect() as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM jobs").fetchone()[0], 0)

    def test_five_files_and_maximum_copies(self):
        self.assertEqual(self.upload(["99"] * 5, count=5).status_code, 303)

    def test_legacy_form(self):
        self.assertEqual(self.upload(legacy="5").status_code, 303)
        with self.common.connect() as db:
            self.assertEqual(db.execute("SELECT copies FROM jobs").fetchone()[0], 5)
            self.assertIsNone(db.execute("SELECT copies FROM job_files").fetchone()[0])

    def test_csp_and_template(self):
        response = self.client().get("/")
        self.assertIn("script-src 'self'", response.headers["content-security-policy"])
        self.assertNotIn("unsafe-inline", response.headers["content-security-policy"])
        self.assertIn("/static/file-picker.js", response.text)

    def worker_case(self, quantities, legacy, expected_pages, expected_price, mode="color"):
        self.assertEqual(self.upload(quantities, legacy=legacy, mode=mode).status_code, 303)
        import worker
        worker = importlib.reload(worker)
        job = worker.claim_job()
        def convert(source, extension, output, workdir):
            output.write_bytes(b"Synthetic converted test")
        def merge(inputs, output):
            self.assertEqual(len(inputs), expected_pages // 5)
            output.write_bytes(b"Synthetic merged test")
        with patch.object(worker, "scan"), patch.object(worker, "convert_source", convert), patch.object(worker, "merge_pdfs", merge), patch.object(worker, "page_count", side_effect=[5, 5, expected_pages]):
            worker.process_job(job)
        with self.common.connect() as db:
            row = dict(db.execute("SELECT * FROM jobs").fetchone())
        self.assertEqual(row["status"], "ready", row["error_code"])
        self.assertEqual(row["pages"], expected_pages)
        self.assertEqual(row["price_cents"], expected_price)
        return row

    def test_mixed_quantities_color(self):
        row = self.worker_case(["2", "5"], "1", 35, 1225)
        self.assertEqual([r["copies"] for r in json.loads(row["document_summary"])], [2, 5])

    def test_mixed_quantities_bw(self):
        self.worker_case(["2", "5"], "1", 35, 525, "bw")

    def test_old_jobs_not_expanded_or_double_charged(self):
        self.worker_case(None, "5", 10, 1750)

    def test_metadata_and_files_removed_at_expiry(self):
        row = self.worker_case(["2", "5"], "1", 35, 1225)
        import sweeper
        sweeper = importlib.reload(sweeper)
        with self.common.connect() as db:
            db.execute("UPDATE jobs SET expires_at = 0")
        self.assertEqual(sweeper.sweep(), 1)
        with self.common.connect() as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM jobs").fetchone()[0], 0)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM job_files").fetchone()[0], 0)
        self.assertFalse(Path(row["normalized_path"]).exists())


class RealMerge(unittest.TestCase):
    @unittest.skipUnless(shutil.which("qpdf") and os.getenv("TEST_PDF"), "requires isolated worker fixture")
    def test_real_qpdf_copy_order(self):
        import worker
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / "merged.pdf"
            source = Path(os.environ["TEST_PDF"])
            worker.merge_pdfs([source] * 7, output)
            self.assertEqual(worker.page_count(output, 500), 35)


if __name__ == "__main__":
    unittest.main()
