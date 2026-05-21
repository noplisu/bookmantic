# Data directory

Large and generated artifacts live here (not under `backend/`, `frontend/`, or `scripts/`).

| Path | Contents | Git |
|------|----------|-----|
| `raw/` | Open Library dumps (`ol_dump_editions_*.txt.gz`, `ol_dump_works_*.txt.gz`, or decompressed `.txt`) | Ignored |
| `processed/` | Curated manifest, resolved curated CSV, export CSVs (`books_top45k.csv`) | Manifest only |
| `dumps/` | Postgres dumps from `backend/bin/db-dump` | Ignored |

## Download raw dumps

From the [Open Library dumps page](https://openlibrary.org/developers/dumps) (~9GB editions + ~3GB works, compressed):

```bash
python3 scripts/download_ol_dumps.py
# Optional: python3 scripts/download_ol_dumps.py --decompress --date 2026-04-30
```

Past monthly releases are on [Archive.org `ol_exports`](https://archive.org/details/ol_exports?sort=-publicdate); place those files in `data/raw/` manually if you need a specific month.

## Pipeline (from repo root)

```bash
python3 scripts/download_ol_dumps.py   # if raw/ is empty
python3 scripts/resolve_curated_works.py
python3 scripts/export_ol_top_books.py
python3 scripts/validate_book_export.py data/processed/books_top45k.csv
cd backend && BOOK_SEED_FULL=1 bin/rails books:import_csv
```

Override paths with CLI flags or `BOOK_SEED_PATH` / `BOOK_DATA_ROOT`.
