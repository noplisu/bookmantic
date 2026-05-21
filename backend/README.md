# semantic-search-rails

Proof of concept for [noplisu.com](https://noplisu.com) and portfolio [github.com/fractalsoft](https://github.com/fractalsoft): a **Rails API** for discovering books by natural-language “what I want to read,” using PostgreSQL (**pgvector**), the [**neighbor**](https://github.com/ankane/neighbor) gem, and **OpenAI `text-embedding-3-small`** embeddings (1536 dimensions).

Example intent: a query like **“dystopian surveillance state”** can surface books whose descriptions never use those exact words, thanks to cosine similarity in embedding space.

**Stack:** Ruby on Rails 8.x, PostgreSQL 16 with the `vector` extension, Sidekiq (Redis), Docker Compose (Postgres + Redis).

**Out of scope for this MVP:** authentication, pagination, fine-tuning, multilingual routing. A separate **Next.js + HeroUI** app lives in [`../frontend/`](../frontend/); see that README for CORS and ports.

---

## Frontend (optional)

The repo includes [`../frontend/`](../frontend/) (Next.js on port **3001** by default). Set in `.env`:

```bash
CORS_ORIGINS=http://localhost:3001
```

so the browser can call this API from the dev UI.

---

## Architecture

1. **`Book` model** — `title`, `url`, `description`, optional `genres` (text), and `embedding` of type `vector(1536)` (nullable until the job runs).
2. **`GenerateEmbeddingJob`** (Sidekiq / Active Job) — the only path that writes embeddings: calls OpenAI and `update_column(:embedding, …)` using **`title` + `description` + `genres`**. OpenAI is **not** called from `after_save` on the model.
3. **`after_create_commit` callback** — only **enqueues** the job (`perform_later`); no vector generation in the HTTP request.
4. **Search by description** — `GET /books/search?q=…`: embeds the query once, then `Book.where.not(embedding: nil).nearest_neighbors(:embedding, vector, distance: "cosine").limit(5)`.
5. **Similar books** — `GET /books/:id/similar`: reuses the book’s stored `embedding` (no OpenAI call); same neighbor query excluding that id, **top 5**. Returns **422** if the book has no embedding yet.
6. **`db/structure.sql` instead of `schema.rb`** — `config.active_record.schema_format = :sql`, because ActiveRecord does not dump the `vector` type correctly into `schema.rb`.
7. **HNSW index** on `embedding` with `vector_cosine_ops` (not IVFFlat).

```
[ HTTP client ]
      │  POST /books
      ▼
[ Rails ] ──after_create_commit──► [ Redis queue ]
                                        │
                                        ▼
                              [ Sidekiq: GenerateEmbeddingJob ]
                                        │
                                        ▼
                              [ OpenAI Embeddings API ]
                                        │
                                        ▼
                              [ UPDATE books.embedding ]

[ HTTP client ]  GET /books/search?q=...
      ▼
[ EmbeddingService ] → OpenAI (query vector)
      ▼
[ PostgreSQL + pgvector + neighbor ] → top 5 neighbors (cosine)

[ HTTP client ]  GET /books/:id/similar
      ▼
[ Book.embedding ] → neighbor search → top 5 other books
```

---

## Requirements

- Ruby 3.3+ (see `.ruby-version`)
- Bundler
- Docker + Docker Compose (recommended for Postgres with pgvector and Redis)

**Required for `./bin/db-reset`:** `postgresql-client` (`psql` on your `PATH`). Rails loads `db/structure.sql` through `psql` using the same `DATABASE_*` settings as the app.

Use **one** Postgres on port `5432`. If a local Postgres and Docker both bind `5432`, Rails and manual `docker compose exec psql` can talk to **different** servers — symptoms include `relation "ar_internal_metadata" already exists` or `pending migrations` after a reset. Stop the extra instance or change `DATABASE_PORT` / Compose port mapping so everything matches.

After `db:create`, Rails may create `ar_internal_metadata` / `schema_migrations` before `structure.sql` runs. The reset script drops and recreates the `public` schema via Rails, then runs `db:schema:load`, so those errors are avoided.

---

## Local setup

### 1. Environment variables

```bash
cp .env.example .env
# Set OPENAI_API_KEY in .env (no quotes around the value unless needed).
```

In **development**, **dotenv-rails** loads `.env` when both `bin/rails server` and **`bundle exec sidekiq`** start — you do not need `source .env` in every terminal. Sidekiq is a separate process and does not inherit env vars only set in the shell where `rails server` runs.

You can still export variables explicitly: `set -a && source .env && set +a`.

### 2. Docker services

```bash
docker compose up -d
```

Starts **PostgreSQL 16 + pgvector** and **Redis** (default ports `5432` and `6379` per `compose.yaml` and `.env.example`).

### 3. Database and seed

Ensure Postgres is available the same way Rails will use it: **`docker compose up -d`** from `backend/` (with `DATABASE_HOST=localhost` in `.env`) is the usual setup. Install **`postgresql-client`** on the host so `./bin/db-reset` can run `psql` against that same instance.

```bash
bundle install
./bin/db-reset
```

The script runs `db:drop`, `db:create`, loads `db/structure.sql`, then `db:seed`.

**Seed CSV (first match wins)** — files live under **[`../data/processed/`](../data/processed/)** (see [`data/README.md`](../data/README.md)):

1. Path from **`BOOK_SEED_PATH`** (absolute or relative to `backend/`), if set
2. Else **`data/processed/books_top45k.csv`**, then **`books_top40k.csv`**
3. Else **`data/processed/book_details.csv`** (small sample shipped in the repo)

Override data root with **`BOOK_DATA_ROOT`** (default: repo `data/`). Columns: `title`, `url`, `description`, `genres`, optional `category`.

- **Default:** first **200** rows (fast dev). Set **`BOOK_SEED_FULL=1`** to load the whole CSV.  
- **`BOOK_SEED_BATCH_SIZE`:** insert batch size for `insert_all` (default `500`).

If **`OPENAI_API_KEY`** is set at seed time, the seed **enqueues** `GenerateEmbeddingJob` for every inserted book (via Sidekiq). It does **not** run embeddings inline. Start **`bundle exec sidekiq`** before or right after seeding. For ~40k books plan on a long queue and OpenAI rate limits.

Re-queue missing embeddings anytime:

```bash
bin/rails books:enqueue_embeddings
```

#### Blended ~45k export (curated classics/learning + OL quotas)

1. Download the **editions** and **works** dumps for the same monthly release ([Open Library data dumps](https://openlibrary.org/developers/dumps)).
2. From the **repo root** (paths adjusted to your files):

Download or place OL dumps in **`data/raw/`** (gitignored):

```bash
python3 scripts/download_ol_dumps.py
```

Generated CSVs and DB dumps go under **`data/processed/`** and **`data/dumps/`**.

```bash
# Resolve curated manifest → full rows with descriptions (defaults use data/)
python3 scripts/resolve_curated_works.py

# Blended export: curated + learning/fiction/nonfiction/popular quotas
python3 scripts/export_ol_top_books.py --target-rows 45000

# Quality gate before seed/embed
python3 scripts/validate_book_export.py
```

**Curated layer:** [`data/processed/curated_manifest.tsv`](../data/processed/curated_manifest.tsv) (committed) lists classics and learning anchors; the resolver writes `curated_books.csv`.

**OL layer:** edition-ranked pools with filters (drops juvenile, dictionaries, large-type, etc.) and quotas (`--quota-learning` 10k, `--quota-fiction` 15k, `--quota-nonfiction` 12k, `--quota-fill` 5k). Optional `--english-only`.

CSV columns: `title`, `url`, `description`, `genres`, `category`. Large exports are gitignored under `data/processed/`. Respect Open Library [Bulk Data](https://openlibrary.org/developers/dumps) / attribution for public use.

Seed with `BOOK_SEED_FULL=1 ./bin/db-reset` (prefers `data/processed/books_top45k.csv`).

**Merge on top of an existing database** (keeps current rows and embeddings; inserts only new URLs):

```bash
bin/rails db:migrate   # if books.category is not applied yet
BOOK_SEED_FULL=1 bin/rails books:import_csv
```

Optional: `BOOK_IMPORT_UPDATE=1` updates `category` / `genres` on rows that already exist (does not re-embed).

To backfill categories after a restore or merge (matches by URL, no re-embed):

```bash
bin/rails books:update_categories
```

Uses `data/processed/books_top45k.csv` by default (`BOOK_SEED_PATH` to override).

#### Staging: ship a prepared database (skip re-seed + embeddings)

After seeding and Sidekiq have filled **`books.embedding`** locally, dump once and restore on staging:

```bash
# Local (uses DATABASE_* from .env — same Postgres as Rails, not necessarily docker exec)
./bin/db-dump
# → data/dumps/semantic_search_rails_prepared.dump (~300MB+ for 45k books)
```

Copy the `.dump` file to staging (S3, scp, etc.; it is gitignored under `data/dumps/`). On the staging host, use **PostgreSQL 16 + pgvector**, create an empty database, then:

```bash
# Example: staging .env points DATABASE_* at your managed Postgres
RAILS_ENV=production DATABASE_NAME=semantic_search_rails_production bin/rails db:create
RAILS_ENV=production DATABASE_NAME=semantic_search_rails_production bin/db-restore
# or: bin/db-restore /path/to/semantic_search_rails_prepared.dump
```

Both scripts default to **`BOOK_DATA_ROOT/data/dumps/`** (repo `data/` when unset), same as seed CSV paths.

`bin/db-restore` runs `pg_restore --clean --if-exists` (schema, data, indexes including HNSW). You still need **`OPENAI_API_KEY`** for search queries (query embedding at request time), not for serving existing book vectors.

Requires **`pg_dump`** / **`pg_restore`** on PATH (`postgresql-client`). Override output path: `./bin/db-dump /path/to/custom.dump`.

### 4. Application processes

Use two terminals:

```bash
# API (e.g. port 3000)
bin/rails server

# Sidekiq worker (embeddings after POST /books)
bundle exec sidekiq
```

Without Sidekiq, new books stay without an `embedding` until jobs are run manually.

---

## API (JSON)

Use header `Content-Type: application/json` for JSON bodies on `POST`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/books` | List books |
| `GET` | `/books/:id` | Single book |
| `POST` | `/books` | Create (`book: { title, url, description, genres? }`) — enqueues embedding job |
| `GET` | `/books/search?q=text` | Semantic match by what you want to read (**5** results; requires `OPENAI_API_KEY`) |
| `GET` | `/books/:id/similar` | **5** books similar to this one (uses stored embedding; **422** if not ready) |

Examples:

```bash
curl -s "http://localhost:3000/books/search?q=magical school coming of age"
```

```bash
curl -s "http://localhost:3000/books/1/similar"
```

```bash
curl -s -X POST http://localhost:3000/books \
  -H "Content-Type: application/json" \
  -d '{"book":{"title":"Example","url":"https://example.com/b/1","description":"A short synopsis for indexing."}}'
```

Search and similar responses include `cosine_distance` and `cosine_similarity` when relevant (lower distance means closer in semantic space).

---

## Regenerating `db/structure.sql`

After migration changes, with local `pg_dump`:

```bash
bin/rails db:migrate
bin/rails db:schema:dump  # with schema_format :sql writes db/structure.sql
```

If `pg_dump` is not on your `PATH`:

```bash
docker compose exec -T postgres pg_dump -U postgres --schema-only --no-privileges --no-owner \
  semantic_search_rails_development > db/structure.sql
```

Ensure the file contains **`schema_migrations`** rows for every applied migration (this repo includes `20250513120000`, `20250514120000`, and `20250519120000` — add new `INSERT` lines when you add migrations).

---

## Sidekiq and `connection_pool`

Sidekiq 7.3.x is **not compatible** with `connection_pool` 3.x (scheduler thread raises `TimedStack#pop` `ArgumentError`). The `Gemfile` pins `connection_pool` ~> 2.4. Run `bundle install` after changes.

---

## Tests / CI

The generated app runs Brakeman and RuboCop in GitHub Actions (`.github/workflows/ci.yml`). Minitest is not configured (`--skip-test` at generation).

---

## License

MIT
