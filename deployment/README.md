# Production deployment (VPS)

Docker Compose stack: **Caddy** (HTTPS entrypoint) → **Next.js frontend** → **Rails API** (internal only), plus **Postgres** (pgvector), **Redis**, and **Sidekiq**.

Images are built on every push to `main` and published to **GHCR**; the VPS pulls them via GitHub Actions over SSH.

## Architecture

- Only **Caddy** binds host ports `80` and `443`.
- The browser talks to Next.js on your domain; API calls use same-origin `/api/*`, which Next proxies to `http://backend:80` inside the Docker network.
- Rails is not exposed on the public internet.

## One-time VPS setup

You do **not** need to clone the repo on the VPS. Only three files live under `/opt/semantic-search-rails/deployment/`: `compose.yaml`, `Caddyfile`, and `.env`.

1. Install [Docker Engine](https://docs.docker.com/engine/install/) and the Compose plugin.
2. On your machine (from a clone of this repo), create `deployment/.env` from `.env.example` and fill in secrets.
3. Copy the three files to the VPS:

   ```bash
   # From the repo root (or deployment/)
   VPS_USER=deploy VPS_HOST=YOUR_VPS_IP ./deployment/sync-to-vps.sh
   ```

   This creates `/opt/semantic-search-rails/deployment/` and uploads `compose.yaml`, `Caddyfile`, and `.env`.

   - `RAILS_MASTER_KEY`: contents of `backend/config/master.key` (never commit).
   - `BACKEND_IMAGE` / `FRONTEND_IMAGE`: e.g. `ghcr.io/youruser/semantic-search-rails-backend:latest` (owner must be **lowercase**).

   To update only compose/Caddyfile later (leave remote `.env` untouched):

   ```bash
   ./deployment/sync-to-vps.sh --config-only deploy@YOUR_VPS_IP
   ```

4. Log in to GHCR on the VPS (read-only PAT with `read:packages`):

   ```bash
   echo YOUR_GHCR_READ_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USER --password-stdin
   ```

5. DNS: point `DOMAIN` (A/AAAA) to the VPS IP.
6. Firewall: allow `80` and `443` only.

### GitHub Actions secrets

| Secret | Purpose |
|--------|---------|
| `VPS_HOST` | VPS hostname or IP |
| `VPS_USER` | SSH user |
| `VPS_SSH_KEY` | Private SSH key |
| `GHCR_TOKEN` | Optional: PAT for `docker login` on VPS during deploy (if not logged in permanently) |

`GITHUB_TOKEN` in the workflow is used to **push** images from CI.

## First database (prepared dump)

The prepared dump (~458MB) is not in git. On the VPS, create a data directory (separate from deployment config):

```bash
ssh deploy@YOUR_VPS_IP 'mkdir -p /opt/semantic-search-rails/data/dumps'
scp data/dumps/semantic_search_rails_prepared.dump deploy@YOUR_VPS_IP:/opt/semantic-search-rails/data/dumps/
```

Start Postgres, then restore:

```bash
cd /opt/semantic-search-rails/deployment
docker compose up -d postgres
# Wait until healthy, then:
docker compose run --rm \
  --entrypoint bin/db-restore \
  -e RAILS_ENV=production \
  -e BOOK_DATA_ROOT=/data \
  -e DATABASE_HOST=postgres \
  -v /opt/semantic-search-rails/data:/data:ro \
  backend
```

Bring up the full stack (or let the deploy workflow do it):

```bash
docker compose pull
docker compose up -d
```

`backend` runs `db:prepare` on boot for migrations only.

## Manual operations

```bash
cd /opt/semantic-search-rails/deployment

# Logs
docker compose logs -f caddy frontend backend

# Restart after .env change
docker compose up -d

# Roll back images: set BACKEND_IMAGE / FRONTEND_IMAGE to a specific SHA tag in .env, then:
docker compose pull && docker compose up -d
```

## Local smoke test (optional)

From the repo root, after building images locally:

```bash
cd deployment
cp .env.example .env
# Set images to local tags if you built them, DOMAIN=localhost, etc.
docker compose up -d
```

For local HTTPS you may need a different Caddy setup; production expects a real `DOMAIN` and DNS.

## Deploy workflow

On push to `main`, `.github/workflows/deploy.yml`:

1. Builds and pushes `semantic-search-rails-backend` and `semantic-search-rails-frontend` to `ghcr.io/<owner>/...`.
2. Runs `deployment/sync-to-vps.sh --config-only` (compose + Caddyfile; does not overwrite `.env`).
3. SSHs to the VPS and runs `docker compose pull` + `docker compose up -d` in `/opt/semantic-search-rails/deployment`.

Ensure `deployment/.env` on the VPS uses `:latest` (or pin SHAs in `.env` for reproducibility).
