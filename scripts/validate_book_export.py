#!/usr/bin/env python3
"""
Validate a blended book export CSV before seeding/embedding.

Usage:
  python3 scripts/validate_book_export.py data/processed/books_top45k.csv
  python3 scripts/validate_book_export.py data/processed/books_top45k.csv --target-rows 45000
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

from data_paths import DEFAULT_EXPORT

EXCLUDE_HEURISTIC = re.compile(
    r"\b(juvenile|children'?s|picture book|large type|dictionary|thesaurus|encyclopedia)\b",
    re.I,
)

CANON_FICTION = [
    "Pride and Prejudice",
    "Moby Dick",
    "To Kill a Mockingbird",
    "The Great Gatsby",
    "1984",
    "Nineteen Eighty-Four",
    "The Lord of the Rings",
    "Don Quixote",
    "Crime and Punishment",
    "The Brothers Karamazov",
    "War and Peace",
    "One Hundred Years of Solitude",
    "The Catcher in the Rye",
    "Jane Eyre",
    "Wuthering Heights",
    "The Hobbit",
    "Frankenstein",
    "Dracula",
    "Alice's Adventures in Wonderland",
]

LEARN_FINANCE = [
    "Intelligent Investor",
    "Random Walk Down Wall Street",
    "Rich Dad Poor Dad",
    "Think and Grow Rich",
    "Psychology of Money",
    "Common Sense Investing",
]

LEARN_PROGRAMMING = [
    "Clean Code",
    "Pragmatic Programmer",
    "Introduction to Algorithms",
    "C Programming Language",
    "Design Patterns",
    "Structure and Interpretation",
    "Python Crash Course",
    "JavaScript: The Good Parts",
    "Code Complete",
    "You Don't Know JS",
]


def load_rows(path: Path) -> list[dict[str, str]]:
    return list(csv.DictReader(path.open(encoding="utf-8", newline="")))


def title_hits(rows: list[dict[str, str]], needles: list[str]) -> list[tuple[str, str | None]]:
    out: list[tuple[str, str | None]] = []
    for needle in needles:
        n = needle.lower()
        hit = None
        for r in rows:
            if n in r.get("title", "").lower() or n in (r.get("description", "")[:500]).lower():
                hit = r["title"]
                break
        out.append((needle, hit))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Validate book export CSV.")
    ap.add_argument("csv_path", type=Path, nargs="?", default=DEFAULT_EXPORT)
    ap.add_argument("--target-rows", type=int, default=45_000)
    ap.add_argument("--min-canon-found", type=int, default=15)
    ap.add_argument("--min-finance-found", type=int, default=4)
    ap.add_argument("--min-programming-found", type=int, default=4)
    args = ap.parse_args()

    if not args.csv_path.is_file():
        print(f"File not found: {args.csv_path}", file=sys.stderr)
        sys.exit(1)

    rows = load_rows(args.csv_path)
    errors: list[str] = []
    warnings: list[str] = []

    print(f"Rows: {len(rows)} (target {args.target_rows})")
    if len(rows) < args.target_rows:
        errors.append(f"Row count {len(rows)} < target {args.target_rows}")

    urls = [r.get("url", "") for r in rows]
    dupes = len(urls) - len(set(urls))
    if dupes:
        errors.append(f"Duplicate URLs: {dupes}")

    categories = Counter((r.get("category") or "unknown").strip() for r in rows)
    print("Category distribution:")
    for cat, n in categories.most_common():
        print(f"  {cat}: {n}")

    excluded = sum(
        1
        for r in rows
        if EXCLUDE_HEURISTIC.search(
            f"{r.get('title', '')} {r.get('genres', '')} {r.get('description', '')[:200]}"
        )
    )
    pct = 100.0 * excluded / max(len(rows), 1)
    print(f"Heuristic noise (juvenile/dictionary/large-type): {excluded} ({pct:.1f}%)")
    if pct > 8.0:
        warnings.append(f"Noise rows above 8%: {pct:.1f}%")

    canon = title_hits(rows, CANON_FICTION)
    finance = title_hits(rows, LEARN_FINANCE)
    programming = title_hits(rows, LEARN_PROGRAMMING)

    def report_group(name: str, hits: list[tuple[str, str | None]], min_found: int) -> int:
        found = sum(1 for _, h in hits if h)
        print(f"\n{name} ({found}/{len(hits)} found, min {min_found}):")
        for needle, hit in hits:
            mark = "OK" if hit else "MISS"
            print(f"  [{mark}] {needle}" + (f" -> {hit[:55]}" if hit else ""))
        if found < min_found:
            errors.append(f"{name}: only {found}/{min_found} required hits")
        return found

    report_group("Canon fiction", canon, args.min_canon_found)
    report_group("Learn finance", finance, args.min_finance_found)
    report_group("Learn programming", programming, args.min_programming_found)

    for w in warnings:
        print(f"WARNING: {w}", file=sys.stderr)
    for e in errors:
        print(f"ERROR: {e}", file=sys.stderr)

    if errors:
        sys.exit(1)
    print("\nValidation passed.")


if __name__ == "__main__":
    main()
