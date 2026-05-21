#!/usr/bin/env python3
"""
Blended Open Library export: edition-ranked works with quotas, filters, and curated merge.

Usage:
  python3 scripts/resolve_curated_works.py
  python3 scripts/export_ol_top_books.py \\
    --editions data/raw/ol_dump_editions_2026-04-30.txt \\
    --works data/raw/ol_dump_works_2026-04-30.txt \\
    --curated data/processed/curated_books.csv \\
    --out data/processed/books_top45k.csv \\
    --target-rows 45000
"""
from __future__ import annotations

import argparse
import csv
import gzip
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from heapq import nlargest
from pathlib import Path
from typing import Any, BinaryIO, Generator

from data_paths import DEFAULT_CURATED, DEFAULT_EDITIONS, DEFAULT_EXPORT, DEFAULT_WORKS


def open_maybe_gzip(path: Path) -> Generator[str, None, None]:
    if path.suffix == ".gz" or str(path).endswith(".gz"):
        raw: BinaryIO = gzip.open(path, "rb")
        for line in raw:
            yield line.decode("utf-8", errors="replace")
        raw.close()
    else:
        with path.open("r", encoding="utf-8", errors="replace") as f:
            for line in f:
                yield line


def parse_ol_line(line: str) -> tuple[str, dict[str, Any]] | None:
    parts = line.rstrip("\n").split("\t", 4)
    if len(parts) < 5:
        return None
    try:
        doc = json.loads(parts[4])
    except json.JSONDecodeError:
        return None
    return parts[0], doc


def work_keys_from_edition(doc: dict[str, Any]) -> list[str]:
    works = doc.get("works")
    if not works or not isinstance(works, list):
        return []
    out: list[str] = []
    for item in works:
        if isinstance(item, dict) and "key" in item:
            k = item["key"]
            if isinstance(k, str) and k.startswith("/works/"):
                out.append(k)
    return out


def extract_description(doc: dict[str, Any]) -> str | None:
    raw = doc.get("description")
    if raw is None:
        return None
    if isinstance(raw, str):
        t = raw.strip()
        return t or None
    if isinstance(raw, dict):
        v = raw.get("value")
        if isinstance(v, str) and v.strip():
            return v.strip()
    return None


def extract_title(doc: dict[str, Any]) -> str | None:
    t = doc.get("title")
    if isinstance(t, str) and t.strip():
        return t.strip()
    return None


def extract_subjects(doc: dict[str, Any]) -> list[str]:
    subs = doc.get("subjects")
    if not subs or not isinstance(subs, list):
        return []
    labels: list[str] = []
    for s in subs:
        if isinstance(s, str):
            labels.append(s)
        elif isinstance(s, dict) and isinstance(s.get("title"), str):
            labels.append(s["title"])
    return labels


def subjects_to_genres(doc: dict[str, Any]) -> str:
    labels = extract_subjects(doc)
    return json.dumps(labels) if labels else ""


def has_language(doc: dict[str, Any], code: str) -> bool:
    langs = doc.get("languages")
    if not isinstance(langs, list):
        return False
    for item in langs:
        if isinstance(item, dict):
            k = item.get("key", "")
            if isinstance(k, str) and k.endswith(f"/{code}"):
                return True
        elif isinstance(item, str) and item.endswith(f"/{code}"):
            return True
    return False


EXCLUDE_PATTERNS = re.compile(
    r"\b(juvenile|children'?s|picture book|large type|dictionary|thesaurus|"
    r"encyclopedia|annual|proceedings|bulletin|report)\b",
    re.I,
)


@dataclass
class WorkCandidate:
    key: str
    title: str
    description: str
    genres: str
    subjects: list[str]
    edition_count: int
    english: bool
    subjects_blob: str = field(init=False)

    def __post_init__(self) -> None:
        self.subjects_blob = " ".join(self.subjects).lower()


def count_editions(editions_path: Path) -> Counter[str]:
    counter: Counter[str] = Counter()
    lines = 0
    matched = 0
    for line in open_maybe_gzip(editions_path):
        lines += 1
        if lines % 2_000_000 == 0:
            print(f"  editions lines: {lines:,} …", file=sys.stderr)
        parsed = parse_ol_line(line)
        if not parsed:
            continue
        typ, doc = parsed
        if typ != "/type/edition":
            continue
        for wk in work_keys_from_edition(doc):
            counter[wk] += 1
            matched += 1
    print(
        f"Phase A done: {lines:,} lines, {len(counter):,} distinct works, "
        f"{matched:,} edition→work links.",
        file=sys.stderr,
    )
    return counter


