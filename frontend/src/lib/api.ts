/**
 * Rails API base URL (no trailing slash).
 * Default matches backend `bin/rails server` on port 3000 while Next runs on 3001.
 */
const DEFAULT_API_BASE = "http://localhost:3000";

export function getApiBase(): string {
  const base = process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "");
  return base || DEFAULT_API_BASE;
}
