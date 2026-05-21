#!/usr/bin/env python3
"""
Resolve curated_manifest.tsv rows against an Open Library works dump.

Outputs curated_books.csv (title, url, description, genres, category) for use
with export_ol_top_books.py --curated.

Usage:
  python3 scripts/resolve_curated_works.py \\
    --works data/raw/ol_dump_works_2026-04-30.txt \\
    --manifest data/processed/curated_manifest.tsv \\
    --out data/processed/curated_books.csv
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from data_paths import DEFAULT_CURATED, DEFAULT_MANIFEST, DEFAULT_WORKS
from export_ol_top_books import (
    extract_description,
    extract_title,
    open_maybe_gzip,
    parse_ol_line,
    subjects_to_genres,
)


def normalize_title(s: str) -> str:
    t = re.sub(r"[^\w\s]", " ", s.lower())
    return re.sub(r"\s+", " ", t).strip()


@dataclass
class ManifestEntry:
    category: str
    title: str
    author: str
    work_key: str


def load_manifest(path: Path) -> list[ManifestEntry]:
    entries: list[ManifestEntry] = []
    with path.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            category = (row.get("category") or "").strip()
            title = (row.get("title") or "").strip()
            if not category or not title:
                continue
            entries.append(
                ManifestEntry(
                    category=category,
                    title=title,
                    author=(row.get("author") or "").strip(),
                    work_key=(row.get("work_key") or "").strip(),
                )
            )
    return entries


def author_names(doc: dict) -> list[str]:
    names: list[str] = []
    for field in ("authors", "author"):
        raw = doc.get(field)
        if not isinstance(raw, list):
            continue
        for item in raw:
            if isinstance(item, dict):
                n = item.get("name") or item.get("key", "")
                if isinstance(n, str) and n.strip():
                    names.append(n.strip().lower())
            elif isinstance(item, str):
                names.append(item.lower())
    return names


def author_matches(doc: dict, author_hint: str) -> bool:
    if not author_hint:
        return True
    names = author_names(doc)
    # Work records in the dump often omit authors; do not reject on missing metadata.
    if not names:
        return True
    hint = author_hint.lower()
    blob = " ".join(names)
    return hint in blob or any(hint in n or n in hint for n in names)


def entry_matches_doc(entry: ManifestEntry, doc: dict, key: str) -> bool:
    if entry.work_key:
        return key == entry.work_key or key.endswith(entry.work_key.lstrip("/"))
    title = extract_title(doc)
    if not title:
        return False
    if normalize_title(title) != normalize_title(entry.title):
        return False
    return author_matches(doc, entry.author)


def resolve(
    works_path: Path,
    entries: list[ManifestEntry],
    min_description_length: int,
) -> tuple[list[dict[str, str]], list[ManifestEntry]]:
    by_key: dict[str, ManifestEntry] = {}
    by_title: dict[str, list[ManifestEntry]] = {}
    for e in entries:
        if e.work_key:
            k = e.work_key if e.work_key.startswith("/works/") else f"/works/{e.work_key}"
            by_key[k] = e
        else:
            by_title.setdefault(normalize_title(e.title), []).append(e)

    resolved: dict[str, dict[str, str]] = {}
    pending: list[ManifestEntry] = list(entries)

    lines = 0
    for line in open_maybe_gzip(works_path):
        lines += 1
        if lines % 5_000_000 == 0:
            print(f"  works lines: {lines:,} …", file=sys.stderr)
        parsed = parse_ol_line(line)
        if not parsed:
            continue
        typ, doc = parsed
        if typ != "/type/work":
            continue
        key = doc.get("key")
        if not isinstance(key, str):
            continue

        desc = extract_description(doc)
        if not desc or len(desc) < min_description_length:
            continue
        title = extract_title(doc)
        if not title:
            continue

        matched: ManifestEntry | None = None
        if key in by_key:
            matched = by_key[key]
        else:
            work_norm = normalize_title(title)
            candidates: list[ManifestEntry] = list(by_title.get(work_norm, []))
            if not candidates:
                for entry_norm, es in by_title.items():
                    if entry_norm == work_norm or entry_norm in work_norm or work_norm in entry_norm:
                        candidates.extend(es)
            for e in candidates:
                if author_matches(doc, e.author):
                    matched = e
                    break

        if not matched:
            continue

        dedupe_key = f"{matched.category}\0{matched.title}\0{matched.author}"
        if dedupe_key in resolved:
            continue

        resolved[dedupe_key] = {
            "title": title,
            "url": f"https://openlibrary.org{key}",
            "description": desc,
            "genres": subjects_to_genres(doc),
            "category": matched.category,
        }

    missing = [e for e in entries if f"{e.category}\0{e.title}\0{e.author}" not in resolved]
    rows = list(resolved.values())
    return rows, missing


def main() -> None:
    ap = argparse.ArgumentParser(description="Resolve curated manifest against OL works dump.")
    ap.add_argument("--works", type=Path, default=DEFAULT_WORKS)
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--out", type=Path, default=DEFAULT_CURATED)
    ap.add_argument("--min-description-length", type=int, default=80)
    args = ap.parse_args()

    entries = load_manifest(args.manifest)
    if not entries:
        print("No manifest entries.", file=sys.stderr)
        sys.exit(1)

    print(f"Resolving {len(entries)} manifest entries…", file=sys.stderr)
    rows, missing = resolve(args.works, entries, args.min_description_length)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["title", "url", "description", "genres", "category"],
            quoting=csv.QUOTE_MINIMAL,
        )
        w.writeheader()
        w.writerows(rows)

    print(f"Wrote {len(rows)} rows to {args.out}", file=sys.stderr)
    if missing:
        print(f"WARNING: {len(missing)} manifest entries not resolved:", file=sys.stderr)
        for e in missing[:30]:
            print(f"  [{e.category}] {e.title} ({e.author})", file=sys.stderr)
        if len(missing) > 30:
            print(f"  … and {len(missing) - 30} more", file=sys.stderr)
        sys.exit(2 if len(rows) < len(entries) * 0.5 else 0)


if __name__ == "__main__":
    main()
