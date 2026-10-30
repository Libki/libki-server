import hashlib
import json
import os
import re
import secrets
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from common import (
    INCOMING_DIR,
    connect,
    decrypt_value,
    encrypt_value,
    initialize_database,
    now_epoch,
)


MAX_UPLOAD_BYTES = int(os.getenv("MOBILEPRINT_MAX_UPLOAD_BYTES", str(20 * 1024 * 1024)))
MAX_JOB_UPLOAD_BYTES = int(
    os.getenv("MOBILEPRINT_MAX_JOB_UPLOAD_BYTES", str(90 * 1024 * 1024))
)
MAX_FILES = int(os.getenv("MOBILEPRINT_MAX_FILES", "5"))
HOLD_SECONDS = int(os.getenv("MOBILEPRINT_HOLD_SECONDS", str(48 * 60 * 60)))
ALLOWED_EXTENSIONS = {".pdf", ".docx", ".odt", ".txt", ".jpg", ".jpeg", ".png"}
PHONE_PATTERN = re.compile(r"^[0-9]{10}$")
RELEASE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
DESTINATIONS = {
    "main": "Main Floor service desk",
    "genealogy": "Genealogy service desk",
}


app = FastAPI(
    title="Clinton Public Library Mobile Printing",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
templates = Jinja2Templates(directory="templates")
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.on_event("startup")
def startup() -> None:
    initialize_database()


@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(), payment=()"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; img-src 'self' data:; style-src 'self'; "
        "script-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; "
        "frame-ancestors 'none'"
    )
    return response


def render_home(request: Request, error: str | None = None, status_code: int = 200):
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={"error": error, "max_files": MAX_FILES},
        status_code=status_code,
    )


def normalize_phone(value: str) -> str | None:
    digits = re.sub(r"[^0-9]", "", value)
    if len(digits) == 11 and digits.startswith("1"):
        digits = digits[1:]
    return digits if PHONE_PATTERN.fullmatch(digits) else None


@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    return render_home(request)


@app.get("/healthz")
def healthz():
    initialize_database()
    return {"status": "ok"}


