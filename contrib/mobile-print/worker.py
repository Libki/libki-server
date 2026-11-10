import os
import json
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path

from common import NORMALIZED_DIR, connect, initialize_database, now_epoch


CONVERSION_TIMEOUT = int(os.getenv("MOBILEPRINT_CONVERSION_TIMEOUT", "60"))
MAX_FILES = int(os.getenv("MOBILEPRINT_MAX_FILES", "5"))
MAX_FILE_PAGES = int(os.getenv("MOBILEPRINT_MAX_FILE_PAGES", "100"))
MAX_JOB_PAGES = int(os.getenv("MOBILEPRINT_MAX_JOB_PAGES", "500"))
MAX_UPLOAD_BYTES = int(os.getenv("MOBILEPRINT_MAX_UPLOAD_BYTES", str(20 * 1024 * 1024)))
MAX_JOB_UPLOAD_BYTES = int(
    os.getenv("MOBILEPRINT_MAX_JOB_UPLOAD_BYTES", str(90 * 1024 * 1024))
)
MAX_FILE_OUTPUT_BYTES = int(
    os.getenv("MOBILEPRINT_MAX_FILE_OUTPUT_BYTES", str(128 * 1024 * 1024))
)
MAX_JOB_OUTPUT_BYTES = int(
    os.getenv("MOBILEPRINT_MAX_JOB_OUTPUT_BYTES", str(256 * 1024 * 1024))
)
MAX_ARCHIVE_EXPANDED_BYTES = 100 * 1024 * 1024
PRICE_BW_CENTS = int(os.getenv("MOBILEPRINT_PRICE_BW_CENTS", "15"))
PRICE_COLOR_CENTS = int(os.getenv("MOBILEPRINT_PRICE_COLOR_CENTS", "35"))


class Rejected(Exception):
    pass


def run(command: list[str], timeout: int = CONVERSION_TIMEOUT) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
            env={"PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", "HOME": "/tmp"},
        )
    except subprocess.TimeoutExpired as error:
        raise Rejected("conversion-timeout") from error


def scan(
    path: Path,
    max_filesize: str = "20M",
    max_scansize: str = "25M",
    timeout: int = 45,
) -> None:
    result = run(
        [
            "clamscan",
            "--no-summary",
            "--infected",
            f"--max-filesize={max_filesize}",
            f"--max-scansize={max_scansize}",
            "--max-recursion=8",
            "--max-files=100",
            str(path),
        ],
        timeout=timeout,
    )
    if result.returncode == 1:
        raise Rejected("malware-detected")
    if result.returncode != 0:
        raise Rejected("scanner-unavailable")


def validate_zip(path: Path, extension: str) -> None:
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            if len(names) > 2500:
                raise Rejected("archive-limit")
            if sum(info.file_size for info in archive.infolist()) > MAX_ARCHIVE_EXPANDED_BYTES:
                raise Rejected("archive-expanded-limit")
            if any(name.startswith(("/", "\\")) or ".." in Path(name).parts for name in names):
                raise Rejected("archive-path")
            lower_names = {name.lower() for name in names}
            if any("vbaproject.bin" in name for name in lower_names):
                raise Rejected("macros-not-allowed")
            if extension == ".docx" and not {
                "[content_types].xml",
                "word/document.xml",
            }.issubset(lower_names):
                raise Rejected("invalid-docx")
            if extension == ".odt" and not {"mimetype", "content.xml"}.issubset(lower_names):
                raise Rejected("invalid-odt")
            bad_encryption = any(info.flag_bits & 0x1 for info in archive.infolist())
            if bad_encryption:
                raise Rejected("encrypted-file")
    except (OSError, zipfile.BadZipFile) as error:
        raise Rejected("invalid-archive") from error


