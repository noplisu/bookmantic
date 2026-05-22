import { FractalSoftMark } from "@/components/fractal-soft-mark";

export function SiteFooter() {
  return (
    <footer className="relative z-10 mt-16 border-t border-[#e8b86d]/10 px-4 py-10">
      <div className="mx-auto flex w-full max-w-3xl flex-col gap-4 text-sm">
        <p className="text-default-500 leading-relaxed">
          Book data from{" "}
          <a
            href="https://openlibrary.org"
            target="_blank"
            rel="noopener noreferrer"
            className="font-medium text-[#e8b86d] hover:underline"
          >
            Open Library
          </a>
          . Semantic search with OpenAI embeddings and PostgreSQL pgvector.
        </p>
        <a
          href="https://fractalsoft.org"
          target="_blank"
          rel="noopener noreferrer"
          className="group inline-flex w-fit items-center gap-2 text-xs text-default-400 transition-colors hover:text-default-600"
        >
          <span className="text-[#c3261c] transition-colors group-hover:text-[#e8b86d]">
            <FractalSoftMark size={18} />
          </span>
          <span>
            Built by <span className="font-medium text-default-500 group-hover:text-[#e8b86d]">Fractal Soft</span>
          </span>
        </a>
      </div>
    </footer>
  );
}
