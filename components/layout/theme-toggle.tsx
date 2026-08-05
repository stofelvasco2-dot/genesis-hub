"use client";

import { useEffect, useState } from "react";
import { useTheme } from "next-themes";
import { Moon, Sun } from "lucide-react";
import { Button } from "@/components/ui/button";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  // Evita mismatch de hidratação: o next-themes só sabe o tema real
  // depois de montar no cliente (ele lê do localStorage).
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return (
      <Button
        variant="ghost"
        size="icon"
        className="text-slate-500 dark:text-slate-400 shrink-0"
        disabled
        aria-hidden
      >
        <Sun className="w-5 h-5" />
      </Button>
    );
  }

  const isDark = theme === "dark";

  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(isDark ? "light" : "dark")}
      title={isDark ? "Ativar modo claro" : "Ativar modo escuro"}
      className="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 shrink-0"
    >
      {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
    </Button>
  );
}
