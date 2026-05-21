#!/usr/bin/env python3
"""
Download Open Library monthly data dumps into data/raw/.

Official URLs (see https://openlibrary.org/developers/dumps):
  - ol_dump_editions_latest.txt.gz (~9GB compressed)
  - ol_dump_works_latest.txt.gz (~3GB compressed)

Usage (from repo root):
  python3 scripts/download_ol_dumps.py
  python3 scripts/download_ol_dumps.py --only works
  python3 scripts/download_ol_dumps.py --decompress --date 2026-04-30

Compressed .gz files are enough for export_ol_top_books.py (it reads .gz directly).
--decompress creates large .txt files; only use if you need uncompressed paths.
"""
from __future__ import annotations

import argparse
import gzip
import shutil
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from data_paths import RAW

OL_DATA_BASE = "https://openlibrary.org/data"

DUMPS = {
    "editions": {
        "url": f"{OL_DATA_BASE}/ol_dump_editions_latest.txt.gz",
        "gz_name": "ol_dump_editions_latest.txt.gz",
        "txt_name": "ol_dump_editions_{date}.txt",
    },
    "works": {
        "url": f"{OL_DATA_BASE}/ol_dump_works_latest.txt.gz",
        "gz_name": "ol_dump_works_latest.txt.gz",
        "txt_name": "ol_dump_works_{date}.txt",
    },
}

CHUNK_SIZE = 1024 * 1024  # 1 MiB


def format_bytes(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    for unit in ("KiB", "MiB", "GiB", "TiB"):
        n_f = n / 1024.0
        if n_f < 1024:
            return f"{n_f:.2f} {unit}"
        n = int(n_f)
    return f"{n / 1024:.2f} TiB"


def download_file(url: str, dest: Path, *, force: bool = False) -> None:
    if dest.exists() and not force:
        print(f"Skip (exists): {dest}", file=sys.stderr)
        return

    part = dest.with_suffix(dest.suffix + ".part")
    resume_at = part.stat().st_size if part.exists() else 0
    started = time.monotonic()

    headers = {"User-Agent": "semantic-search-rails/1.0 (Open Library dump downloader)"}
    if resume_at:
        headers["Range"] = f"bytes={resume_at}-"
        print(f"Resuming {dest.name} from {format_bytes(resume_at)} …", file=sys.stderr)
    else:
        print(f"Downloading {url}", file=sys.stderr)
        print(f"  → {dest}", file=sys.stderr)

    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=120) as resp:
            if resume_at and resp.status == 200:
                # Server ignored Range; start over
                print("  Server did not resume; restarting download.", file=sys.stderr)
                part.unlink(missing_ok=True)
                resume_at = 0
                req = Request(url, headers={"User-Agent": headers["User-Agent"]})
                resp = urlopen(req, timeout=120)

            total = resp.headers.get("Content-Length")
            total_size = int(total) + resume_at if total and resume_at else (int(total) if total else None)

            mode = "ab" if resume_at else "wb"
            downloaded = resume_at
            last_log = started

            with part.open(mode) as out:
                while True:
                    chunk = resp.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    out.write(chunk)
                    downloaded += len(chunk)
                    now = time.monotonic()
                    if now - last_log >= 5.0:
                        if total_size:
                            pct = 100.0 * downloaded / total_size
                            print(
                                f"  {format_bytes(downloaded)} / {format_bytes(total_size)} ({pct:.1f}%)",
                                file=sys.stderr,
                            )
                        else:
                            print(f"  {format_bytes(downloaded)} …", file=sys.stderr)
                        last_log = now

    except HTTPError as e:
        print(f"HTTP error {e.code} for {url}: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except URLError as e:
        print(f"Network error for {url}: {e.reason}", file=sys.stderr)
        sys.exit(1)

    part.replace(dest)
    elapsed = time.monotonic() - started
    print(f"Done: {dest} ({format_bytes(dest.stat().st_size)}, {elapsed:.0f}s)", file=sys.stderr)


def decompress_gz(gz_path: Path, txt_path: Path, *, force: bool = False) -> None:
    if txt_path.exists() and not force:
        print(f"Skip decompress (exists): {txt_path}", file=sys.stderr)
        return
    print(f"Decompressing {gz_path.name} → {txt_path.name} …", file=sys.stderr)
    with gzip.open(gz_path, "rb") as src, txt_path.open("wb") as dst:
        shutil.copyfileobj(src, dst, length=CHUNK_SIZE)
    print(f"Done: {txt_path} ({format_bytes(txt_path.stat().st_size)})", file=sys.stderr)


def main() -> None:
    ap = argparse.ArgumentParser(description="Download Open Library editions/works dumps.")
    ap.add_argument(
        "--output-dir",
        type=Path,
        default=RAW,
        help=f"Directory for downloads (default: {RAW})",
    )
    ap.add_argument(
        "--only",
        choices=("editions", "works", "all"),
        default="all",
        help="Which dump(s) to fetch",
    )
    ap.add_argument(
        "--decompress",
        action="store_true",
        help="Also write uncompressed .txt (very large; editions ~50GB+)",
    )
    ap.add_argument(
        "--date",
        type=str,
        default="",
        metavar="YYYY-MM-DD",
        help="Date suffix for decompressed .txt filenames (default: latest)",
    )
    ap.add_argument("--force", action="store_true", help="Re-download / re-decompress even if output exists")
    args = ap.parse_args()

    out_dir: Path = args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    date_suffix = args.date.strip() or "latest"
    which = ["editions", "works"] if args.only == "all" else [args.only]

    for key in which:
        spec = DUMPS[key]
        gz_path = out_dir / spec["gz_name"]
        download_file(spec["url"], gz_path, force=args.force)

        if args.decompress:
            txt_name = spec["txt_name"].format(date=date_suffix)
            txt_path = out_dir / txt_name
            decompress_gz(gz_path, txt_path, force=args.force)

    print("\nDumps ready under:", out_dir, file=sys.stderr)
    print("  export: python3 scripts/export_ol_top_books.py", file=sys.stderr)
    if not args.decompress:
        print("  (pass --editions/--works pointing at the .gz files, or use --decompress)", file=sys.stderr)


if __name__ == "__main__":
    main()
