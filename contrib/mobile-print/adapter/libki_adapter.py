#!/usr/bin/python3
import json
import logging
import os
import re
import shutil
import ssl
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from decimal import Decimal, InvalidOperation
from pathlib import Path


INTERNAL_URL = os.getenv(
    "MOBILEPRINT_INTERNAL_URL", "https://mobileprint-internal.example.invalid:8443"
).rstrip("/")
TOKEN_PATH = Path(
    os.getenv(
        "MOBILEPRINT_ADAPTER_TOKEN_FILE",
        "/etc/libki/mobileprint-adapter/token",
    )
)
CA_PATH = Path(
    os.getenv(
        "MOBILEPRINT_ADAPTER_CA_FILE",
        "/etc/libki/mobileprint-adapter/ca.crt",
    )
)
CERT_PATH = Path(
    os.getenv(
        "MOBILEPRINT_ADAPTER_CERT_FILE",
        "/etc/libki/mobileprint-adapter/client.crt",
    )
)
KEY_PATH = Path(
    os.getenv(
        "MOBILEPRINT_ADAPTER_KEY_FILE",
        "/etc/libki/mobileprint-adapter/client.key",
    )
)
LIBKI_URL = os.getenv(
    "LIBKI_MOBILEPRINT_API_URL",
    "https://libki.example.invalid/api/client/v1_0/print",
)
LIBKI_RESOLVE = os.getenv(
    "LIBKI_MOBILEPRINT_RESOLVE",
    "",
)
POLL_SECONDS = max(2, int(os.getenv("MOBILEPRINT_ADAPTER_POLL_SECONDS", "5")))
RELEASE_CODE = re.compile(r"^MP-[23456789A-HJ-NP-Z]{4}-[23456789A-HJ-NP-Z]{4}$")
DESTINATIONS = {
    "main": {
        "client": "MOBILEPRINT-MAIN",
        "location": "CPL Main",
        "bw": "main-bw",
        "color": "main-color",
    },
    "genealogy": {
        "client": "MOBILEPRINT-GENEALOGY",
        "location": "CPL Genealogy",
        "bw": "genealogy-bw",
        "color": "genealogy-color",
    },
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
LOG = logging.getLogger("libki-mobileprint-adapter")


def ssl_context() -> ssl.SSLContext:
    context = ssl.create_default_context(cafile=str(CA_PATH))
    context.load_cert_chain(certfile=str(CERT_PATH), keyfile=str(KEY_PATH))
    return context


def bearer_token() -> str:
    token = TOKEN_PATH.read_text(encoding="ascii").strip()
    if not token:
        raise RuntimeError("adapter token is empty")
    return token


def internal_request(
    path: str,
    method: str = "GET",
    form: dict[str, str] | None = None,
):
    data = None
    headers = {
        "Authorization": f"Bearer {bearer_token()}",
        "Accept": "application/json",
        "Cache-Control": "no-store",
    }
    if form is not None:
        data = urllib.parse.urlencode(form).encode("ascii")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    request = urllib.request.Request(
        f"{INTERNAL_URL}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    return urllib.request.urlopen(request, context=ssl_context(), timeout=30)


def next_job():
    with internal_request("/v1/jobs/next") as response:
        if response.status == 204:
            return None
        if response.status != 200:
            raise RuntimeError(f"unexpected internal API status {response.status}")
        payload = response.read(65537)
    if len(payload) > 65536:
        raise RuntimeError("internal API response exceeded limit")
    return json.loads(payload.decode("utf-8"))


def validate_job(job: dict) -> dict:
    destination = job.get("destination")
    print_mode = job.get("print_mode")
    release_code = job.get("release_code", "")
    if destination not in DESTINATIONS or print_mode not in {"bw", "color"}:
        raise RuntimeError("job has invalid routing")
    if not RELEASE_CODE.fullmatch(release_code):
        raise RuntimeError("job has invalid release code")
    phone_number = str(job.get("phone_number", job.get("library_card", "")))
    if not re.fullmatch(r"[0-9]{10}", phone_number):
        raise RuntimeError("job has invalid phone number")
    job["phone_number"] = phone_number
    quantities = job.get("document_quantities", [])
    maximum_pages = 500
    if quantities:
        # Per-document quantities are already incorporated in the PDF. Validate
        # every source bound and the arithmetic before accepting expanded pages.
        if not isinstance(quantities, list) or len(quantities) != job.get("file_count") or not 1 <= len(quantities) <= 5:
            raise RuntimeError("job has invalid document quantities")
        total = 0
        for ordinal, item in enumerate(quantities, start=1):
            if not isinstance(item, dict) or item.get("document") != ordinal:
                raise RuntimeError("job has invalid document order")
            pages, count = item.get("pages"), item.get("copies")
            if type(pages) is not int or not 1 <= pages <= 100 or type(count) is not int or not 1 <= count <= 99:
                raise RuntimeError("job has invalid document quantity")
            if item.get("printed_pages") != pages * count:
                raise RuntimeError("job has invalid document page total")
            total += pages * count
        if job.get("copies") != 1 or job.get("pages") != total:
            raise RuntimeError("job has invalid prepared bundle total")
        maximum_pages = 500 * 99
    if int(job.get("pages", 0)) < 1 or int(job.get("pages", 0)) > maximum_pages:
        raise RuntimeError("job has invalid page count")
    copies = job.get("copies", 1)
    if not isinstance(copies, int) or not 1 <= copies <= 99:
        raise RuntimeError("job has invalid copy count")
    if int(job.get("file_count", 1)) < 1 or int(job.get("file_count", 1)) > 5:
        raise RuntimeError("job has invalid file count")
    if int(job.get("expires_at", 0)) <= int(time.time()):
        raise RuntimeError("job has expired")
    return DESTINATIONS[destination]


def download_document(job: dict, path: Path) -> None:
    with internal_request(f"/v1/jobs/{job['id']}/document") as response:
        if response.status != 200:
            raise RuntimeError(f"document request returned {response.status}")
        with path.open("xb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)
    if path.stat().st_size < 5 or path.stat().st_size > 256 * 1024 * 1024:
        raise RuntimeError("downloaded document size is invalid")
    with path.open("rb") as document:
        if not document.read(5).startswith(b"%PDF-"):
            raise RuntimeError("downloaded document is not a PDF")


def submit_to_libki(job: dict, route: dict, path: Path) -> int:
    release_code = job["release_code"]
    printer = route[job["print_mode"]]
    command = [
        "/usr/bin/curl",
        "--silent",
        "--show-error",
        "--fail-with-body",
        "--max-time",
        "45",
        "-X",
        "POST",
        LIBKI_URL,
        "-F",
        f"client_name={route['client']}",
        "-F",
        f"username={job['phone_number']}",
        "-F",
        f"printer={printer}",
        "-F",
        f"location={route['location']}",
        "-F",
        f"mobile_job_id={job['id']}",
        "-F",
        f"mobile_expires_at={job['expires_at']}",
        "-F",
        f"mobile_release_code={release_code}",
        "-F",
        f"mobile_file_count={job.get('file_count', 1)}",
        "-F",
        f"mobile_copies={job.get('copies', 1)}",
        "-F",
        f"print_file=@{path};filename={release_code}.pdf;type=application/pdf",
    ]
    if LIBKI_RESOLVE:
        command[1:1] = ["--resolve", LIBKI_RESOLVE]
    result = subprocess.run(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=55,
        check=False,
        env={
            "PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
            "HOME": "/tmp",
            "LANG": "C.UTF-8",
        },
    )
    if result.returncode != 0:
        raise RuntimeError(f"Libki API rejected job (curl {result.returncode})")
    try:
        response = json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError("Libki API returned invalid JSON") from error
    if int(response.get("success", 0)) != 1:
        raise RuntimeError("Libki API did not accept job")
    try:
        actual_cents = int(
            (Decimal(str(response["amount_due"])) * Decimal("100")).quantize(
                Decimal("1")
            )
        )
    except (InvalidOperation, KeyError, ValueError) as error:
        raise RuntimeError("Libki API returned an invalid price") from error
    if actual_cents != int(job["price_cents"]):
        raise RuntimeError(
            f"price mismatch: gateway={job['price_cents']} Libki={actual_cents}"
        )
    libki_job_id = int(response.get("print_job_id", 0))
    if libki_job_id < 1:
        raise RuntimeError("Libki API did not return a print job ID")
    return libki_job_id


def acknowledge(job_id: str, libki_job_id: int) -> None:
    with internal_request(
        f"/v1/jobs/{job_id}/ack",
        method="POST",
        form={"libki_job_id": str(libki_job_id)},
    ) as response:
        if response.status != 200:
            raise RuntimeError(f"acknowledgement returned {response.status}")
        response.read(65536)


def process_once() -> bool:
    job = next_job()
    if job is None:
        return False
    route = validate_job(job)
    with tempfile.TemporaryDirectory(prefix="mobileprint-") as temporary:
        path = Path(temporary) / "document.pdf"
        download_document(job, path)
        libki_job_id = submit_to_libki(job, route, path)
    acknowledge(job["id"], libki_job_id)
    LOG.info(
        "submitted mobile job %s to held Libki job %s (%s/%s)",
        job["id"],
        libki_job_id,
        job["destination"],
        job["print_mode"],
    )
    return True


def main() -> None:
    while True:
        try:
            worked = process_once()
            if not worked:
                time.sleep(POLL_SECONDS)
        except urllib.error.HTTPError as error:
            LOG.error("internal API HTTP error %s", error.code)
            time.sleep(POLL_SECONDS)
        except Exception as error:
            LOG.error("mobile print adapter error: %s", error)
            time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
