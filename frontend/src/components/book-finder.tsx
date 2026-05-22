"use client";

import {
  Alert,
  Button,
  Label,
  Spinner,
  TextArea,
  TextField,
} from "@heroui/react";
import { motion } from "framer-motion";
import { useCallback, useEffect, useRef, useState } from "react";
import { apiUrl } from "@/lib/api";
import { EXAMPLE_QUERIES } from "@/lib/book-display";
import { BookCard } from "@/components/book-card";
import { SimilarBooksPanel } from "@/components/similar-books-panel";
import type { Book } from "@/types/book";

async function parseJsonResponse(res: Response): Promise<unknown> {
  const text = await res.text();
  if (!text) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return { error: text || `HTTP ${res.status}` };
  }
}

const listVariants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.4, ease: "easeOut" as const } },
};

export function BookFinder() {
  const [query, setQuery] = useState("");
  const [books, setBooks] = useState<Book[]>([]);
  const [hasSearched, setHasSearched] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [similarFor, setSimilarFor] = useState<Book | null>(null);
  const [similar, setSimilar] = useState<Book[]>([]);
  const [similarLoading, setSimilarLoading] = useState(false);
  const [similarError, setSimilarError] = useState<string | null>(null);
  const similarPanelRef = useRef<HTMLDivElement | null>(null);

  const closeSimilar = useCallback(() => {
    setSimilarFor(null);
    setSimilar([]);
    setSimilarError(null);
    setSimilarLoading(false);
  }, []);

  const runSearch = useCallback(
    async (q: string) => {
      const trimmed = q.trim();
      if (!trimmed) {
        setError("Describe what you would like to read.");
        return;
      }
      setError(null);
      setHasSearched(false);
      setLoading(true);
      setBooks([]);
      closeSimilar();
      try {
        const url = `${apiUrl("/books/search")}?q=${encodeURIComponent(trimmed)}`;
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
        setHasSearched(true);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Network error.");
      } finally {
        setLoading(false);
      }
    },
    [closeSimilar],
  );

  const search = useCallback(() => runSearch(query), [query, runSearch]);

  const loadSimilar = useCallback(
    async (book: Book) => {
      if (similarFor?.id === book.id) {
        closeSimilar();
        return;
      }
      setSimilarFor(book);
      setSimilar([]);
      setSimilarError(null);
      setSimilarLoading(true);
      try {
        const res = await fetch(apiUrl(`/books/${book.id}/similar`), {
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
    },
    [similarFor?.id, closeSimilar],
  );

  useEffect(() => {
    if (similarFor && similarPanelRef.current) {
      similarPanelRef.current.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }, [similarFor, similarLoading]);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      search();
    }
  };

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-10 px-4 pb-12">
      <motion.header
        className="flex flex-col gap-4 pt-2 text-center sm:text-left"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
      >
        <p className="text-default-500 text-sm font-medium tracking-[0.2em] uppercase">
          Semantic discovery
        </p>
        <h1 className="font-display text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl">
          Find your next book by{" "}
          <span className="text-gradient italic">feeling</span>, not keywords
        </h1>
        <p className="text-default-500 mx-auto max-w-xl text-base leading-relaxed sm:mx-0 sm:text-lg">
          Describe the mood, ideas, or world you want. We match thousands of titles by meaning.
        </p>
      </motion.header>

      <motion.div
        className="glass-panel rounded-3xl p-6 sm:p-8"
        initial={{ opacity: 0, y: 24 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.55, delay: 0.1, ease: "easeOut" }}
      >
        <TextField className="w-full">
          <Label className="text-default-600 mb-2 text-sm font-medium">
            What would you like to read?
          </Label>
          <TextArea
            rows={4}
            placeholder="A quiet novel about reinvention, or a sharp guide to system design…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            className="min-h-[120px] text-base"
          />
        </TextField>
        <p className="text-default-400 mt-3 text-xs">
          Enter to search · Shift+Enter for a new line
        </p>

        <div className="mt-5 flex flex-wrap gap-2">
          {EXAMPLE_QUERIES.map((example) => (
            <button
              key={example.label}
              type="button"
              className="chip-example rounded-full px-4 py-1.5 text-sm font-medium"
              onClick={() => {
                setQuery(example.query);
                runSearch(example.query);
              }}
            >
              {example.label}
            </button>
          ))}
        </div>

        <div className="mt-6">
          <Button
            variant="primary"
            size="lg"
            isDisabled={loading}
            onPress={search}
            className="w-full bg-gradient-to-r from-[#e8b86d] via-[#d4894a] to-[#c45c6e] font-semibold text-[#0c0a0f] shadow-lg shadow-[#e8b86d]/20 sm:w-auto sm:min-w-[200px]"
          >
            {loading ? <Spinner color="current" size="sm" /> : null}
            {loading ? "Searching…" : "Find books"}
          </Button>
        </div>
      </motion.div>

      {error && (
        <Alert status="danger" className="rounded-2xl">
          <Alert.Title>Could not search</Alert.Title>
          <Alert.Description>{error}</Alert.Description>
        </Alert>
      )}

      {hasSearched && !loading && !error && books.length === 0 && (
        <Alert status="warning" className="rounded-2xl">
          <Alert.Title>No matches</Alert.Title>
          <Alert.Description>
            Try a broader description — mood, genre, topic, or setting — and search again.
          </Alert.Description>
        </Alert>
      )}

      {books.length > 0 && (
        <section className="flex flex-col gap-5">
          <div className="flex items-baseline justify-between gap-4">
            <h2 className="font-display text-2xl font-medium">Your matches</h2>
            <span className="text-default-400 text-sm tabular-nums">{books.length} books</span>
          </div>
          <motion.ul
            className="flex flex-col gap-5"
            variants={listVariants}
            initial="hidden"
            animate="show"
          >
            {books.map((book, index) => (
              <motion.li key={book.id} variants={itemVariants}>
                <BookCard
                  book={book}
                  rank={index + 1}
                  onSimilar={loadSimilar}
                  similarActive={similarFor?.id === book.id}
                />
                {similarFor?.id === book.id && (
                  <div ref={similarPanelRef}>
                    <SimilarBooksPanel
                      book={similarFor}
                      similar={similar}
                      loading={similarLoading}
                      error={similarError}
                      onClose={closeSimilar}
                    />
                  </div>
                )}
              </motion.li>
            ))}
          </motion.ul>
        </section>
      )}
    </main>
  );
}
