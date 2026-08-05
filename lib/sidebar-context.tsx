"use client";

import { createContext, useContext, useEffect, useState } from "react";

interface SidebarContextValue {
  isSidebarOpen: boolean;
  setIsSidebarOpen: (val: boolean) => void;
  isMobile: boolean;
}

const SidebarContext = createContext<SidebarContextValue | null>(null);

export function SidebarProvider({ children }: { children: React.ReactNode }) {
  // No mobile é uma gaveta que abre/fecha por cima do conteúdo.
  // No desktop é um colapso: fica larga (w-64) ou só com ícones (w-16).
  // Cada modo guarda seu próprio estado, pra não se misturarem.
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);
  const [isDesktopSidebarOpen, setIsDesktopSidebarOpen] = useState(true);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkIsMobile = () => {
      setIsMobile(window.innerWidth < 1024); // lg breakpoint
    };
    checkIsMobile();
    window.addEventListener("resize", checkIsMobile);
    return () => window.removeEventListener("resize", checkIsMobile);
  }, []);

  const isSidebarOpen = isMobile ? isMobileSidebarOpen : isDesktopSidebarOpen;

  const setIsSidebarOpen = (val: boolean) => {
    if (isMobile) setIsMobileSidebarOpen(val);
    else setIsDesktopSidebarOpen(val);
  };

  return (
    <SidebarContext.Provider value={{ isSidebarOpen, setIsSidebarOpen, isMobile }}>
      {children}
    </SidebarContext.Provider>
  );
}

export function useSidebar() {
  const ctx = useContext(SidebarContext);
  if (!ctx) {
    throw new Error("useSidebar deve ser usado dentro de um SidebarProvider");
  }
  return ctx;
}