"use client";

import { createContext, useContext, useEffect, useState } from "react";

interface SidebarContextValue {
  isSidebarOpen: boolean;
  setIsSidebarOpen: (val: boolean) => void;
  isMobile: boolean;
}

const SidebarContext = createContext<SidebarContextValue | null>(null);

export function SidebarProvider({ children }: { children: React.ReactNode }) {
  // No mobile, o usuário controla (drawer que abre/fecha). No desktop, a
  // barra lateral fica sempre fixa/aberta — sem nenhuma lógica de
  // abrir/fechar automática, então não tem mais como "piscar".
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkIsMobile = () => {
      setIsMobile(window.innerWidth < 1024); // lg breakpoint
    };
    checkIsMobile();
    window.addEventListener("resize", checkIsMobile);
    return () => window.removeEventListener("resize", checkIsMobile);
  }, []);

  const isSidebarOpen = isMobile ? isMobileSidebarOpen : true;

  const setIsSidebarOpen = (val: boolean) => {
    // No desktop a barra é sempre fixa: ignora qualquer tentativa de fechar.
    if (isMobile) setIsMobileSidebarOpen(val);
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