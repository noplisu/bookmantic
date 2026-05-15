/**
 * Rails API base URL (no trailing slash).
 * Default matches backend `bin/rails server` on port 3000 while Next runs on 3001.
 */
export function getApiBase(): string {
  const base = process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "");
  if (base) return base;
  if (typeof window !== "undefined") {
    return "";
  }
  return "http://localhost:3000";
}
