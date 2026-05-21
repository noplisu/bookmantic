# Book finder (Next.js + HeroUI)

UI for the Rails API in `../backend/`: semantic search (`GET /books/search`) and similar books (`GET /books/:id/similar`).

## Setup

```bash
cd frontend
npm install
cp .env.example .env.local
```

## API routing

- **Development (default):** set `NEXT_PUBLIC_API_BASE_URL=http://localhost:3000` in `.env.local`. The UI calls Rails directly; set `CORS_ORIGINS=http://localhost:3001` on the backend.
- **Development (proxied):** leave `NEXT_PUBLIC_API_BASE_URL` unset. The UI calls `/api/...`; Next rewrites to `http://localhost:3000` (no CORS needed).
- **Production (Docker):** leave `NEXT_PUBLIC_API_BASE_URL` unset. The UI uses `/api/...`; the image is built with `INTERNAL_API_URL=http://backend:80` so Next proxies to the internal Rails container. Only the Next app is exposed via Caddy.

Helper: `apiUrl('/books/search')` in `src/lib/api.ts`.

## Run

```bash
npm run dev
```

Opens **http://localhost:3001** (Rails should stay on **3000**).

## Build

```bash
npm run build
npm start
```

## Stack

- [Next.js 16](https://nextjs.org/) (App Router)
- [HeroUI](https://www.heroui.com/) (`@heroui/react`, `@heroui/styles`) + Tailwind CSS 4
- [next-themes](https://github.com/pacocoursey/next-themes) (system light/dark via `Providers`)
