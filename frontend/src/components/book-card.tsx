"use client";

import { Button, Link } from "@heroui/react";
import { categoryChipClass, formatCategory, SHOW_DEBUG } from "@/lib/book-display";
import type { Book } from "@/types/book";

function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  return `${text.slice(0, max).trim()}…`;
}

type BookCardProps = {
  book: Book;
  rank?: number;
  descriptionMax?: number;
  onSimilar?: (book: Book) => void;
  similarActive?: boolean;
  compact?: boolean;
};

export function BookCard({
  book,
  rank,
  descriptionMax = 420,
  onSimilar,
  similarActive = false,
  compact = false,
}: BookCardProps) {
  return (
    <article
      className={`book-card-surface group relative overflow-hidden rounded-2xl ${compact ? "p-4" : "p-0"}`}
    >
      <div
        className="absolute left-0 top-0 h-full w-1 bg-gradient-to-b from-[#e8b86d] via-[#d4894a] to-[#c45c6e] opacity-80"
        aria-hidden
      />
      <div className={compact ? "pl-3" : "px-5 pb-2 pt-5 pl-4"}>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex gap-3">
            {rank != null && !compact && (
              <span
                className="font-display text-[#e8b86d]/50 mt-0.5 text-2xl font-semibold tabular-nums"
                aria-hidden
              >
                {rank}
              </span>
            )}
            <h3
              className={`font-display text-foreground leading-snug ${compact ? "text-base" : "text-xl"}`}
            >
              {book.title}
            </h3>
          </div>
          {(book.category || SHOW_DEBUG) && (
            <div className="flex flex-shrink-0 flex-wrap items-center gap-2">
              {book.category && (
                <span
                  className={`rounded-full border px-2.5 py-0.5 text-xs font-medium capitalize ${categoryChipClass(book.category)}`}
                >
                  {formatCategory(book.category)}
                </span>
              )}
              {SHOW_DEBUG && typeof book.cosine_similarity === "number" && (
                <span className="text-default-400 text-xs tabular-nums">
                  {(book.cosine_similarity * 100).toFixed(0)}% match
                </span>
              )}
            </div>
          )}
        </div>
        <p
          className={`text-default-600 mt-3 whitespace-pre-wrap leading-relaxed ${compact ? "text-sm" : "text-[0.95rem]"}`}
        >
          {truncate(book.description, descriptionMax)}
        </p>
      </div>
      {!compact && (
        <div className="flex flex-wrap items-center gap-3 border-t border-[#e8b86d]/10 px-5 py-4 pl-4">
          {onSimilar && (
            <Button
              size="sm"
              variant={similarActive ? "primary" : "outline"}
              className={
                similarActive
                  ? "bg-gradient-to-r from-[#e8b86d] to-[#d4894a] font-medium text-[#0c0a0f]"
                  : "border-[#e8b86d]/30"
              }
              onPress={() => onSimilar(book)}
              isDisabled={!book.embedding_ready}
            >
              {similarActive ? "Hide similar" : "Similar books"}
            </Button>
          )}
          {book.purchase_url && (
            <Link
              href={book.purchase_url}
              target="_blank"
              rel="noopener noreferrer sponsored"
              className="text-sm font-semibold text-[#e8b86d] hover:underline"
            >
              Buy on Amazon
            </Link>
          )}
          <Link
            href={book.url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-default-500 text-sm hover:text-[#e8b86d]"
          >
            Open Library →
          </Link>
        </div>
      )}
      {compact && (
        <div className="mt-3 pl-3">
          <Link
            href={book.url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-default-500 text-sm hover:text-[#e8b86d]"
          >
            Open Library →
          </Link>
        </div>
      )}
    </article>
  );
}