def validate_source(path: Path, extension: str) -> None:
    with path.open("rb") as source:
        header = source.read(16)
    if extension == ".pdf" and not header.startswith(b"%PDF-"):
        raise Rejected("type-mismatch")
    if extension == ".png" and not header.startswith(b"\x89PNG\r\n\x1a\n"):
        raise Rejected("type-mismatch")
    if extension in {".jpg", ".jpeg"} and not header.startswith(b"\xff\xd8\xff"):
        raise Rejected("type-mismatch")
    if extension in {".docx", ".odt"}:
        if not header.startswith(b"PK"):
            raise Rejected("type-mismatch")
        validate_zip(path, extension)
    if extension == ".txt":
        try:
            path.read_text(encoding="utf-8")
        except UnicodeDecodeError as error:
            raise Rejected("invalid-text-encoding") from error


def convert_source(source: Path, extension: str, output: Path, workdir: Path) -> None:
    if extension == ".pdf":
        result = run(["qpdf", "--warning-exit-0", str(source), str(output)])
    elif extension in {".jpg", ".jpeg", ".png"}:
        result = run(["img2pdf", str(source), "-o", str(output)])
    else:
        named_source = workdir / f"source{extension}"
        shutil.copyfile(source, named_source)
        result = run(
            [
                "libreoffice",
                "--headless",
                "--safe-mode",
                "--norestore",
                "--nodefault",
                "--nolockcheck",
                "--convert-to",
                "pdf",
                "--outdir",
                str(workdir),
                str(named_source),
            ]
        )
        generated = workdir / "source.pdf"
        if result.returncode == 0 and generated.exists():
            shutil.move(generated, output)
    if result.returncode != 0 or not output.exists():
        raise Rejected("conversion-failed")


def page_count(path: Path, maximum: int) -> int:
    result = run(["pdfinfo", str(path)], timeout=20)
    if result.returncode != 0:
        raise Rejected("invalid-pdf")
    for line in result.stdout.splitlines():
        if line.lower().startswith("pages:"):
            pages = int(line.split(":", 1)[1].strip())
            if pages < 1 or pages > maximum:
                raise Rejected("page-limit")
            return pages
    raise Rejected("page-count-failed")


def claim_job():
    with connect() as connection:
        connection.execute("BEGIN IMMEDIATE")
        row = connection.execute(
            "SELECT * FROM jobs WHERE status = 'received' ORDER BY created_at LIMIT 1"
        ).fetchone()
        if row is None:
            connection.rollback()
            return None
        changed = connection.execute(
            "UPDATE jobs SET status = 'processing', updated_at = ? WHERE id = ? AND status = 'received'",
            (now_epoch(), row["id"]),
        ).rowcount
        if changed != 1:
            connection.rollback()
            return None
        connection.commit()
        return row


