import os
import json
import re
import secrets
from pathlib import Path

from fastapi import FastAPI, Form, Header, HTTPException, Response
from fastapi.responses import FileResponse

from common import connect, decrypt_value, initialize_database, now_epoch


TOKEN_PATH = Path(
    os.getenv(
        "MOBILEPRINT_ADAPTER_TOKEN_FILE",
        "/run/secrets/adapter_bearer_token",
    )
)
JOB_ID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)

app = FastAPI(
    title="CPL Mobile Print Internal Adapter",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)


@app.on_event("startup")
def startup() -> None:
    initialize_database()


@app.middleware("http")
async def security_headers(request, call_next):
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


def authorize(authorization: str | None = Header(default=None)) -> None:
    try:
        expected = TOKEN_PATH.read_text(encoding="ascii").strip()
    except OSError as error:
        raise HTTPException(status_code=503, detail="adapter unavailable") from error
    supplied = ""
    if authorization and authorization.startswith("Bearer "):
        supplied = authorization[7:]
    if not expected or not secrets.compare_digest(supplied, expected):
        raise HTTPException(status_code=401, detail="unauthorized")


def load_ready_job(job_id: str):
    if not JOB_ID_PATTERN.fullmatch(job_id):
        raise HTTPException(status_code=404, detail="job not found")
    with connect() as connection:
        job = connection.execute(
            """
            SELECT * FROM jobs
             WHERE id = ? AND status = 'ready' AND expires_at > ?
            """,
            (job_id, now_epoch()),
        ).fetchone()
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    return job


@app.get("/healthz")
def healthz():
    initialize_database()
    return {"status": "ok"}


@app.get("/v1/jobs/next")
def next_job(authorization: str | None = Header(default=None)):
    authorize(authorization)
    with connect() as connection:
        job = connection.execute(
            """
            SELECT * FROM jobs
             WHERE status = 'ready' AND expires_at > ?
             ORDER BY created_at
             LIMIT 1
            """,
            (now_epoch(),),
        ).fetchone()
    if job is None:
        return Response(status_code=204)
    phone_number = decrypt_value(job["card_ciphertext"])
    return {
        "id": job["id"],
        "phone_number": phone_number,
        # Kept temporarily for compatibility with an adapter during a rolling
        # upgrade. It is the same encrypted-at-rest phone value, not a card.
        "library_card": phone_number,
        "release_code": decrypt_value(job["release_code_ciphertext"]),
        "destination": job["destination"],
        "print_mode": job["print_mode"],
        "pages": job["pages"],
        "copies": job["copies"],
        "file_count": job["file_count"],
        "document_quantities": json.loads(job["document_summary"] or "[]"),
        "price_cents": job["price_cents"],
        "created_at": job["created_at"],
        "expires_at": job["expires_at"],
    }


@app.get("/v1/jobs/{job_id}/document")
def document(job_id: str, authorization: str | None = Header(default=None)):
    authorize(authorization)
    job = load_ready_job(job_id)
    path = Path(job["normalized_path"] or "")
    if not path.is_file():
        raise HTTPException(status_code=410, detail="document unavailable")
    release_code = decrypt_value(job["release_code_ciphertext"])
    return FileResponse(
        path,
        media_type="application/pdf",
        filename=f"{release_code}.pdf",
        headers={"Cache-Control": "no-store"},
    )


@app.post("/v1/jobs/{job_id}/ack")
def acknowledge(
    job_id: str,
    libki_job_id: int = Form(...),
    authorization: str | None = Header(default=None),
):
    authorize(authorization)
    load_ready_job(job_id)
    if libki_job_id < 1:
        raise HTTPException(status_code=400, detail="invalid Libki job")
    now = now_epoch()
    with connect() as connection:
        changed = connection.execute(
            """
            UPDATE jobs
               SET status = 'submitted', submitted_at = ?, updated_at = ?,
                   libki_job_id = ?
             WHERE id = ? AND status = 'ready'
            """,
            (now, now, libki_job_id, job_id),
        ).rowcount
    if changed != 1:
        raise HTTPException(status_code=409, detail="job state changed")
    return {"status": "submitted", "libki_job_id": libki_job_id}