def passes_global_filters(cand: WorkCandidate, *, include_reference: bool, english_only: bool) -> bool:
    blob = f"{cand.title} {cand.subjects_blob}".lower()
    if not include_reference and EXCLUDE_PATTERNS.search(blob):
        return False
    if english_only and not cand.english:
        return False
    return True


def is_learning(cand: WorkCandidate) -> bool:
    b = cand.subjects_blob + " " + cand.title.lower()
    return bool(
        re.search(
            r"\b(programming|computer science|software|finance|business|economics|"
            r"accounting|invest|textbook|textbooks|self[- ]help|psychology|"
            r"management|entrepreneur|marketing)\b",
            b,
            re.I,
        )
    )


def is_fiction(cand: WorkCandidate) -> bool:
    b = cand.subjects_blob + " " + cand.title.lower()
    if re.search(r"\b(juvenile|children'?s|picture book)\b", b, re.I):
        return False
    return bool(re.search(r"\b(fiction|literature|novel|romans)\b", b, re.I))


def is_nonfiction(cand: WorkCandidate) -> bool:
    if is_fiction(cand) or is_learning(cand):
        return False
    b = cand.subjects_blob
    return bool(
        re.search(
            r"\b(history|biography|philosophy|nonfiction|non-fiction|science|"
            r"politics|government|sociology|anthropology)\b",
            b,
            re.I,
        )
    )


def collect_candidates(
    works_path: Path,
    allowed: set[str],
    edition_counts: Counter[str],
    min_description_length: int,
    english_only: bool,
) -> dict[str, WorkCandidate]:
    candidates: dict[str, WorkCandidate] = {}
    lines = 0
    for line in open_maybe_gzip(works_path):
        lines += 1
        if lines % 5_000_000 == 0:
            print(f"  works lines: {lines:,} (candidates {len(candidates):,}) …", file=sys.stderr)
        parsed = parse_ol_line(line)
        if not parsed:
            continue
        typ, doc = parsed
        if typ != "/type/work":
            continue
        key = doc.get("key")
        if not isinstance(key, str) or key not in allowed:
            continue
        desc = extract_description(doc)
        if not desc or len(desc) < min_description_length:
            continue
        title = extract_title(doc)
        if not title:
            continue
        subjects = extract_subjects(doc)
        candidates[key] = WorkCandidate(
            key=key,
            title=title,
            description=desc,
            genres=subjects_to_genres(doc),
            subjects=subjects,
            edition_count=edition_counts.get(key, 0),
            english=has_language(doc, "eng"),
        )
    print(f"Phase C done: {len(candidates):,} candidates from works dump.", file=sys.stderr)
    return candidates


