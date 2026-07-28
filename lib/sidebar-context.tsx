"use client";

import { createContext, useContext, useEffect, useRef, useState } from "react";

interface SidebarContextValue {
  isSidebarOpen: boolean;
  setIsSidebarOpen: (val: boolean) => void;
  isMobile: boolean;
}

const SidebarContext = createContext<SidebarContextValue | null>(null);

export function SidebarProvider({ children }: { children: React.ReactNode }) {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  // useRef (não useState) porque precisa ser lido com o valor mais atual
  // dentro do listener de "resize", sem sofrer de closure desatualizada.
  const hasInitialized = useRef(false);

  useEffect(() => {
    const checkIsMobile = () => {
      const mobile = window.innerWidth < 1024; // lg breakpoint
      setIsMobile(mobile);
      // Só define o estado inicial do sidebar UMA vez (no primeiro carregamento
      // real da aplicação). Depois disso, o usuário controla manualmente e
      // nada mais reseta esse estado (nem trocar de aba, nem voltar pro app).
      if (!hasInitialized.current) {
        setIsSidebarOpen(!mobile);
        hasInitialized.current = true;
      }
    };

    checkIsMobile();
    window.addEventListener("resize", checkIsMobile);
    return () => window.removeEventListener("resize", checkIsMobile);
  }, []);

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