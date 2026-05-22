import type { Metadata } from "next";
import { DM_Sans, Fraunces } from "next/font/google";
import "./globals.css";

import { Providers } from "@/components/providers";

const dmSans = DM_Sans({
  variable: "--font-dm-sans",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

const fraunces = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://bookmatic.com";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "Bookmatic — find books by what you want to read",
    template: "%s · Bookmatic",
  },
  description:
    "Describe the kind of book you want in plain language. Bookmatic matches by meaning, not keywords — powered by semantic search.",
  openGraph: {
    type: "website",
    locale: "en_US",
    url: siteUrl,
    siteName: "Bookmatic",
    title: "Bookmatic — semantic book discovery",
    description:
      "Describe what you want to read. Get book suggestions matched by meaning, not keywords.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Bookmatic — semantic book discovery",
    description:
      "Describe what you want to read. Get book suggestions matched by meaning, not keywords.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${dmSans.variable} ${fraunces.variable} h-full w-full`}
    >
      <body className="font-sans text-foreground flex min-h-full w-full flex-col antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