def load_job_files(job) -> list[dict[str, object]]:
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT ordinal, source_extension, incoming_path, source_bytes, copies
              FROM job_files
             WHERE job_id = ?
             ORDER BY ordinal
            """,
            (job["id"],),
        ).fetchall()
    if rows:
        return [dict(row) for row in rows]
    return [
        {
            "ordinal": 1,
            "copies": None,
            "source_extension": job["source_extension"],
            "incoming_path": job["incoming_path"],
            "source_bytes": Path(job["incoming_path"]).stat().st_size
            if job["incoming_path"] and Path(job["incoming_path"]).is_file()
            else 0,
        }
    ]


def merge_pdfs(inputs: list[Path], output: Path) -> None:
    if len(inputs) == 1:
        shutil.copyfile(inputs[0], output)
        return
    command = ["qpdf", "--empty", "--pages"]
    for input_path in inputs:
        command.extend([str(input_path), "1-z"])
    command.extend(["--", str(output)])
    result = run(command, timeout=max(CONVERSION_TIMEOUT, 120))
    if result.returncode != 0 or not output.exists():
        raise Rejected("merge-failed")


def process_job(job) -> None:
    sources = load_job_files(job)
    source_paths = [Path(str(item["incoming_path"])) for item in sources]
    final_output = NORMALIZED_DIR / f"{job['id']}.pdf"
    error_code = None
    try:
        if not 1 <= len(sources) <= MAX_FILES:
            raise Rejected("file-count-limit")
        total_source_bytes = 0
        for item, source in zip(sources, source_paths):
            if not source.is_file():
                raise Rejected("source-unavailable")
            actual_size = source.stat().st_size
            total_source_bytes += actual_size
            if actual_size < 1 or actual_size > MAX_UPLOAD_BYTES:
                raise Rejected("source-size-limit")
        if total_source_bytes > MAX_JOB_UPLOAD_BYTES:
            raise Rejected("job-upload-limit")

        with tempfile.TemporaryDirectory(prefix="mobileprint-", dir="/tmp") as temporary:
            workdir = Path(temporary)
            converted: list[Path] = []
            pages = 0
            printed_pages = 0
            summary = []
            for item, source in zip(sources, source_paths):
                extension = str(item["source_extension"])
                scan(source)
                validate_source(source, extension)
                file_workdir = workdir / f"file-{int(item['ordinal'])}"
                file_workdir.mkdir()
                staged_output = file_workdir / "normalized.pdf"
                convert_source(source, extension, staged_output, file_workdir)
                if staged_output.stat().st_size > MAX_FILE_OUTPUT_BYTES:
                    raise Rejected("file-output-limit")
                file_pages = page_count(staged_output, MAX_FILE_PAGES)
                pages += file_pages
                if pages > MAX_JOB_PAGES:
                    raise Rejected("job-page-limit")
                scan(staged_output, "128M", "160M", timeout=90)
                copies = item.get("copies")
                if copies is not None and (not isinstance(copies, int) or not 1 <= copies <= 99):
                    raise Rejected("copies-limit")
                quantity = copies if copies is not None else 1
                printed_pages += file_pages * quantity
                converted.extend([staged_output] * quantity)
                if copies is not None:
                    summary.append({"document": int(item["ordinal"]), "pages": file_pages,
                                    "copies": quantity, "printed_pages": file_pages * quantity})

            merged_output = workdir / "merged.pdf"
            merge_pdfs(converted, merged_output)
            if merged_output.stat().st_size > MAX_JOB_OUTPUT_BYTES:
                raise Rejected("job-output-limit")
            # Source limits remain 100 pages/file and 500/job. Quantities were
            # already allowed up to 99; never apply the bundle quantity twice.
            merged_pages = page_count(merged_output, MAX_JOB_PAGES * 99)
            if merged_pages != printed_pages:
                raise Rejected("merged-page-count-mismatch")
            scan(merged_output, "256M", "300M", timeout=120)
            shutil.copyfile(merged_output, final_output)
        for source in source_paths:
            source.unlink(missing_ok=True)
        price = printed_pages * int(job["copies"]) * (
            PRICE_BW_CENTS if job["print_mode"] == "bw" else PRICE_COLOR_CENTS
        )
        with connect() as connection:
            connection.execute(
                """
                UPDATE jobs
                   SET status = 'ready', incoming_path = NULL, normalized_path = ?,
                       pages = ?, price_cents = ?, updated_at = ?, document_summary = ?
                 WHERE id = ? AND status = 'processing'
                """,
                (str(final_output), printed_pages, price, now_epoch(),
                 json.dumps(summary) if summary else None, job["id"]),
            )
            connection.execute("DELETE FROM job_files WHERE job_id = ?", (job["id"],))
    except Rejected as error:
        error_code = str(error)
    except Exception:
        error_code = "processing-error"

    if error_code:
        for source in source_paths:
            source.unlink(missing_ok=True)
        final_output.unlink(missing_ok=True)
        with connect() as connection:
            connection.execute(
                """
                UPDATE jobs
                   SET status = 'rejected', error_code = ?, incoming_path = NULL,
                       normalized_path = NULL, updated_at = ?, deleted_at = ?
                 WHERE id = ?
                """,
                (error_code, now_epoch(), now_epoch(), job["id"]),
            )
            connection.execute("DELETE FROM job_files WHERE job_id = ?", (job["id"],))


def main() -> None:
    initialize_database()
    while True:
        job = claim_job()
        if job is None:
            time.sleep(2)
            continue
        process_job(job)


if __name__ == "__main__":
    main()