def load_curated(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with path.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            title = (row.get("title") or "").strip()
            url = (row.get("url") or "").strip()
            description = (row.get("description") or "").strip()
            if not title or not url or not description:
                continue
            rows.append(
                {
                    "title": title,
                    "url": url,
                    "description": description,
                    "genres": (row.get("genres") or "").strip(),
                    "category": (row.get("category") or "curated").strip(),
                }
            )
    return rows


def pick_quota(
    pool: list[WorkCandidate],
    n: int,
    used_urls: set[str],
    category: str,
) -> list[dict[str, str]]:
    picked: list[dict[str, str]] = []
    for cand in sorted(pool, key=lambda c: c.edition_count, reverse=True):
        if len(picked) >= n:
            break
        url = f"https://openlibrary.org{cand.key}"
        if url in used_urls:
            continue
        used_urls.add(url)
        picked.append(
            {
                "title": cand.title,
                "url": url,
                "description": cand.description,
                "genres": cand.genres,
                "category": category,
            }
        )
    return picked


def build_blended_rows(
    candidates: dict[str, WorkCandidate],
    curated_rows: list[dict[str, str]],
    *,
    target_rows: int,
    quota_learning: int,
    quota_fiction: int,
    quota_nonfiction: int,
    quota_fill: int,
    include_reference: bool,
    english_only: bool,
) -> list[dict[str, str]]:
    filtered = [
        c
        for c in candidates.values()
        if passes_global_filters(c, include_reference=include_reference, english_only=english_only)
    ]

    learning_pool = [c for c in filtered if is_learning(c)]
    fiction_pool = [c for c in filtered if is_fiction(c)]
    nonfiction_pool = [c for c in filtered if is_nonfiction(c)]
    assigned_keys = {c.key for c in learning_pool + fiction_pool + nonfiction_pool}
    fill_pool = [c for c in filtered if c.key not in assigned_keys]

    used_urls: set[str] = set()
    out: list[dict[str, str]] = []

    for row in curated_rows:
        if row["url"] in used_urls:
            continue
        used_urls.add(row["url"])
        out.append(row)

    print(
        f"Curated: {len(out)} | pools: learning={len(learning_pool)} fiction={len(fiction_pool)} "
        f"nonfiction={len(nonfiction_pool)} fill={len(fill_pool)}",
        file=sys.stderr,
    )

    for batch, cat, limit in [
        (learning_pool, "learning", quota_learning),
        (fiction_pool, "fiction", quota_fiction),
        (nonfiction_pool, "nonfiction", quota_nonfiction),
        (fill_pool, "popular", quota_fill),
    ]:
        picked = pick_quota(batch, limit, used_urls, cat)
        out.extend(picked)
        print(f"  quota {cat}: {len(picked)} (target {limit})", file=sys.stderr)
        if len(out) >= target_rows:
            break

    if len(out) < target_rows:
        remainder = pick_quota(
            sorted(filtered, key=lambda c: c.edition_count, reverse=True),
            target_rows - len(out),
            used_urls,
            "popular",
        )
        out.extend(remainder)
        print(f"  top-up popular: {len(remainder)}", file=sys.stderr)

    return out[:target_rows]


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(
            f,
            fieldnames=["title", "url", "description", "genres", "category"],
            quoting=csv.QUOTE_MINIMAL,
        )
        w.writeheader()
        w.writerows(rows)


def main() -> None:
    ap = argparse.ArgumentParser(description="Blended OL export with quotas and curated merge.")
    ap.add_argument("--editions", type=Path, default=DEFAULT_EDITIONS)
    ap.add_argument("--works", type=Path, default=DEFAULT_WORKS)
    ap.add_argument("--curated", type=Path, default=DEFAULT_CURATED, help="curated_books.csv from resolve_curated_works.py")
    ap.add_argument("--out", type=Path, default=DEFAULT_EXPORT)
    ap.add_argument("--target-rows", type=int, default=45_000)
    ap.add_argument("--top-work-pool", type=int, default=500_000)
    ap.add_argument("--min-description-length", type=int, default=120)
    ap.add_argument("--quota-learning", type=int, default=10_000)
    ap.add_argument("--quota-fiction", type=int, default=15_000)
    ap.add_argument("--quota-nonfiction", type=int, default=12_000)
    ap.add_argument("--quota-fill", type=int, default=5_000)
    ap.add_argument("--include-reference", action="store_true", help="Allow dictionaries/encyclopedias")
    ap.add_argument("--english-only", action="store_true")
    args = ap.parse_args()

    if not args.curated.is_file():
        print(f"Missing curated file: {args.curated}. Run resolve_curated_works.py first.", file=sys.stderr)
        sys.exit(1)

    curated_rows = load_curated(args.curated)
    print(f"Loaded {len(curated_rows)} curated rows.", file=sys.stderr)

    print("Counting editions per work…", file=sys.stderr)
    counter = count_editions(args.editions)
    if not counter:
        print("No edition counts.", file=sys.stderr)
        sys.exit(1)

    pool_n = min(args.top_work_pool, len(counter))
    top_pairs = nlargest(pool_n, counter.items(), key=lambda x: x[1])
    allowed = {wk for wk, _ in top_pairs}
    print(f"Phase B: top {pool_n:,} works by edition count.", file=sys.stderr)

    print("Collecting work candidates…", file=sys.stderr)
    candidates = collect_candidates(
        args.works,
        allowed,
        counter,
        args.min_description_length,
        args.english_only,
    )

    rows = build_blended_rows(
        candidates,
        curated_rows,
        target_rows=args.target_rows,
        quota_learning=args.quota_learning,
        quota_fiction=args.quota_fiction,
        quota_nonfiction=args.quota_nonfiction,
        quota_fill=args.quota_fill,
        include_reference=args.include_reference,
        english_only=args.english_only,
    )

    write_csv(args.out, rows)
    if len(rows) < args.target_rows:
        print(
            f"WARNING: only {len(rows)} rows (wanted {args.target_rows}). "
            "Increase --top-work-pool or quotas.",
            file=sys.stderr,
        )
        sys.exit(2)
    print(f"Wrote {len(rows)} rows to {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
