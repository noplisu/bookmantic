# Book finder (Next.js + HeroUI)

UI for the Rails API in `../backend/`: semantic search (`GET /books/search`) and similar books (`GET /books/:id/similar`).

## Setup

```bash
cd frontend
npm install
cp .env.example .env.local
```

Edit `.env.local` if the API is not at `http://localhost:3000`.

## Run

```bash
npm run dev
```

Opens **http://localhost:3001** (Rails should stay on **3000**).

In the backend `.env`, allow browser calls from the Next origin:

```bash
CORS_ORIGINS=http://localhost:3001
```

## Build

```bash
npm run build
npm start
```

## Stack

- [Next.js 16](https://nextjs.org/) (App Router)
- [HeroUI](https://www.heroui.com/) (`@heroui/react`, `@heroui/styles`) + Tailwind CSS 4
- [next-themes](https://github.com/pacocoursey/next-themes) (system light/dark via `Providers`)
