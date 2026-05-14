# semantic-search-rails

Proof of concept for [noplisu.com](https://noplisu.com) and portfolio [github.com/fractalsoft](https://github.com/fractalsoft): a **Rails API** with semantic search on PostgreSQL (**pgvector**), the [**neighbor**](https://github.com/ankane/neighbor) gem, and **OpenAI `text-embedding-3-small`** embeddings (1536 dimensions).

Example intent: a query like **“annual tax return”** can surface an article about **PIT-37** with no overlapping keywords, thanks to cosine similarity in embedding space.

**Stack:** Ruby on Rails 8.x, PostgreSQL 16 with the `vector` extension, Sidekiq (Redis), Docker Compose (Postgres + Redis).

**Out of scope for this MVP:** frontend, authentication, pagination, fine-tuning, multilingual routing.

---

## Architecture

1. **`Article` model** — `title`, `body`, and an `embedding` column of type `vector(1536)` (nullable until the vector is stored).
2. **`GenerateEmbeddingJob`** (Sidekiq / Active Job) — the only path that writes embeddings: calls the OpenAI API and uses `update_column(:embedding, …)` inside the job. OpenAI is **not** called from `after_save` on the model.
3. **`after_create_commit` callback** — only **enqueues** the job (`perform_later`); no vector generation in the HTTP request.
4. **Search** — `GET /articles/search?q=…`: computes the query embedding synchronously, then `Article.nearest_neighbors(:embedding, vector, distance: "cosine")` (ordering by pgvector cosine distance).
5. **`db/structure.sql` instead of `schema.rb`** — `config.active_record.schema_format = :sql`, because ActiveRecord does not dump the `vector` type correctly into `schema.rb`.
6. **HNSW index** on `embedding` with `vector_cosine_ops` (not IVFFlat).

```
[ HTTP client ]
      │  POST /articles
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
                              [ UPDATE articles.embedding ]

[ HTTP client ]  GET /articles/search?q=...
      ▼
[ EmbeddingService ] → OpenAI (query vector)
      ▼
[ PostgreSQL + pgvector + neighbor ] → nearest neighbors (cosine)
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

The script runs `db:drop`, `db:create`, loads `db/structure.sql` (via host `psql` or `docker compose exec` when `psql` is missing), then `db:seed` — **20 sample articles in English**.

If `OPENAI_API_KEY` is set, the seed also runs `GenerateEmbeddingJob.perform_now` for each row (no double enqueue thanks to `DISABLE_EMBEDDING_CALLBACKS` during bulk insert).

### 4. Application processes

Use two terminals:

```bash
# API (e.g. port 3000)
bin/rails server

# Sidekiq worker (embeddings after POST /articles)
bundle exec sidekiq
```

Without Sidekiq, new articles stay without an `embedding` until jobs are run manually.

---

## API (JSON)

Use header `Content-Type: application/json` for JSON bodies.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/articles` | List articles |
| `GET` | `/articles/:id` | Single article |
| `POST` | `/articles` | Create (`article: { title, body }`) — enqueues embedding job |
| `GET` | `/articles/search?q=text` | Semantic search (requires `OPENAI_API_KEY`) |

Examples:

```bash
curl -s "http://localhost:3000/articles/search?q=annual tax return filing"
```

```bash
curl -s -X POST http://localhost:3000/articles \
  -H "Content-Type: application/json" \
  -d '{"article":{"title":"Title","body":"Body text to index."}}'
```

Search responses include `cosine_distance` and `cosine_similarity` (from neighbor search: lower distance means closer in semantic space).

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

Ensure the file contains the migration version row in `schema_migrations` (this repo includes an `INSERT` for `20250513120000` — update when you add migrations).

---

## Sidekiq and `connection_pool`

Sidekiq 7.3.x is **not compatible** with `connection_pool` 3.x (scheduler thread raises `TimedStack#pop` `ArgumentError`). The `Gemfile` pins `connection_pool` ~> 2.4. Run `bundle install` after changes.

---

## Tests / CI

The generated app runs Brakeman and RuboCop in GitHub Actions (`.github/workflows/ci.yml`). Minitest is not configured (`--skip-test` at generation).

---

## License

MIT
