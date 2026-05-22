import { SiteHeader } from "@/components/site-header";

export function SiteShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="bm-mesh bm-grain relative min-h-full w-full overflow-x-hidden">
      <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden>
        <div className="bm-orb absolute -left-32 top-20 h-72 w-72 rounded-full bg-[#e8b86d]/20 blur-3xl" />
        <div
          className="bm-orb absolute -right-24 top-48 h-96 w-96 rounded-full bg-[#c45c6e]/15 blur-3xl"
          style={{ animationDelay: "2s" }}
        />
        <div
          className="bm-orb absolute bottom-32 left-1/3 h-64 w-64 rounded-full bg-[#d4894a]/10 blur-3xl"
          style={{ animationDelay: "4s" }}
        />
      </div>
      <div className="relative z-10 flex min-h-full w-full flex-col">
        <SiteHeader />
        {children}
      </div>
    </div>
  );
}
