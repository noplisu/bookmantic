"use client";

import { Alert, Button, Spinner } from "@heroui/react";
import { BookCard } from "@/components/book-card";
import type { Book } from "@/types/book";

type SimilarBooksPanelProps = {
  book: Book;
  similar: Book[];
  loading: boolean;
  error: string | null;
  onClose: () => void;
};

export function SimilarBooksPanel({
  book,
  similar,
  loading,
  error,
  onClose,
}: SimilarBooksPanelProps) {
  return (
    <div className="similar-panel-surface bm-fade-up mt-4 rounded-2xl p-4 pl-5">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 className="font-display text-lg">
          More like <span className="text-gradient">&ldquo;{book.title}&rdquo;</span>
        </h3>
        <Button size="sm" variant="ghost" className="text-default-500" onPress={onClose}>
          Close
        </Button>
      </div>
      {loading && (
        <div className="text-default-500 mt-4 flex items-center gap-2 text-sm">
          <Spinner size="sm" />
          Finding related titles…
        </div>
      )}
      {error && (
        <Alert status="danger" className="mt-4">
          <Alert.Title>Similar books</Alert.Title>
          <Alert.Description>{error}</Alert.Description>
        </Alert>
      )}
      {!loading && !error && similar.length === 0 && (
        <p className="text-default-500 mt-4 text-sm">No similar books found.</p>
      )}
      {!loading && similar.length > 0 && (
        <ul className="mt-4 flex flex-col gap-3">
          {similar.map((b, i) => (
            <li key={b.id}>
              <BookCard book={b} rank={i + 1} descriptionMax={200} compact />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
