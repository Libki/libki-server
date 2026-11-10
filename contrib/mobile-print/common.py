import os
import sqlite3
import time
from pathlib import Path

from cryptography.fernet import Fernet


STATE_DIR = Path(os.getenv("MOBILEPRINT_STATE_DIR", "/data/state"))
INCOMING_DIR = Path(os.getenv("MOBILEPRINT_INCOMING_DIR", "/data/incoming"))
NORMALIZED_DIR = Path(os.getenv("MOBILEPRINT_NORMALIZED_DIR", "/data/normalized"))
DATABASE_PATH = STATE_DIR / "mobileprint.sqlite3"
SECRET_PATH = Path(os.getenv("MOBILEPRINT_CARD_KEY_FILE", "/run/secrets/card_fernet_key"))


def now_epoch() -> int:
    return int(time.time())


def ensure_directories() -> None:
    for path in (STATE_DIR, INCOMING_DIR, NORMALIZED_DIR):
        path.mkdir(parents=True, exist_ok=True)


def connect() -> sqlite3.Connection:
    ensure_directories()
    connection = sqlite3.connect(DATABASE_PATH, timeout=30)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA journal_mode=WAL")
    connection.execute("PRAGMA foreign_keys=ON")
    connection.execute("PRAGMA busy_timeout=30000")
    return connection


def initialize_database() -> None:
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS jobs (
                id TEXT PRIMARY KEY,
                public_token_hash TEXT NOT NULL UNIQUE,
                card_ciphertext TEXT NOT NULL,
                card_last4 TEXT NOT NULL,
                release_code_ciphertext TEXT NOT NULL,
                destination TEXT NOT NULL CHECK(destination IN ('main', 'genealogy')),
                print_mode TEXT NOT NULL CHECK(print_mode IN ('bw', 'color')),
                source_extension TEXT NOT NULL,
                incoming_path TEXT,
                normalized_path TEXT,
                file_count INTEGER NOT NULL DEFAULT 1,
                copies INTEGER NOT NULL DEFAULT 1,
                status TEXT NOT NULL,
                error_code TEXT,
                pages INTEGER,
                price_cents INTEGER,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                submitted_at INTEGER,
                released_at INTEGER,
                deleted_at INTEGER,
                libki_job_id INTEGER
            );
            CREATE TABLE IF NOT EXISTS job_files (
                job_id TEXT NOT NULL,
                ordinal INTEGER NOT NULL,
                source_extension TEXT NOT NULL,
                incoming_path TEXT NOT NULL,
                source_bytes INTEGER NOT NULL,
                PRIMARY KEY (job_id, ordinal),
                FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS jobs_status_created
                ON jobs(status, created_at);
            CREATE INDEX IF NOT EXISTS jobs_expires
                ON jobs(expires_at, status);
            """
        )
        columns = {
            row["name"] for row in connection.execute("PRAGMA table_info(jobs)")
        }
        if "copies" not in columns:
            try:
                connection.execute("ALTER TABLE jobs ADD COLUMN copies INTEGER NOT NULL DEFAULT 1")
            except sqlite3.OperationalError as error:
                if "duplicate column" not in str(error).lower():
                    raise
        if "libki_job_id" not in columns:
            connection.execute("ALTER TABLE jobs ADD COLUMN libki_job_id INTEGER")
        if "file_count" not in columns:
            connection.execute(
                "ALTER TABLE jobs ADD COLUMN file_count INTEGER NOT NULL DEFAULT 1"
            )
        # Additive migrations: old jobs retain the original whole-job copies.
        for table, column, declaration in (
            ("jobs", "document_summary", "TEXT"),
            ("job_files", "copies", "INTEGER"),
        ):
            present = {row["name"] for row in connection.execute(f"PRAGMA table_info({table})")}
            if column not in present:
                try:
                    connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")
                except sqlite3.OperationalError as error:
                    if "duplicate column" not in str(error).lower():
                        raise


def fernet() -> Fernet:
    key = SECRET_PATH.read_bytes().strip()
    return Fernet(key)


def encrypt_value(value: str) -> str:
    return fernet().encrypt(value.encode("utf-8")).decode("ascii")


def decrypt_value(value: str) -> str:
    return fernet().decrypt(value.encode("ascii")).decode("utf-8")
