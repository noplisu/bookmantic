import { BookFinder } from "@/components/book-finder";
import { SiteFooter } from "@/components/site-footer";
import { SiteShell } from "@/components/site-shell";

export default function Home() {
  return (
    <SiteShell>
      <BookFinder />
      <SiteFooter />
    </SiteShell>
  );
}
