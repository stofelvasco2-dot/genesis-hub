"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { LayoutDashboard, KanbanSquare, ListTodo, Settings, Users, LogOut } from "lucide-react";
import { useStore } from "@/lib/store";
import { LOGO_URL } from "@/lib/branding";

const NAV_ITEMS = [
  { name: "Dashboard", href: "/", icon: LayoutDashboard },
  { name: "Kanban", href: "/kanban", icon: KanbanSquare },
  { name: "Todas as Tarefas", href: "/tasks", icon: ListTodo },
];

const ADMIN_ITEMS = [
  { name: "Configurações", href: "/admin/settings", icon: Settings },
];

export function Sidebar({ isOpen, setIsOpen, isMobile }: { isOpen: boolean; setIsOpen: (val: boolean) => void; isMobile: boolean }) {
  const pathname = usePathname();
  const { currentUser, signOut } = useStore();

  const isAdminOrGestor = currentUser?.role === 'Admin' || currentUser?.role === 'Gestor';

  return (
    <aside className={cn(
      "bg-slate-900 flex flex-col border-r border-slate-200 h-full overflow-hidden transition-all duration-300",
      isOpen ? "w-64" : "w-16"
    )}>
      <div className={cn("p-4 border-b border-slate-800 flex items-center h-16", isOpen ? "justify-between" : "justify-center")}>
        <div className={cn("flex items-center gap-3", !isOpen && "hidden")}>
          <img src={LOGO_URL} alt="Genesis Hub" className="h-8 object-contain" />
        </div>
        {!isOpen && (
          <img src={LOGO_URL} alt="Genesis Hub" className="h-8 w-8 object-cover rounded-lg" />
        )}
      </div>

      <nav className="flex-1 py-4 flex flex-col gap-1 px-3 overflow-y-auto">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.name}
              href={item.href}
              title={item.name}
              className={cn(
                "flex items-center rounded-md text-sm font-medium transition-colors h-10",
                isOpen ? "px-3 gap-3" : "justify-center",
                isActive 
                  ? "bg-slate-800 text-white" 
                  : "text-slate-400 hover:bg-slate-800 hover:text-white"
              )}
            >
              <item.icon className={cn("shrink-0", isOpen ? "w-5 h-5" : "w-6 h-6", isActive ? "opacity-100" : "opacity-80")} />
              {isOpen && <span className="truncate">{item.name}</span>}
            </Link>
          );
        })}

        {isAdminOrGestor && (
          <>
            <div className={cn("mt-6 mb-2 px-3 text-[10px] font-bold text-slate-500 uppercase tracking-wider", !isOpen && "hidden text-center")}>
              {isOpen ? "Gestão" : "..."}
            </div>
            {ADMIN_ITEMS.map((item) => {
              const isActive = pathname.startsWith(item.href);
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  title={item.name}
                  className={cn(
                    "flex items-center rounded-md text-sm font-medium transition-colors h-10",
                    isOpen ? "px-3 gap-3" : "justify-center",
                    isActive 
                      ? "bg-slate-800 text-white" 
                      : "text-slate-400 hover:bg-slate-800 hover:text-white"
                  )}
                >
                  <item.icon className={cn("shrink-0", isOpen ? "w-5 h-5" : "w-6 h-6", isActive ? "opacity-100" : "opacity-80")} />
                  {isOpen && <span className="truncate">{item.name}</span>}
                </Link>
              );
            })}
          </>
        )}
      </nav>

      <div className="p-4 border-t border-slate-800 flex flex-col gap-4">
        {currentUser && (
          <div className={cn("flex items-center", isOpen ? "gap-3 justify-between" : "justify-center flex-col gap-2")}>
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold text-xs border border-blue-500/40 shrink-0">
                {currentUser.name ? currentUser.name.split(' ').map((n: string) => n[0]).join('').substring(0, 2).toUpperCase() : 'U'}
              </div>
              {isOpen && (
                <div className="flex flex-col truncate max-w-[120px]">
                  <span className="text-xs font-semibold text-white truncate">{currentUser.name}</span>
                  <span className="text-[10px] text-slate-500 uppercase truncate">{currentUser.role}</span>
                </div>
              )}
            </div>
            <button 
              onClick={signOut}
              title="Sair"
              className={cn("text-slate-500 hover:text-red-400 transition-colors", !isOpen && "mt-2")}
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>
    </aside>
  );
}