@app.post("/jobs")
async def create_job(
    request: Request,
    phone_number: str = Form(...),
    destination: str = Form(...),
    print_mode: str = Form(...),
    documents: list[UploadFile] = File(...),
    copies: str = Form("1"),
    file_copies: list[str] | None = Form(None),
):
    if not re.fullmatch(r"[0-9]{1,2}", copies) or not 1 <= int(copies) <= 99:
        for document in documents:
            await document.close()
        return render_home(request, "Choose between 1 and 99 copies.", 400)
    copy_count = int(copies)
    # Legacy forms retain one quantity for the whole job. Enhanced forms submit
    # one quantity per document in the exact same multipart order.
    if file_copies is not None and (
        len(file_copies) != len(documents)
        or any(not re.fullmatch(r"[0-9]{1,2}", value)
               or not 1 <= int(value) <= 99 for value in file_copies)
    ):
        for document in documents:
            await document.close()
        return render_home(request, "Choose between 1 and 99 copies for every document.", 400)
    if file_copies is not None:
        copy_count = 1  # Quantities are incorporated once into the prepared bundle.
    phone = normalize_phone(phone_number)
    if phone is None:
        return render_home(request, "Enter a valid 10-digit phone number.", 400)
    if destination not in DESTINATIONS or print_mode not in {"bw", "color"}:
        return render_home(request, "Choose a valid print destination and print type.", 400)

    if not 1 <= len(documents) <= MAX_FILES:
        for document in documents:
            await document.close()
        return render_home(request, f"Choose between 1 and {MAX_FILES} documents.", 400)

    extensions = [Path(document.filename or "").suffix.lower() for document in documents]
    if any(extension not in ALLOWED_EXTENSIONS for extension in extensions):
        for document in documents:
            await document.close()
        return render_home(request, "One or more files use an unsupported type.", 400)

    job_id = str(uuid.uuid4())
    public_token = secrets.token_urlsafe(32)
    release_raw = "".join(secrets.choice(RELEASE_ALPHABET) for _ in range(8))
    release_code = f"MP-{release_raw[:4]}-{release_raw[4:]}"
    accepted_files: list[dict[str, object]] = []
    temporary_paths: list[Path] = []
    job_total = 0

    try:
        for ordinal, (document, extension) in enumerate(zip(documents, extensions), start=1):
            incoming_path = INCOMING_DIR / f"{job_id}-{ordinal}.upload"
            temporary_path = INCOMING_DIR / f"{job_id}-{ordinal}.partial"
            temporary_paths.append(temporary_path)
            file_total = 0
            with temporary_path.open("xb") as output:
                while chunk := await document.read(1024 * 1024):
                    file_total += len(chunk)
                    job_total += len(chunk)
                    if file_total > MAX_UPLOAD_BYTES:
                        raise ValueError("file-too-large")
                    if job_total > MAX_JOB_UPLOAD_BYTES:
                        raise ValueError("job-too-large")
                    output.write(chunk)
            if file_total == 0:
                raise ValueError("empty-upload")
            temporary_path.rename(incoming_path)
            accepted_files.append(
                {
                    "ordinal": ordinal,
                    "extension": extension,
                    "path": incoming_path,
                    "size": file_total,
                    "copies": int(file_copies[ordinal - 1]) if file_copies else None,
                }
            )
    except (OSError, ValueError):
        for path in temporary_paths:
            path.unlink(missing_ok=True)
        for item in accepted_files:
            item["path"].unlink(missing_ok=True)
        return render_home(
            request,
            "The documents could not be accepted. Use no more than 5 files, "
            "20 MB per file, and 90 MB total.",
            400,
        )
    finally:
        for document in documents:
            await document.close()

    created = now_epoch()
    expires = created + HOLD_SECONDS
    try:
        with connect() as connection:
            connection.execute(
                """
                INSERT INTO jobs (
                    id, public_token_hash, card_ciphertext, card_last4,
                    release_code_ciphertext, destination, print_mode,
                    source_extension, incoming_path, file_count, copies, status,
                    created_at, updated_at, expires_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'received', ?, ?, ?)
                """,
                (
                    job_id,
                    hashlib.sha256(public_token.encode("utf-8")).hexdigest(),
                    encrypt_value(phone),
                    phone[-4:],
                    encrypt_value(release_code),
                    destination,
                    print_mode,
                    accepted_files[0]["extension"],
                    str(accepted_files[0]["path"]),
                    len(accepted_files),
                    copy_count,
                    created,
                    created,
                    expires,
                ),
            )
            connection.executemany(
                """
                INSERT INTO job_files (
                    job_id, ordinal, source_extension, incoming_path, source_bytes, copies
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        job_id,
                        item["ordinal"],
                        item["extension"],
                        str(item["path"]),
                        item["size"],
                        item["copies"],
                    )
                    for item in accepted_files
                ],
            )
    except Exception:
        for item in accepted_files:
            item["path"].unlink(missing_ok=True)
        return render_home(request, "The service could not create the print job. Please try again.", 503)

    return RedirectResponse(url=f"/jobs/{public_token}", status_code=303)


@app.get("/jobs/{public_token}", response_class=HTMLResponse)
def job_status(request: Request, public_token: str):
    token_hash = hashlib.sha256(public_token.encode("utf-8")).hexdigest()
    with connect() as connection:
        job = connection.execute(
            "SELECT * FROM jobs WHERE public_token_hash = ?", (token_hash,)
        ).fetchone()
    if job is None:
        return templates.TemplateResponse(
            request=request,
            name="not_found.html",
            context={},
            status_code=404,
        )

    context = {
        "job": job,
        "destination_name": DESTINATIONS[job["destination"]],
        "document_summary": json.loads(job["document_summary"] or "[]"),
        "release_code": decrypt_value(job["release_code_ciphertext"])
        if job["status"] in {"ready", "held", "submitted"}
        else None,
    }
    response = templates.TemplateResponse(
        request=request,
        name="status.html",
        context=context,
    )
    if job["status"] in {"received", "processing"}:
        response.headers["Refresh"] = "3"
    return response
