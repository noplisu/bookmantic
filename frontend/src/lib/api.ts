/**
 * Public Rails API base URL (no trailing slash), if set.
 * When unset, the app uses same-origin `/api/*` (proxied by Next in production).
 */
export function getApiBase(): string {
  return process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "") ?? "";
}

/** Build a URL for a Rails API path (e.g. `/books/search`). */
export function apiUrl(path: string): string {
  const p = path.startsWith("/") ? path : `/${path}`;
  const base = getApiBase();
  if (!base) return `/api${p}`;
  return `${base}${p}`;
}
