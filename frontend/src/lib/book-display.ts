export const SHOW_DEBUG =
  process.env.NEXT_PUBLIC_SHOW_DEBUG === "true" ||
  process.env.NEXT_PUBLIC_SHOW_DEBUG === "1";

export function formatCategory(category: string): string {
  return category.replace(/_/g, " ");
}

const CATEGORY_STYLES: Record<string, string> = {
  fiction: "bg-[#c45c6e]/15 text-[#c45c6e] border-[#c45c6e]/25",
  nonfiction: "bg-[#5b8a72]/15 text-[#5b8a72] border-[#5b8a72]/25",
  learning: "bg-[#6b7fd7]/15 text-[#8b9ef0] border-[#6b7fd7]/25",
  popular: "bg-[#e8b86d]/15 text-[#e8b86d] border-[#e8b86d]/30",
  fiction_classic: "bg-[#d4894a]/15 text-[#d4894a] border-[#d4894a]/25",
};

export function categoryChipClass(category: string | null): string {
  if (!category) return "bg-default-100 text-default-600 border-default-200";
  if (CATEGORY_STYLES[category]) return CATEGORY_STYLES[category];
  if (category.startsWith("learn_")) return CATEGORY_STYLES.learning;
  if (category.startsWith("fiction")) return CATEGORY_STYLES.fiction;
  if (category.startsWith("nonfiction")) return CATEGORY_STYLES.nonfiction;
  return "bg-[#e8b86d]/10 text-[#e8b86d] border-[#e8b86d]/20";
}

export const EXAMPLE_QUERIES = [
  {
    label: "Hopeful sci-fi",
    query: "hopeful science fiction about friendship and discovery",
  },
  {
    label: "Startup biography",
    query: "biography of a technology founder building a company",
  },
  {
    label: "Learn Python",
    query: "practical books to learn Python programming from scratch",
  },
] as const;
