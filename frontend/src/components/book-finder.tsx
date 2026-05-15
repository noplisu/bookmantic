"use client";

import {
  Alert,
  Button,
  Card,
  Chip,
  Label,
  Link,
  Spinner,
  TextArea,
  TextField,
} from "@heroui/react";
import { useCallback, useState } from "react";
import { getApiBase } from "@/lib/api";
import type { Book } from "@/types/book";

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return `${text.slice(0, max).trim()}…`;
}

async function parseJsonResponse(res: Response): Promise<unknown> {
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return { error: text || `HTTP ${res.status}` };
  }
}

export function BookFinder() {
  const [query, setQuery] = useState("");
  const [books, setBooks] = useState<Book[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [similarFor, setSimilarFor] = useState<Book | null>(null);
  const [similar, setSimilar] = useState<Book[]>([]);
  const [similarLoading, setSimilarLoading] = useState(false);
  const [similarError, setSimilarError] = useState<string | null>(null);

  const search = useCallback(async () => {
    const q = query.trim();
    if (!q) {
      setError("Describe what you would like to read.");
      return;
    }
    setError(null);
    setLoading(true);
    setBooks([]);
    setSimilarFor(null);
    setSimilar([]);
    setSimilarError(null);
    try {
      const base = getApiBase();
      const url = `${base}/books/search?q=${encodeURIComponent(q)}`;
      const res = await fetch(url, { headers: { Accept: "application/json" } });
      const data = await parseJsonResponse(res);
      if (!res.ok) {
        const msg =
          typeof data === "object" && data !== null && "error" in data
            ? String((data as { error: unknown }).error)
            : `Search failed (${res.status})`;
        setError(msg);
        return;
      }
      if (!Array.isArray(data)) {
        setError("Unexpected response from server.");
        return;
      }
      setBooks(data as Book[]);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Network error.");
    } finally {
      setLoading(false);
    }
  }, [query]);

  const loadSimilar = useCallback(async (book: Book) => {
    setSimilarFor(book);
    setSimilar([]);
    setSimilarError(null);
    setSimilarLoading(true);
    try {
      const base = getApiBase();
      const res = await fetch(`${base}/books/${book.id}/similar`, {
        headers: { Accept: "application/json" },
      });
      const data = await parseJsonResponse(res);
      if (!res.ok) {
        const msg =
          typeof data === "object" && data !== null && "error" in data
            ? String((data as { error: unknown }).error)
            : `Similar books failed (${res.status})`;
        setSimilarError(msg);
        return;
      }
      if (!Array.isArray(data)) {
        setSimilarError("Unexpected response from server.");
        return;
      }
      setSimilar(data as Book[]);
    } catch (e) {
      setSimilarError(e instanceof Error ? e.message : "Network error.");
    } finally {
      setSimilarLoading(false);
    }
  }, []);

  return (
    <div className="mx-auto flex w-full max-w-3xl flex-col gap-8 px-4 py-10">
      <header className="flex flex-col gap-2">
        <h1 className="text-3xl font-semibold tracking-tight">Book finder</h1>
        <p className="text-default-500 text-sm">
          Describe what you want to read. Results come from the Rails API (
          <code className="text-xs">GET /books/search</code>, top 5).
        </p>
      </header>

      <TextField className="w-full">
        <Label>What would you like to read?</Label>
        <TextArea
          rows={5}
          placeholder="e.g. hopeful stories about friendship, or practical distributed systems"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </TextField>
      <p className="text-default-400 -mt-4 text-xs">Natural language works best.</p>

      <div className="flex flex-wrap items-center gap-3">
        <Button variant="primary" isDisabled={loading} onPress={search}>
          {loading && <Spinner color="current" size="sm" />}
          Find books
        </Button>
      </div>

      {error && (
        <Alert status="danger">
          <Alert.Title>Could not search</Alert.Title>
          <Alert.Description>{error}</Alert.Description>
        </Alert>
      )}

      {books.length > 0 && (
        <section className="flex flex-col gap-4">
          <h2 className="text-lg font-medium">Suggestions</h2>
          <ul className="flex flex-col gap-4">
            {books.map((book) => (
              <li key={book.id}>
                <Card className="p-0">
                  <Card.Header className="flex flex-col items-start gap-1 px-4 pt-4 sm:flex-row sm:items-center sm:justify-between">
                    <Card.Title className="text-lg">{book.title}</Card.Title>
                    <div className="flex flex-wrap items-center gap-2">
                      {book.embedding_ready ? (
                        <Chip color="success" size="sm" variant="soft">
                          Indexed
                        </Chip>
                      ) : (
                        <Chip color="warning" size="sm" variant="soft">
                          Embedding pending
                        </Chip>
                      )}
                      {typeof book.cosine_similarity === "number" && (
                        <Chip size="sm" variant="tertiary">
                          similarity {(book.cosine_similarity * 100).toFixed(1)}%
                        </Chip>
                      )}
                    </div>
                  </Card.Header>
                  <Card.Content className="px-4 pb-2">
                    <Card.Description className="text-default-600 whitespace-pre-wrap">
                      {truncate(book.description, 420)}
                    </Card.Description>
                    {book.genres && (
                      <p className="text-default-400 mt-2 font-mono text-xs">{book.genres}</p>
                    )}
                  </Card.Content>
                  <Card.Footer className="flex flex-wrap gap-3 px-4 pb-4">
                    <Button
                      size="sm"
                      variant="outline"
                      onPress={() => loadSimilar(book)}
                      isDisabled={!book.embedding_ready}
                    >
                      Similar books
                    </Button>
                    <Link href={book.url} target="_blank" rel="noreferrer" className="text-sm">
                      Goodreads
                    </Link>
                  </Card.Footer>
                </Card>
              </li>
            ))}
          </ul>
        </section>
      )}

      {similarFor && (
        <section className="border-default-200 flex flex-col gap-3 rounded-xl border p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-lg font-medium">
              Similar to <span className="text-primary">&ldquo;{similarFor.title}&rdquo;</span>
            </h2>
            <Button size="sm" variant="ghost" onPress={() => setSimilarFor(null)}>
              Close
            </Button>
          </div>
          {similarLoading && (
            <div className="flex items-center gap-2 text-sm">
              <Spinner size="sm" />
              Loading…
            </div>
          )}
          {similarError && (
            <Alert status="danger">
              <Alert.Title>Similar books</Alert.Title>
              <Alert.Description>{similarError}</Alert.Description>
            </Alert>
          )}
          {!similarLoading && similar.length > 0 && (
            <ul className="flex flex-col gap-3">
              {similar.map((b) => (
                <li key={b.id} className="border-default-100 rounded-lg border p-3">
                  <p className="font-medium">{b.title}</p>
                  <p className="text-default-500 mt-1 text-sm">{truncate(b.description, 200)}</p>
                  <Link href={b.url} target="_blank" rel="noreferrer" className="mt-2 inline-block text-sm">
                    Goodreads
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}
    </div>
  );
}
