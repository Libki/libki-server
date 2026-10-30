#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 City of Clinton, Iowa
"""Install the pinned noVNC core, its dependencies and license texts."""
import argparse, hashlib, io, tarfile, urllib.request
from pathlib import Path

REVISION = "a8dfd6a3ea3c74244f5ebdaa5a7f1023007a7820"  # noVNC v1.6.0
SHA256 = "ebb8eabcd3670ce1a02e4025f03976826c289121cf631183647bd8325b003403"
URL = f"https://codeload.github.com/novnc/noVNC/tar.gz/{REVISION}"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("server_checkout", type=Path)
    args = parser.parse_args()
    destination = args.server_checkout / "root/static/vendor/novnc"
    if not (args.server_checkout / "lib/Libki.pm").is_file():
        parser.error("expected a Libki server checkout")
    if destination.exists():
        parser.error("noVNC destination already exists; review it before replacing")
    data = urllib.request.urlopen(URL, timeout=60).read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit("noVNC archive checksum mismatch")
    prefix = f"noVNC-{REVISION}/"
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        for member in archive.getmembers():
            if not member.name.startswith(prefix) or not member.isfile():
                continue
            relative = Path(member.name[len(prefix):])
            if ".." in relative.parts or relative.is_absolute():
                raise SystemExit("unsafe archive member")
            if not (relative.parts[0] in ("core", "vendor") or
                    str(relative) == "LICENSE.txt" or
                    str(relative).startswith("docs/LICENSE")):
                continue
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extractfile(member).read())
    print(f"Installed noVNC v1.6.0 with pako and license texts in {destination}")

if __name__ == "__main__":
    main()
