"""Repo-root data directory paths (shared by export/resolve/validate scripts)."""
from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA = REPO_ROOT / "data"
RAW = DATA / "raw"
PROCESSED = DATA / "processed"
DUMPS = DATA / "dumps"

DEFAULT_MANIFEST = PROCESSED / "curated_manifest.tsv"
DEFAULT_CURATED = PROCESSED / "curated_books.csv"
DEFAULT_EXPORT = PROCESSED / "books_top45k.csv"


def _pick_raw_dump(kind: str) -> Path:
    """Prefer dated .txt, then dated/latest .gz, then latest .txt."""
    patterns = [
        f"ol_dump_{kind}_*.txt",
        f"ol_dump_{kind}_*.txt.gz",
        f"ol_dump_{kind}_latest.txt.gz",
        f"ol_dump_{kind}_latest.txt",
    ]
    for pattern in patterns:
        matches = sorted(RAW.glob(pattern), key=lambda p: p.stat().st_mtime if p.exists() else 0, reverse=True)
        if matches:
            return matches[0]
    return RAW / f"ol_dump_{kind}_latest.txt.gz"


DEFAULT_WORKS = _pick_raw_dump("works")
DEFAULT_EDITIONS = _pick_raw_dump("editions")
