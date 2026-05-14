# semantic-search-rails

Proof of concept for [noplisu.com](https://noplisu.com) and portfolio [github.com/fractalsoft](https://github.com/fractalsoft): a **Rails API** for discovering books by natural-language “what I want to read,” using PostgreSQL (**pgvector**), the [**neighbor**](https://github.com/ankane/neighbor) gem, and **OpenAI `text-embedding-3-small`** embeddings (1536 dimensions).

Example intent: a query like **“dystopian surveillance state”** can surface books whose descriptions never use those exact words, thanks to cosine similarity in embedding space.

**Stack:** Ruby on Rails 8.x, PostgreSQL 16 with the `vector` extension, Sidekiq (Redis), Docker Compose (Postgres + Redis).

**Out of scope for this MVP:** frontend, authentication, pagination, fine-tuning, multilingual routing.

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

Optional on the host: `postgresql-client` (`psql`, `pg_dump`) — simplifies `bin/rails db:structure:load` / `db:structure:dump`. Without it, use `./bin/db-reset` (loads `structure.sql` via the Postgres container).

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

```bash
bundle install
./bin/db-reset
```

The script runs `db:drop`, `db:create`, loads `db/structure.sql`, then `db:seed`.

Seeds load from **[db/book_details.csv](db/book_details.csv)** (Goodreads-style rows: `title`, `url`, `description`, `genres`).

- **Default:** first **200** rows (keeps local OpenAI cost and seed time reasonable). Override with `BOOK_SEED_LIMIT=500` (example).
- **Full CSV:** set **`BOOK_SEED_FULL=1`** to load every row (large; many OpenAI calls if `OPENAI_API_KEY` is set).

If `OPENAI_API_KEY` is set, the seed runs `GenerateEmbeddingJob.perform_now` per book after bulk insert (`DISABLE_EMBEDDING_CALLBACKS` avoids double enqueue during `create!`).

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
