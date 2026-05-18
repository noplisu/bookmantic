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

**Seed CSV (first match wins):**

1. Path from **`BOOK_SEED_PATH`** (relative to `backend/`), if set  
2. Else **`db/books_top40k.csv`** if that file exists (generated export from Open Library — see below)  
3. Else **`db/book_details.csv`** (small Goodreads-style sample shipped in the repo)

Columns: `title`, `url`, `description`, `genres` (genres optional).

- **Default:** first **200** rows (fast dev). Set **`BOOK_SEED_FULL=1`** to load the whole CSV.  
- **`BOOK_SEED_BATCH_SIZE`:** insert batch size for `insert_all` (default `500`).

If **`OPENAI_API_KEY`** is set at seed time, the seed **enqueues** `GenerateEmbeddingJob` for every inserted book (via Sidekiq). It does **not** run embeddings inline. Start **`bundle exec sidekiq`** before or right after seeding. For ~40k books plan on a long queue and OpenAI rate limits.

Re-queue missing embeddings anytime:

```bash
bin/rails books:enqueue_embeddings
```

#### Open Library ~40k export (edition popularity + full descriptions)

1. Download the **editions** dump for the same monthly release as the **works** dump (see [Open Library data dumps](https://openlibrary.org/developers/dumps)). Example names: `ol_dump_editions_YYYY-MM-DD.txt.gz`, `ol_dump_works_YYYY-MM-DD.txt`.  
2. From the **repo root**, run (paths adjusted to your files):

```bash
python3 scripts/export_ol_top_books.py \
  --editions /path/to/ol_dump_editions_2026-04-30.txt.gz \
  --works /path/to/ol_dump_works_2026-04-30.txt \
  --out backend/db/books_top40k.csv \
  --target-rows 40000 \
  --top-work-pool 120000
```

The script streams both files (gzip supported), counts **editions per work**, takes the top `--top-work-pool` works, then scans the works dump for those keys with a non-empty **description**. If fewer than `--target-rows` match, increase `--top-work-pool` or lower `--min-description-length`.

Respect Open Library [Bulk Data](https://openlibrary.org/developers/dumps) / attribution expectations for public use.

Generated **`backend/db/books_top40k.csv`** is gitignored (large). Commit only the script under `scripts/`.

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

Ensure the file contains **`schema_migrations`** rows for every applied migration (this repo includes `20250513120000` and `20250514120000` — add new `INSERT` lines when you add migrations).

---

## Sidekiq and `connection_pool`

Sidekiq 7.3.x is **not compatible** with `connection_pool` 3.x (scheduler thread raises `TimedStack#pop` `ArgumentError`). The `Gemfile` pins `connection_pool` ~> 2.4. Run `bundle install` after changes.

---

## Tests / CI

The generated app runs Brakeman and RuboCop in GitHub Actions (`.github/workflows/ci.yml`). Minitest is not configured (`--skip-test` at generation).

---

## License

MIT
