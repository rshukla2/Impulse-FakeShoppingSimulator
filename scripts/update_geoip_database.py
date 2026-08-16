#!/usr/bin/env python3
"""Download and atomically install the GeoLite2 Country MMDB."""

from __future__ import annotations

import argparse
import base64
import os
from pathlib import Path
import shutil
import tarfile
import tempfile
from urllib.request import Request, urlopen

import geoip2.database
from dotenv import load_dotenv


DOWNLOAD_URL = "https://download.maxmind.com/geoip/databases/GeoLite2-Country/download?suffix=tar.gz"

load_dotenv()


def _install_archive(archive_path: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not archive_path.is_file() or archive_path.stat().st_size > 100 * 1024 * 1024:
        raise RuntimeError("GeoLite archive is missing or unexpectedly large")
    with tempfile.TemporaryDirectory(prefix="impulse-geolite-") as temp_dir:
        temp_root = Path(temp_dir)
        candidate_path = temp_root / "GeoLite2-Country.mmdb"
        with tarfile.open(archive_path, mode="r:gz") as bundle:
            for item in bundle.getmembers():
                member_path = Path(item.name)
                if member_path.is_absolute() or ".." in member_path.parts or item.issym() or item.islnk():
                    raise RuntimeError(f"Unsafe archive member: {item.name}")
            member = next(
                (item for item in bundle.getmembers() if Path(item.name).name == "GeoLite2-Country.mmdb" and item.isfile()),
                None,
            )
            if member is None:
                raise RuntimeError("Downloaded archive does not contain GeoLite2-Country.mmdb")
            source = bundle.extractfile(member)
            if source is None:
                raise RuntimeError("Unable to read GeoLite2-Country.mmdb from archive")
            with candidate_path.open("wb") as candidate:
                shutil.copyfileobj(source, candidate)

        with geoip2.database.Reader(str(candidate_path)) as reader:
            database_type = reader.metadata().database_type
            if "Country" not in database_type:
                raise RuntimeError(f"Unexpected MaxMind database type: {database_type}")

        # Stage on the destination filesystem so the final replace is atomic
        # even when the system temporary directory is a separate mount.
        staged_path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="wb",
                prefix=f".{destination.name}.",
                dir=destination.parent,
                delete=False,
            ) as staged, candidate_path.open("rb") as candidate:
                staged_path = Path(staged.name)
                shutil.copyfileobj(candidate, staged)
                staged.flush()
                os.fsync(staged.fileno())
            staged_path.chmod(0o644)
            os.replace(staged_path, destination)
            staged_path = None
        finally:
            if staged_path is not None:
                staged_path.unlink(missing_ok=True)


def install_archive(archive_path: Path, destination: Path) -> None:
    _install_archive(archive_path.expanduser().resolve(), destination.expanduser().resolve())


def download_database(destination: Path, account_id: str, license_key: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    token = base64.b64encode(f"{account_id}:{license_key}".encode("utf-8")).decode("ascii")
    request = Request(
        DOWNLOAD_URL,
        headers={"Authorization": f"Basic {token}", "User-Agent": "Impulse-GeoLite-Updater/1.0"},
    )
    with tempfile.TemporaryDirectory(prefix="impulse-geolite-download-") as temp_dir:
        archive_path = Path(temp_dir) / "GeoLite2-Country.tar.gz"
        with urlopen(request, timeout=60) as response, archive_path.open("wb") as archive:
            shutil.copyfileobj(response, archive)
        _install_archive(archive_path, destination)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--destination",
        default=os.getenv("GEOIP_DATABASE_PATH", "data/GeoLite2-Country.mmdb"),
        help="MMDB installation path",
    )
    parser.add_argument("--archive", help="Install an already-downloaded GeoLite2 Country .tar.gz archive")
    args = parser.parse_args()

    destination = Path(args.destination).expanduser().resolve()
    if args.archive:
        install_archive(Path(args.archive), destination)
    else:
        account_id = os.getenv("MAXMIND_ACCOUNT_ID")
        license_key = os.getenv("MAXMIND_LICENSE_KEY")
        if not account_id or not license_key:
            raise SystemExit("MAXMIND_ACCOUNT_ID and MAXMIND_LICENSE_KEY are required when --archive is not used")
        download_database(destination, account_id, license_key)
    print(f"Installed GeoLite2 Country database at {destination}")


if __name__ == "__main__":
    main()
