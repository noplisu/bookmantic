"use client";

import { Button } from "@heroui/react";
import { useTheme } from "next-themes";
import { useSyncExternalStore } from "react";
import { LogoMark } from "@/components/logo-mark";

function useIsClient() {
  return useSyncExternalStore(
    () => () => {},
    () => true,
    () => false,
  );
}

export function SiteHeader() {
  const { resolvedTheme, setTheme } = useTheme();
  const isClient = useIsClient();

  return (
    <header className="mx-auto flex w-full max-w-3xl items-center justify-between px-4 py-6">
      <div className="flex items-center gap-3">
        <LogoMark size={40} className="shadow-lg" />
        <span className="font-display text-xl font-semibold tracking-tight">
          Book<span className="text-gradient">mantic</span>
        </span>
      </div>
      {isClient && (
        <Button
          size="sm"
          variant="ghost"
          className="border border-[#e8b86d]/20 text-sm"
          onPress={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}
        >
          {resolvedTheme === "dark" ? "Light" : "Dark"}
        </Button>
      )}
    </header>
  );
}
