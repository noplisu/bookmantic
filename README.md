# semantic-search-rails

Monorepo layout:

- **[backend/](backend/)** — Rails 8 API (PostgreSQL + pgvector, Sidekiq, OpenAI embeddings). See [backend/README.md](backend/README.md).
- **[frontend/](frontend/)** — Next.js 16 + [HeroUI](https://www.heroui.com/) UI for book search and similar books. See [frontend/README.md](frontend/README.md).

## Quick start

1. **Backend** (from `backend/`): Docker Compose, `./bin/db-reset`, `bin/rails server` on port **3000**.
2. **Frontend** (from `frontend/`): copy `.env.example` to `.env.local`, set `CORS_ORIGINS` on the backend to include `http://localhost:3001`, then `npm install` and `npm run dev` (defaults to port **3001**).
