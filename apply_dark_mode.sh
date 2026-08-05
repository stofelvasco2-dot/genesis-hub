#!/bin/bash
set -e
echo "Aplicando modo escuro no Genesis Hub..."

mkdir -p "app"
cat > "app/layout.tsx" << 'GENESIS_HUB_EOF_dark1'
import type {Metadata, Viewport} from 'next';
import './globals.css';
import { Geist } from "next/font/google";
import { cn } from "@/lib/utils";
import { StoreProvider } from '@/lib/store';
import { SidebarProvider } from '@/lib/sidebar-context';
import { ThemeProvider } from '@/components/theme-provider';
import { Toaster } from '@/components/ui/sonner';

const geist = Geist({subsets:['latin'],variable:'--font-sans'});

export const metadata: Metadata = {
  title: 'Genesis Hub',
  description: 'Sistema de Gestão de Demandas para o setor de Marketing',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({children}: {children: React.ReactNode}) {
  return (
    <html lang="en" className={cn("font-sans", geist.variable)} suppressHydrationWarning>
      <body suppressHydrationWarning>
        <ThemeProvider
          attribute="class"
          defaultTheme="light"
          enableSystem={false}
          storageKey="genesis-hub-theme"
        >
          <StoreProvider>
            <SidebarProvider>
              {children}
              <Toaster />
            </SidebarProvider>
          </StoreProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components"
cat > "components/theme-provider.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import * as React from "react";
import { ThemeProvider as NextThemesProvider } from "next-themes";

export function ThemeProvider({
  children,
  ...props
}: React.ComponentProps<typeof NextThemesProvider>) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>;
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/layout"
cat > "components/layout/theme-toggle.tsx" << 'GENESIS_HUB_EOF_dark1'
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
GENESIS_HUB_EOF_dark1

mkdir -p "components/layout"
cat > "components/layout/header.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { PlusCircle, Menu, PanelLeft } from "lucide-react";
import { TaskFormModal } from "@/components/tasks/task-form-modal";
import { NotificationBell } from "@/components/layout/notification-bell";
import { ThemeToggle } from "@/components/layout/theme-toggle";
import { useState } from "react";
import { Button } from "@/components/ui/button";

export function Header({ toggleSidebar, isSidebarOpen, isMobile }: { toggleSidebar?: () => void, isSidebarOpen?: boolean, isMobile?: boolean }) {
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <header className="h-16 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between px-4 sm:px-8 sticky top-0 z-10 shrink-0">
      <div className="flex items-center gap-4 flex-1 overflow-hidden">
        {toggleSidebar && (
          <Button variant="ghost" size="icon" onClick={toggleSidebar} className="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 shrink-0">
            <Menu className="w-5 h-5" />
          </Button>
        )}
        <h1 className="text-lg sm:text-xl font-bold text-slate-800 dark:text-slate-100 tracking-tight truncate">Gestão de Demandas</h1>
      </div>
      
      <div className="flex items-center gap-2 sm:gap-4 ml-4 shrink-0">
        <ThemeToggle />
        <NotificationBell />
        <Button 
          onClick={() => setIsModalOpen(true)} 
          className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-3 sm:px-4 py-2 rounded-md text-sm font-semibold transition-colors shadow-sm"
        >
          <PlusCircle className="w-4 h-4" />
          <span className="hidden sm:inline">Nova Demanda</span>
          <span className="sm:hidden">Nova</span>
        </Button>
      </div>
      
      <TaskFormModal open={isModalOpen} onOpenChange={setIsModalOpen} />
    </header>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/layout"
cat > "components/layout/notification-bell.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { Bell, UserPlus, ArrowRightCircle, Info, CheckCheck, MessageSquare, CalendarClock } from "lucide-react";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { useStore } from "@/lib/store";
import { formatDistanceToNow } from "date-fns";
import { ptBR } from "date-fns/locale";
import { useRouter } from "next/navigation";

const typeIcon: Record<string, React.ReactNode> = {
  assigned: <UserPlus className="w-4 h-4 text-blue-600" />,
  stage_owner: <ArrowRightCircle className="w-4 h-4 text-violet-600" />,
  commented: <MessageSquare className="w-4 h-4 text-emerald-600" />,
  due_date_changed: <CalendarClock className="w-4 h-4 text-amber-600" />,
  other: <Info className="w-4 h-4 text-slate-500" />,
};

export function NotificationBell() {
  const { notifications, unreadCount, markNotificationRead, markAllNotificationsRead } = useStore();
  const router = useRouter();

  const openNotification = (id: string, read: boolean, taskId?: string) => {
    if (!read) markNotificationRead(id);
    if (taskId) router.push(`/kanban?task=${taskId}`);
  };

  return (
    <Popover>
      <PopoverTrigger className="relative inline-flex items-center justify-center size-8 shrink-0 rounded-lg text-slate-500 hover:bg-muted hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors">
        <Bell className="w-5 h-5" />
        {unreadCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80 p-0 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100 dark:border-slate-800">
          <p className="text-sm font-bold text-slate-800 dark:text-slate-100">Notificações</p>
          {unreadCount > 0 && (
            <button
              onClick={() => markAllNotificationsRead()}
              className="text-xs text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 font-medium flex items-center gap-1"
            >
              <CheckCheck className="w-3.5 h-3.5" /> Marcar todas como lidas
            </button>
          )}
        </div>
        <div className="max-h-96 overflow-y-auto divide-y divide-slate-50 dark:divide-slate-800">
          {notifications.length === 0 && (
            <p className="text-sm text-slate-400 dark:text-slate-500 text-center py-10">Nenhuma notificação por aqui.</p>
          )}
          {notifications.map(n => (
            <button
              key={n.id}
              onClick={() => openNotification(n.id, n.read, n.taskId)}
              className={`w-full text-left px-4 py-3 flex gap-3 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors ${!n.read ? "bg-blue-50/50 dark:bg-blue-500/10" : ""}`}
            >
              <div className="mt-0.5 shrink-0">{typeIcon[n.type] || typeIcon.other}</div>
              <div className="flex-1 min-w-0">
                <p className={`text-sm ${!n.read ? "font-semibold text-slate-800 dark:text-slate-100" : "text-slate-600 dark:text-slate-400"}`}>{n.title}</p>
                {n.message && <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5 line-clamp-2">{n.message}</p>}
                <p className="text-[11px] text-slate-400 dark:text-slate-500 mt-1">
                  {formatDistanceToNow(new Date(n.createdAt), { addSuffix: true, locale: ptBR })}
                </p>
              </div>
              {!n.read && <span className="w-2 h-2 rounded-full bg-blue-500 shrink-0 mt-1.5" />}
            </button>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/layout"
cat > "components/layout/app-layout.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { Sidebar } from "./sidebar";
import { Header } from "./header";
import { cn } from "@/lib/utils";
import { useSidebar } from "@/lib/sidebar-context";

export function AppLayout({ children }: { children: React.ReactNode }) {
  const { isSidebarOpen, setIsSidebarOpen, isMobile } = useSidebar();

  return (
    <div className="flex h-screen w-full bg-slate-50 dark:bg-slate-950 font-sans text-slate-900 dark:text-slate-100 overflow-hidden">
      {/* Mobile Overlay */}
      {isMobile && isSidebarOpen && (
        <div 
          className="fixed inset-0 bg-slate-900/50 z-40 transition-opacity"
          onClick={() => setIsSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <div className={cn(
        "fixed lg:static inset-y-0 left-0 z-50 transition-all duration-300 ease-in-out shrink-0",
        isSidebarOpen ? "translate-x-0 w-64" : "-translate-x-full lg:translate-x-0 lg:w-16 w-64"
      )}>
        <Sidebar isOpen={isSidebarOpen} setIsOpen={setIsSidebarOpen} isMobile={isMobile} />
      </div>

      <div className="flex-1 flex flex-col h-full min-w-0 overflow-hidden">
        <Header 
          toggleSidebar={() => setIsSidebarOpen(!isSidebarOpen)} 
          isSidebarOpen={isSidebarOpen} 
          isMobile={isMobile}
        />
        <main className="flex-1 flex flex-col overflow-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/layout"
cat > "components/layout/sidebar.tsx" << 'GENESIS_HUB_EOF_dark1'
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
      "bg-slate-900 flex flex-col border-r border-slate-800 h-full overflow-hidden transition-all duration-300",
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
GENESIS_HUB_EOF_dark1

mkdir -p "components/dashboard"
cat > "components/dashboard/admin-dashboard.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { useMemo, useState, type ReactNode } from "react";
import { useStore } from "@/lib/store";
import { useRouter } from "next/navigation";
import { format, parseISO, differenceInCalendarDays } from "date-fns";
import { ptBR } from "date-fns/locale";
import {
  AlertCircle,
  ArrowRight,
  CheckCircle2,
  Clock,
  Flame,
  ListTodo,
  PauseCircle,
  Users,
} from "lucide-react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import {
  isTaskDelayed,
  isTaskDueToday,
  daysSinceUpdate,
  computeSla,
  buildWeeklyDeliveryTrend,
  priorityColor,
  priorityBadgeStyle,
  initialsFromName,
} from "@/lib/dashboard-utils";

const SLA_PERIODS = [
  { label: "7 dias", days: 7 },
  { label: "30 dias", days: 30 },
  { label: "90 dias", days: 90 },
];

const roleBadgeStyle: Record<string, string> = {
  Admin: "bg-violet-100 dark:bg-violet-500/15 text-violet-700",
  Gestor: "bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400",
  Colaborador: "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300",
};

export default function AdminDashboard() {
  const { tasks, users, statuses } = useStore();
  const router = useRouter();
  const [slaPeriod, setSlaPeriod] = useState(30);

  // Tudo aqui é derivado direto de `tasks`, que já chega em tempo real via
  // o canal do Supabase Realtime (lib/store.tsx) — então cada seção deste
  // dashboard se atualiza sozinha assim que qualquer card muda, sem F5.
  const activeTasks = useMemo(() => tasks.filter((t) => t.status !== "Aprovado"), [tasks]);
  const delayedTasks = useMemo(() => tasks.filter(isTaskDelayed), [tasks]);
  const dueTodayTasks = useMemo(() => tasks.filter(isTaskDueToday), [tasks]);
  const urgentActive = useMemo(
    () => activeTasks.filter((t) => t.priority === "Urgente"),
    [activeTasks]
  );
  const inTriagem = useMemo(() => tasks.filter((t) => t.status === "Triagem"), [tasks]);
  const awaitingApproval = useMemo(
    () => tasks.filter((t) => t.status === "Aguardando Aprovação"),
    [tasks]
  );

  // Funil do pipeline: quantas demandas estão paradas em cada etapa agora.
  const pipelineCounts = useMemo(() => {
    return statuses.map((status) => ({
      status,
      count: tasks.filter((t) => t.status === status).length,
    }));
  }, [tasks, statuses]);
  const maxPipeline = Math.max(1, ...pipelineCounts.map((p) => p.count));

  // Cards parados: sem nenhuma atualização há X dias, mesmo que o prazo
  // formal ainda não tenha vencido — sinal de que algo travou de verdade.
  const stuckTasks = useMemo(() => {
    return activeTasks
      .map((t) => ({ task: t, stuckDays: daysSinceUpdate(t) }))
      .filter((x) => x.stuckDays >= 3)
      .sort((a, b) => b.stuckDays - a.stuckDays)
      .slice(0, 8);
  }, [activeTasks]);

  // Carga de trabalho por pessoa (inclui Admin/Gestor, que também podem
  // ser responsáveis por demandas).
  const workload = useMemo(() => {
    return users
      .map((u) => {
        const assigned = activeTasks.filter((t) => t.assigneeId === u.id);
        const delayedCount = assigned.filter(isTaskDelayed).length;
        return { user: u, active: assigned.length, delayed: delayedCount };
      })
      .filter((w) => w.active > 0)
      .sort((a, b) => b.active - a.active);
  }, [users, activeTasks]);
  const maxActive = Math.max(1, ...workload.map((w) => w.active));
  const unassignedCount = activeTasks.filter((t) => !t.assigneeId).length;

  // SLA e tendência de entregas.
  const sla = useMemo(() => computeSla(tasks, slaPeriod), [tasks, slaPeriod]);
  const trend = useMemo(() => buildWeeklyDeliveryTrend(tasks, 8), [tasks]);

  // Distribuição por prioridade (só o que está ativo — prioridade de
  // tarefa já concluída não importa mais pra gestão do dia a dia).
  const priorityCounts = useMemo(() => {
    const order = ["Urgente", "Alta", "Normal", "Baixa"];
    const counts = activeTasks.reduce((acc, t) => {
      acc[t.priority] = (acc[t.priority] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    return order.filter((p) => counts[p]).map((p) => ({ name: p, total: counts[p] }));
  }, [activeTasks]);
  const maxPriority = Math.max(1, ...priorityCounts.map((p) => p.total));

  // Departamentos que mais geram demanda (volume de solicitação, não de
  // execução — mostra de onde vem a carga de trabalho da equipe).
  const departmentCounts = useMemo(() => {
    const counts = tasks.reduce((acc, t) => {
      acc[t.department] = (acc[t.department] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    return Object.entries(counts)
      .map(([name, total]) => ({ name, total }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 8);
  }, [tasks]);
  const maxDepartment = Math.max(1, ...departmentCounts.map((d) => d.total));

  return (
    <div className="p-6 space-y-6 flex-1 overflow-y-auto flex flex-col">
      {/* KPIs principais */}
      <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-4 shrink-0">
        <KpiCard label="Ativas no total" value={activeTasks.length} border="border-l-slate-400" icon={<ListTodo className="w-4 h-4 text-slate-400 dark:text-slate-500" />} />
        <KpiCard label="Na Triagem" value={inTriagem.length} border="border-l-slate-400" icon={<Clock className="w-4 h-4 text-slate-400 dark:text-slate-500" />} />
        <KpiCard label="Aguardando Aprovação" value={awaitingApproval.length} border="border-l-purple-500" valueClass="text-purple-600 dark:text-purple-400" icon={<PauseCircle className="w-4 h-4 text-purple-400" />} />
        <KpiCard label="Urgentes Ativas" value={urgentActive.length} border="border-l-red-600" valueClass="text-red-700 dark:text-red-400" icon={<Flame className="w-4 h-4 text-red-500 dark:text-red-400" />} />
        <KpiCard label="Atrasadas" value={delayedTasks.length} border="border-l-red-500" valueClass="text-red-600 dark:text-red-400" icon={<AlertCircle className="w-4 h-4 text-red-400" />} />
        <KpiCard label="Vencem Hoje" value={dueTodayTasks.length} border="border-l-amber-500" valueClass="text-amber-600 dark:text-amber-400" icon={<Clock className="w-4 h-4 text-amber-400" />} />
      </div>

      {/* Funil do Pipeline */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm shrink-0">
        <div className="px-5 pt-5 pb-1">
          <h4 className="text-sm font-bold text-slate-800 dark:text-slate-100">Funil do Pipeline</h4>
          <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">Quantas demandas estão em cada etapa agora, em tempo real.</p>
        </div>
        <div className="px-5 pb-5 pt-3 space-y-2.5">
          {pipelineCounts.map(({ status, count }) => (
            <button
              key={status}
              onClick={() => router.push(`/kanban?status=${encodeURIComponent(status)}`)}
              className="w-full flex items-center gap-3 text-left group"
            >
              <span className="text-xs text-slate-600 dark:text-slate-300 w-40 shrink-0 truncate group-hover:text-slate-900 dark:hover:text-white">{status}</span>
              <div className="flex-1 h-3 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
                <div
                  className={`h-full rounded-full ${status === "Aprovado" ? "bg-emerald-500" : "bg-blue-500"} transition-all`}
                  style={{ width: `${(count / maxPipeline) * 100}%` }}
                />
              </div>
              <span className="text-sm font-bold text-slate-800 dark:text-slate-100 w-6 text-right shrink-0">{count}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Carga de Trabalho + Cards Parados */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 shrink-0">
        <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <div className="flex items-center justify-between px-5 pt-5 pb-1">
            <div>
              <h4 className="text-sm font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
                <Users className="w-4 h-4 text-slate-400 dark:text-slate-500" /> Carga de Trabalho da Equipe
              </h4>
              <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">Demandas ativas por responsável</p>
            </div>
            {unassignedCount > 0 && (
              <span className="text-[11px] font-semibold px-2.5 py-1 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 shrink-0">
                {unassignedCount} sem responsável
              </span>
            )}
          </div>
          <div className="px-5 pb-5 pt-3 divide-y divide-slate-100 dark:divide-slate-800 max-h-80 overflow-y-auto">
            {workload.map(({ user, active, delayed }) => (
              <div key={user.id} className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 text-white text-[11px] font-bold flex items-center justify-center shrink-0">
                  {initialsFromName(user.name)}
                </div>
                <div className="w-32 shrink-0 min-w-0">
                  <p className="text-sm font-semibold text-slate-800 dark:text-slate-100 truncate">{user.name}</p>
                  <span className={`inline-block text-[10px] font-bold px-1.5 py-0.5 rounded uppercase mt-0.5 ${roleBadgeStyle[user.role] || "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300"}`}>
                    {user.role}
                  </span>
                </div>
                <div className="flex-1 flex items-center gap-2">
                  <div className="flex-1 h-2 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
                    <div
                      className={`h-full rounded-full ${active === 0 ? "bg-slate-200 dark:bg-slate-700" : delayed > 0 ? "bg-red-400" : "bg-blue-500"}`}
                      style={{ width: `${(active / maxActive) * 100}%` }}
                    />
                  </div>
                  <span className="text-sm font-bold text-slate-800 dark:text-slate-100 w-5 text-right shrink-0">{active}</span>
                </div>
                {delayed > 0 && (
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400 shrink-0">
                    {delayed}
                  </span>
                )}
              </div>
            ))}
            {workload.length === 0 && (
              <p className="text-sm text-slate-400 dark:text-slate-500 text-center py-4">Ninguém com demandas ativas no momento.</p>
            )}
          </div>
        </div>

        <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <div className="px-5 pt-5 pb-1">
            <h4 className="text-sm font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
              <PauseCircle className="w-4 h-4 text-orange-400" /> Cards Parados
            </h4>
            <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">Sem nenhuma atualização há 3+ dias — mesmo sem estar atrasada no prazo.</p>
          </div>
          <div className="px-5 pb-5 pt-3 divide-y divide-slate-100 dark:divide-slate-800 max-h-80 overflow-y-auto">
            {stuckTasks.map(({ task, stuckDays }) => (
              <button
                key={task.id}
                onClick={() => router.push(`/kanban?task=${task.id}`)}
                className="w-full flex items-center gap-3 py-3 first:pt-0 last:pb-0 text-left hover:bg-slate-50 dark:hover:bg-slate-800 -mx-2 px-2 rounded-lg transition-colors"
              >
                <span className="text-[10px] font-bold px-2 py-1 rounded-full bg-orange-100 dark:bg-orange-500/15 text-orange-600 shrink-0 whitespace-nowrap">
                  {stuckDays}d parada
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-slate-800 dark:text-slate-100 truncate">{task.title}</p>
                  <p className="text-xs text-slate-400 dark:text-slate-500">{task.status}</p>
                </div>
                <ArrowRight className="w-4 h-4 text-slate-300 dark:text-slate-600 shrink-0" />
              </button>
            ))}
            {stuckTasks.length === 0 && (
              <p className="text-sm text-slate-400 dark:text-slate-500 text-center py-6 flex flex-col items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                Nenhum card parado no momento.
              </p>
            )}
          </div>
        </div>
      </div>

      {/* Demandas Atrasadas */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm shrink-0">
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <div>
            <h4 className="text-sm font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-red-500 dark:text-red-400" /> Demandas Atrasadas
            </h4>
            <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">Prazo já vencido e ainda não aprovadas — ordenadas da mais urgente pra menos.</p>
          </div>
          {delayedTasks.length > 0 && (
            <span className="text-[11px] font-semibold px-2.5 py-1 rounded-full bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400 shrink-0">
              {delayedTasks.length}
            </span>
          )}
        </div>
        <div className="px-5 pb-5 divide-y divide-slate-100 dark:divide-slate-800">
          {[...delayedTasks]
            .sort((a, b) => parseISO(a.dueDate).getTime() - parseISO(b.dueDate).getTime())
            .slice(0, 8)
            .map((task) => {
              const assignee = users.find((u) => u.id === task.assigneeId);
              const daysLate = Math.abs(differenceInCalendarDays(parseISO(task.dueDate), new Date()));
              return (
                <button
                  key={task.id}
                  onClick={() => router.push(`/kanban?task=${task.id}`)}
                  className="w-full flex items-center gap-3 py-3 first:pt-0 last:pb-0 text-left hover:bg-slate-50 dark:hover:bg-slate-800 -mx-2 px-2 rounded-lg transition-colors"
                >
                  <span className="text-[10px] font-bold px-2 py-1 rounded-full bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400 shrink-0 whitespace-nowrap">
                    {daysLate} dia{daysLate !== 1 ? "s" : ""}
                  </span>
                  <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded shrink-0 ${priorityBadgeStyle[task.priority] || "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300"}`}>
                    {task.priority}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 dark:text-slate-100 truncate">{task.title}</p>
                    <p className="text-xs text-slate-400 dark:text-slate-500">
                      {task.category} · venceu em {format(parseISO(task.dueDate), "dd/MM", { locale: ptBR })}
                      {assignee ? ` · ${assignee.name}` : " · sem responsável"}
                    </p>
                  </div>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 uppercase shrink-0">{task.status}</span>
                  <ArrowRight className="w-4 h-4 text-slate-300 dark:text-slate-600 shrink-0" />
                </button>
              );
            })}
          {delayedTasks.length === 0 && (
            <p className="text-sm text-slate-400 dark:text-slate-500 text-center py-6 flex flex-col items-center gap-2">
              <CheckCircle2 className="w-5 h-5 text-emerald-400" />
              Nenhuma demanda atrasada no momento.
            </p>
          )}
        </div>
      </div>

      {/* Performance / SLA + Tendência de Entregas */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 shrink-0">
        <div className="bg-white dark:bg-slate-900 p-5 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col">
          <div className="flex items-center justify-between mb-4">
            <h4 className="text-xs font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Performance (SLA)</h4>
            <div className="flex items-center gap-1 bg-slate-100 dark:bg-slate-800 rounded-lg p-0.5">
              {SLA_PERIODS.map((p) => (
                <button
                  key={p.days}
                  onClick={() => setSlaPeriod(p.days)}
                  className={`text-[11px] font-semibold px-2 py-1 rounded-md transition-colors ${
                    slaPeriod === p.days ? "bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100 shadow-sm" : "text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200"
                  }`}
                >
                  {p.label}
                </button>
              ))}
            </div>
          </div>
          <div className="flex items-center justify-between flex-1">
            <div className="relative w-24 h-24 shrink-0">
              <svg viewBox="0 0 36 36" className="w-24 h-24">
                <path className="stroke-current text-slate-100 dark:text-slate-800" strokeWidth="4" fill="none" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                <path
                  className={`stroke-current ${sla.onTimePercentage >= 90 ? "text-green-500" : sla.onTimePercentage >= 70 ? "text-amber-500" : "text-red-500 dark:text-red-400"}`}
                  strokeWidth="4"
                  strokeDasharray={`${sla.onTimePercentage}, 100`}
                  strokeLinecap="round"
                  fill="none"
                  d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center font-bold text-xl text-slate-800 dark:text-slate-100">{sla.onTimePercentage}%</div>
            </div>
            <div className="flex-1 ml-6 space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-[11px] font-medium text-slate-500 dark:text-slate-400">Entregues no período</span>
                <span className="text-sm font-bold text-slate-800 dark:text-slate-100">{sla.completedCount}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-[11px] font-medium text-slate-500 dark:text-slate-400">Tempo Médio Entrega</span>
                <span className="text-sm font-bold text-slate-800 dark:text-slate-100">{sla.avgDeliveryDays > 0 ? `${sla.avgDeliveryDays.toFixed(1)} dias` : "-"}</span>
              </div>
              <div className="flex justify-between items-center border-t border-slate-100 dark:border-slate-800 pt-2">
                <span className="text-[11px] font-medium text-slate-500 dark:text-slate-400">No prazo</span>
                <span className={`text-sm font-bold ${sla.onTimePercentage >= 90 ? "text-green-600 dark:text-green-400" : sla.onTimePercentage >= 70 ? "text-amber-600 dark:text-amber-400" : "text-red-600 dark:text-red-400"}`}>
                  {sla.onTimePercentage}%
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-slate-900 p-5 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col">
          <h4 className="text-xs font-bold text-slate-400 dark:text-slate-500 uppercase mb-2 tracking-wider">Tendência de Entregas (8 semanas)</h4>
          <div className="flex-1 min-h-[160px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={trend} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="label" tick={{ fontSize: 11, fill: "#94a3b8" }} axisLine={false} tickLine={false} />
                <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: "#94a3b8" }} axisLine={false} tickLine={false} width={28} />
                <Tooltip
                  contentStyle={{
                    fontSize: 12,
                    borderRadius: 8,
                    border: "1px solid var(--border)",
                    backgroundColor: "var(--popover)",
                    color: "var(--popover-foreground)",
                  }}
                  labelFormatter={(label) => `Semana de ${label}`}
                  formatter={(value) => [`${value}`, "Entregues"]}
                />
                <Line type="monotone" dataKey="entregues" stroke="#3b82f6" strokeWidth={2} dot={{ r: 3 }} activeDot={{ r: 5 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Prioridade + Departamentos */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 shrink-0">
        <div className="bg-white dark:bg-slate-900 p-5 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col">
          <h4 className="text-xs font-bold text-slate-400 dark:text-slate-500 uppercase mb-4 tracking-wider">Prioridade das Demandas Ativas</h4>
          <div className="space-y-3">
            {priorityCounts.length === 0 && <p className="text-sm text-slate-400 dark:text-slate-500">Nenhuma demanda ativa.</p>}
            {priorityCounts.map((p) => (
              <div key={p.name} className="flex items-center gap-3">
                <span className="text-xs text-slate-600 dark:text-slate-300 w-16 shrink-0">{p.name}</span>
                <div className="flex-1 h-2 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
                  <div className={`h-full rounded-full ${priorityColor[p.name] || "bg-blue-500"}`} style={{ width: `${(p.total / maxPriority) * 100}%` }} />
                </div>
                <span className="text-xs font-bold text-slate-700 dark:text-slate-200 w-5 text-right shrink-0">{p.total}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white dark:bg-slate-900 p-5 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col">
          <h4 className="text-xs font-bold text-slate-400 dark:text-slate-500 uppercase mb-4 tracking-wider">Departamentos que Mais Solicitam</h4>
          <div className="space-y-3 max-h-56 overflow-y-auto pr-1">
            {departmentCounts.length === 0 && <p className="text-sm text-slate-400 dark:text-slate-500">Nenhuma demanda ainda.</p>}
            {departmentCounts.map((d) => (
              <div key={d.name} className="flex items-center gap-3">
                <span className="text-xs text-slate-600 dark:text-slate-300 w-32 shrink-0 truncate" title={d.name}>{d.name}</span>
                <div className="flex-1 h-2 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden">
                  <div className="h-full rounded-full bg-indigo-500" style={{ width: `${(d.total / maxDepartment) * 100}%` }} />
                </div>
                <span className="text-xs font-bold text-slate-700 dark:text-slate-200 w-5 text-right shrink-0">{d.total}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function KpiCard({
  label,
  value,
  border,
  valueClass = "text-slate-900 dark:text-white",
  icon,
}: {
  label: string;
  value: number;
  border: string;
  valueClass?: string;
  icon?: ReactNode;
}) {
  return (
    <div className={`bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 ${border}`}>
      <div className="flex items-center justify-between mb-1">
        <p className="text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase">{label}</p>
        {icon}
      </div>
      <p className={`text-2xl font-bold ${valueClass}`}>{value}</p>
    </div>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/dashboard"
cat > "components/dashboard/collaborator-dashboard.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { useMemo } from "react";
import { useStore } from "@/lib/store";
import { useRouter } from "next/navigation";
import { format, parseISO, differenceInCalendarDays } from "date-fns";
import { ptBR } from "date-fns/locale";
import { AlertCircle, ArrowRight, CalendarClock, CheckCircle2, Clock, ListTodo } from "lucide-react";
import {
  isTaskDelayed,
  isTaskDueToday,
  isTaskDueThisWeek,
  priorityBadgeStyle,
} from "@/lib/dashboard-utils";

const statusBadgeStyle: Record<string, string> = {
  Triagem: "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300",
  "Em Produção": "bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400",
  "Revisão Interna": "bg-indigo-100 dark:bg-indigo-500/15 text-indigo-700 dark:text-indigo-400",
  "Ajustes Solicitados": "bg-amber-100 dark:bg-amber-500/15 text-amber-700 dark:text-amber-400",
  "Aguardando Aprovação": "bg-purple-100 dark:bg-purple-500/15 text-purple-700 dark:text-purple-400",
  Aprovado: "bg-emerald-100 dark:bg-emerald-500/15 text-emerald-700 dark:text-emerald-400",
};

export default function CollaboratorDashboard() {
  const { tasks, currentUser } = useStore();
  const router = useRouter();

  // Só as tarefas onde a pessoa é responsável (a fila de trabalho dela) —
  // atualiza sozinho em tempo real, sem precisar de F5.
  const myTasks = useMemo(
    () => tasks.filter((t) => t.assigneeId === currentUser?.id),
    [tasks, currentUser?.id]
  );
  const myActiveTasks = useMemo(() => myTasks.filter((t) => t.status !== "Aprovado"), [myTasks]);
  const myDelayed = useMemo(() => myActiveTasks.filter(isTaskDelayed), [myActiveTasks]);
  const myDueToday = useMemo(() => myActiveTasks.filter(isTaskDueToday), [myActiveTasks]);
  const myDueThisWeek = useMemo(() => myActiveTasks.filter(isTaskDueThisWeek), [myActiveTasks]);

  // Fila de trabalho ordenada: atrasadas primeiro, depois por prazo mais
  // próximo, sem prazo por último.
  const workQueue = useMemo(() => {
    return [...myActiveTasks].sort((a, b) => {
      const aLate = isTaskDelayed(a) ? 0 : 1;
      const bLate = isTaskDelayed(b) ? 0 : 1;
      if (aLate !== bLate) return aLate - bLate;
      if (!a.dueDate && !b.dueDate) return 0;
      if (!a.dueDate) return 1;
      if (!b.dueDate) return -1;
      return parseISO(a.dueDate).getTime() - parseISO(b.dueDate).getTime();
    });
  }, [myActiveTasks]);

  return (
    <div className="p-6 space-y-6 flex-1 overflow-y-auto flex flex-col">
      <div>
        <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100">Olá, {currentUser?.name?.split(" ")[0] || "por aqui"} 👋</h2>
        <p className="text-sm text-slate-400 dark:text-slate-500">Aqui está o que precisa da sua atenção agora.</p>
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 shrink-0">
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-slate-400">
          <div className="flex items-center justify-between mb-1">
            <p className="text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase">Pendentes</p>
            <ListTodo className="w-4 h-4 text-slate-400 dark:text-slate-500" />
          </div>
          <p className="text-2xl font-bold text-slate-900 dark:text-white">{myActiveTasks.length}</p>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-red-500">
          <div className="flex items-center justify-between mb-1">
            <p className="text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase">Atrasadas</p>
            <AlertCircle className="w-4 h-4 text-red-400" />
          </div>
          <p className="text-2xl font-bold text-red-600 dark:text-red-400">{myDelayed.length}</p>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-amber-500">
          <div className="flex items-center justify-between mb-1">
            <p className="text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase">Vencem Hoje</p>
            <Clock className="w-4 h-4 text-amber-400" />
          </div>
          <p className="text-2xl font-bold text-amber-600 dark:text-amber-400">{myDueToday.length}</p>
        </div>
        <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm border-l-4 border-l-blue-500">
          <div className="flex items-center justify-between mb-1">
            <p className="text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase">Essa Semana</p>
            <CalendarClock className="w-4 h-4 text-blue-400" />
          </div>
          <p className="text-2xl font-bold text-blue-600 dark:text-blue-400">{myDueThisWeek.length}</p>
        </div>
      </div>

      {/* Fila de trabalho */}
      <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm shrink-0">
        <div className="px-5 pt-5 pb-3">
          <h4 className="text-sm font-bold text-slate-800 dark:text-slate-100">Sua Fila de Trabalho</h4>
          <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">Atrasadas primeiro, depois por prazo mais próximo.</p>
        </div>
        <div className="px-5 pb-5 divide-y divide-slate-100 dark:divide-slate-800">
          {workQueue.slice(0, 12).map((task) => {
            const delayed = isTaskDelayed(task);
            const dueToday = isTaskDueToday(task);
            return (
              <button
                key={task.id}
                onClick={() => router.push(`/kanban?task=${task.id}`)}
                className="w-full flex items-center gap-3 py-3 first:pt-0 last:pb-0 text-left hover:bg-slate-50 dark:hover:bg-slate-800 -mx-2 px-2 rounded-lg transition-colors"
              >
                <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded shrink-0 ${priorityBadgeStyle[task.priority] || "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300"}`}>
                  {task.priority}
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-slate-800 dark:text-slate-100 truncate">{task.title}</p>
                  <p className="text-xs text-slate-400 dark:text-slate-500">
                    {task.category}
                    {task.dueDate ? ` · prazo ${format(parseISO(task.dueDate), "dd/MM", { locale: ptBR })}` : " · sem prazo"}
                  </p>
                </div>
                {delayed && (
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-100 dark:bg-red-500/15 text-red-600 dark:text-red-400 shrink-0 whitespace-nowrap">
                    {Math.abs(differenceInCalendarDays(parseISO(task.dueDate), new Date()))}d atraso
                  </span>
                )}
                {!delayed && dueToday && (
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-100 dark:bg-amber-500/15 text-amber-700 dark:text-amber-400 shrink-0 whitespace-nowrap">
                    Hoje
                  </span>
                )}
                <span className={`text-[10px] font-bold px-2 py-0.5 rounded uppercase shrink-0 ${statusBadgeStyle[task.status] || "bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400"}`}>
                  {task.status}
                </span>
                <ArrowRight className="w-4 h-4 text-slate-300 dark:text-slate-600 shrink-0" />
              </button>
            );
          })}
          {workQueue.length === 0 && (
            <p className="text-sm text-slate-400 dark:text-slate-500 text-center py-8 flex flex-col items-center gap-2">
              <CheckCircle2 className="w-6 h-6 text-emerald-400" />
              Nenhuma demanda pendente com você. 🎉
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/kanban"
cat > "components/kanban/board.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { useStore } from "@/lib/store";
import { DragDropContext, DropResult } from "@hello-pangea/dnd";
import { KanbanColumn } from "./column";
import { Status, Task } from "@/lib/types";
import { useState, useEffect } from "react";
import { LayoutGrid, List, Trello } from "lucide-react";
import { Button } from "@/components/ui/button";
import { format, parseISO, isPast, isToday } from "date-fns";
import { ptBR } from "date-fns/locale";
import { TaskDetailModal } from "@/components/tasks/task-detail-modal";
import { useSearchParams, useRouter } from "next/navigation";

export function KanbanBoard() {
  const { tasks, currentUser, moveTaskStatus, users, statuses } = useStore();
  const [view, setView] = useState<"kanban" | "list" | "cards">("kanban");

  // Deep-link: clicar numa notificação leva pra /kanban?task=<id> e abre o
  // modal dessa tarefa direto, sem precisar caçar o card na tela.
  const searchParams = useSearchParams();
  const router = useRouter();
  const deepLinkTaskId = searchParams.get("task");
  const deepLinkTask = deepLinkTaskId ? tasks.find(t => t.id === deepLinkTaskId) : undefined;
  const closeDeepLink = () => router.replace("/kanban");

  const onDragEnd = (result: DropResult) => {
    const { destination, source, draggableId } = result;
    if (!destination) return;
    if (destination.droppableId === source.droppableId && destination.index === source.index) return;
    if (currentUser) {
      moveTaskStatus(draggableId, destination.droppableId as Status, currentUser.id);
    }
  };

  // Admin e Gestor enxergam todas as demandas, independente de quem criou ou
  // é o responsável — igual à mesma regra já usada no Dashboard e em Tarefas.
  // Colaborador só vê o que ele criou ou o que foi atribuído a ele.
  const isGestorOrAdmin = currentUser?.role === "Admin" || currentUser?.role === "Gestor";
  const displayTasks = isGestorOrAdmin
    ? tasks
    : tasks.filter(t => t.assigneeId === currentUser?.id || t.requesterId === currentUser?.id);

  return (
    <>
      <div className="flex flex-col h-full min-h-0 overflow-hidden space-y-6 p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 shrink-0">
          <div>
            <h2 className="text-3xl font-bold tracking-tight">Demandas</h2>
            <p className="text-muted-foreground mt-2">Acompanhamento e execução das demandas.</p>
          </div>
          
          <div className="flex items-center gap-2 bg-slate-100 dark:bg-slate-800 p-1 rounded-lg self-start">
            <Button
              variant={view === "kanban" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setView("kanban")}
              className="h-8 gap-2"
            >
              <Trello className="w-4 h-4" />
              <span className="hidden sm:inline">Kanban</span>
            </Button>
            <Button
              variant={view === "list" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setView("list")}
              className="h-8 gap-2"
            >
              <List className="w-4 h-4" />
              <span className="hidden sm:inline">Lista</span>
            </Button>
            <Button
              variant={view === "cards" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setView("cards")}
              className="h-8 gap-2"
            >
              <LayoutGrid className="w-4 h-4" />
              <span className="hidden sm:inline">Cards</span>
            </Button>
          </div>
        </div>

        {view === "kanban" && (
          <DragDropContext onDragEnd={onDragEnd}>
            <div className="flex flex-1 min-h-0 gap-6 overflow-x-auto overflow-y-hidden pb-4">
              {statuses.map(status => {
                const colTasks = displayTasks.filter(t => t.status === status);
                return <KanbanColumn key={status} column={{ id: status, title: status }} tasks={colTasks} />;
              })}
            </div>
          </DragDropContext>
        )}

        {view === "list" && (
          <div className="flex-1 min-h-0 overflow-y-auto bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800">
            <table className="w-full text-sm text-left">
              <thead className="bg-slate-50 dark:bg-slate-950 text-slate-500 dark:text-slate-400 text-xs uppercase font-bold border-b border-slate-200 dark:border-slate-800 sticky top-0">
                <tr>
                  <th className="px-6 py-4">ID</th>
                  <th className="px-6 py-4">Título</th>
                  <th className="px-6 py-4">Status</th>
                  <th className="px-6 py-4">Prioridade</th>
                  <th className="px-6 py-4">Responsável</th>
                  <th className="px-6 py-4">Prazo</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 dark:divide-slate-800">
                {displayTasks.map(task => {
                  const assignee = users.find(u => u.id === task.assigneeId);
                  return (
                    <TaskRow key={task.id} task={task} assignee={assignee} />
                  );
                })}
                {displayTasks.length === 0 && (
                  <tr>
                    <td colSpan={6} className="px-6 py-8 text-center text-slate-500 dark:text-slate-400">
                      Nenhuma demanda encontrada.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}

        {view === "cards" && (
          <div className="flex-1 min-h-0 overflow-y-auto grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 pb-4">
            {displayTasks.map(task => {
              const assignee = users.find(u => u.id === task.assigneeId);
              return (
                <TaskGridCard key={task.id} task={task} assignee={assignee} />
              );
            })}
          </div>
        )}
      </div>

      {deepLinkTask && (
        <TaskDetailModal
          task={deepLinkTask}
          open={true}
          onOpenChange={(open) => { if (!open) closeDeepLink(); }}
        />
      )}
    </>
  );
}

function TaskRow({ task, assignee }: { task: Task; assignee?: { name: string } }) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  return (
    <>
      <tr onClick={() => setIsModalOpen(true)} className="hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer transition-colors group">
        <td className="px-6 py-4 font-mono text-slate-400 dark:text-slate-500 group-hover:text-slate-600">#{task.id.slice(0, 4)}</td>
        <td className="px-6 py-4 font-medium text-slate-900 dark:text-white">{task.title}</td>
        <td className="px-6 py-4">
          <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 uppercase tracking-wider">
            {task.status}
          </span>
        </td>
        <td className="px-6 py-4">
          <span className={`px-2.5 py-1 rounded text-[11px] font-bold uppercase tracking-wider ${task.priority === 'Alta' ? 'bg-orange-100 dark:bg-orange-500/15 text-orange-700 dark:text-orange-400' : task.priority === 'Urgente' ? 'bg-red-100 dark:bg-red-500/15 text-red-700 dark:text-red-400' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'}`}>
            {task.priority}
          </span>
        </td>
        <td className="px-6 py-4">
          {assignee ? (
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-full bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400 font-bold text-[10px] flex items-center justify-center">
                {assignee.name.split(' ').map((n: string) => n[0]).join('').substring(0, 2).toUpperCase()}
              </div>
              <span className="text-slate-600 dark:text-slate-300">{assignee.name}</span>
            </div>
          ) : (
            <span className="text-slate-400 dark:text-slate-500 text-xs italic">Não atribuído</span>
          )}
        </td>
        <td className={`px-6 py-4 ${getDateColor(task.dueDate, task.status)}`}>
          {task.dueDate ? format(parseISO(task.dueDate), "dd/MM/yyyy", { locale: ptBR }) : '-'}
        </td>
      </tr>
      <TaskDetailModal task={task} open={isModalOpen} onOpenChange={setIsModalOpen} />
    </>
  );
}

function TaskGridCard({ task, assignee }: { task: Task; assignee?: { name: string } }) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  return (
    <>
      <div onClick={() => setIsModalOpen(true)} className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm hover:shadow-md transition-shadow cursor-pointer flex flex-col h-full">
        <div className="flex justify-between items-start mb-3">
          <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${task.priority === 'Alta' ? 'bg-orange-100 dark:bg-orange-500/15 text-orange-700 dark:text-orange-400' : task.priority === 'Urgente' ? 'bg-red-100 dark:bg-red-500/15 text-red-700 dark:text-red-400' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'}`}>
            {task.priority}
          </span>
          <span className="px-2 py-0.5 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
            {task.status}
          </span>
        </div>
        <h3 className="font-bold text-slate-900 dark:text-white mb-2 leading-tight">{task.title}</h3>
        <p className="text-xs text-slate-500 dark:text-slate-400 line-clamp-2 mb-4 flex-1">{task.description}</p>
        
        <div className="flex items-center justify-between pt-4 border-t border-slate-100 dark:border-slate-800 mt-auto">
          {assignee ? (
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-full bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400 font-bold text-[10px] flex items-center justify-center">
                {assignee.name.split(' ').map((n: string) => n[0]).join('').substring(0, 2).toUpperCase()}
              </div>
              <span className="text-xs font-medium text-slate-600 dark:text-slate-300 truncate max-w-[100px]">{assignee.name}</span>
            </div>
          ) : (
            <span className="text-slate-400 dark:text-slate-500 text-xs italic">Não atribuído</span>
          )}
          <span className={`text-xs font-semibold ${getDateColor(task.dueDate, task.status)}`}>
            {task.dueDate ? format(parseISO(task.dueDate), "dd/MM", { locale: ptBR }) : '-'}
          </span>
        </div>
      </div>
      <TaskDetailModal task={task} open={isModalOpen} onOpenChange={setIsModalOpen} />
    </>
  );
}

function getDateColor(dueDateStr: string | undefined, status: string) {
  if (!dueDateStr || status === 'Aprovado') return 'text-slate-500 dark:text-slate-400';
  const date = parseISO(dueDateStr);
  
  if (isToday(date)) return 'text-amber-600 dark:text-amber-400 font-bold';
  if (isPast(date)) return 'text-red-600 dark:text-red-400 font-bold';
  return 'text-emerald-600 dark:text-emerald-400 font-bold';
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/kanban"
cat > "components/kanban/column.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { Droppable } from "@hello-pangea/dnd";
import { KanbanCard } from "./card";
import { Task, Status } from "@/lib/types";

interface KanbanColumnProps {
  column: { id: Status; title: string };
  tasks: Task[];
}

export function KanbanColumn({ column, tasks }: KanbanColumnProps) {
  let dotColor = "bg-slate-400";
  if (column.id === "Atribuído, A Fazer") dotColor = "bg-cyan-500";
  if (column.id === "Em Produção") dotColor = "bg-blue-500";
  if (column.id === "Aprovado") dotColor = "bg-green-500";
  if (column.id === "Revisão Interna") dotColor = "bg-purple-500";
  if (column.id === "Ajustes Solicitados") dotColor = "bg-orange-500";
  if (column.id === "Aguardando Aprovação") dotColor = "bg-yellow-500";

  return (
    <div className="flex flex-col w-80 shrink-0 h-full min-h-0">
      <div className="flex items-center justify-between mb-4 px-1 shrink-0">
        <h3 className="text-sm font-bold text-slate-700 dark:text-slate-200 uppercase flex items-center gap-2 tracking-wider">
          <span className={`w-2 h-2 rounded-full ${dotColor}`}></span> 
          {column.title}
        </h3>
        <span className="text-xs font-bold text-slate-400 dark:text-slate-500 bg-slate-200 dark:bg-slate-700/50 px-2 py-0.5 rounded-full">
          {tasks.length}
        </span>
      </div>

      <Droppable droppableId={column.id}>
        {(provided, snapshot) => (
          <div
            {...provided.droppableProps}
            ref={provided.innerRef}
            className={`flex-1 min-h-0 overflow-y-auto bg-slate-200 dark:bg-slate-700/30 rounded-xl p-3 flex flex-col gap-3 transition-colors ${
              snapshot.isDraggingOver ? "bg-slate-200 dark:bg-slate-700/50" : ""
            }`}
          >
            {tasks.map((task, index) => (
              <KanbanCard key={task.id} task={task} index={index} />
            ))}
            {provided.placeholder}
          </div>
        )}
      </Droppable>
    </div>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/kanban"
cat > "components/kanban/card.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { Draggable } from "@hello-pangea/dnd";
import { Task } from "@/lib/types";
import { format, parseISO, isPast, isToday } from "date-fns";
import { ptBR } from "date-fns/locale";
import { CalendarIcon } from "lucide-react";
import { useStore } from "@/lib/store";
import { useState } from "react";
import { TaskDetailModal } from "@/components/tasks/task-detail-modal";

interface KanbanCardProps {
  task: Task;
  index: number;
}

export function KanbanCard({ task, index }: KanbanCardProps) {
  const { users } = useStore();
  const assignee = users.find((u) => u.id === task.assigneeId);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const dueDate = parseISO(task.dueDate);
  const isOverdue = isPast(dueDate) && !isToday(dueDate);

  return (
    <>
      <Draggable draggableId={task.id} index={index}>
        {(provided, snapshot) => (
          <div
            ref={provided.innerRef}
            {...provided.draggableProps}
            {...provided.dragHandleProps}
            style={provided.draggableProps.style}
            onClick={() => setIsModalOpen(true)}
            className={`group select-none relative ${snapshot.isDragging ? 'z-50' : ''}`}
          >
            <div className={`bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm cursor-grab active:cursor-grabbing hover:shadow-md transition-all duration-200 ${task.status === "Em Produção" ? "ring-2 ring-blue-500/10" : ""} ${task.status === "Aprovado" ? "opacity-75" : ""}`}>
              
              <div className="flex justify-between items-start mb-3 gap-2">
                <div className="flex flex-wrap gap-1.5">
                  <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-800 truncate max-w-[100px]">
                    {task.category}
                  </span>
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${task.priority === 'Alta' ? 'bg-orange-100 dark:bg-orange-500/15 text-orange-700 dark:text-orange-400' : task.priority === 'Urgente' ? 'bg-red-100 dark:bg-red-500/15 text-red-700 dark:text-red-400' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'}`}>
                    {task.priority}
                  </span>
                </div>
                <span className="text-[10px] font-mono text-slate-400 dark:text-slate-500 font-semibold">#{task.id.slice(0,4)}</span>
              </div>
              
              <h4 className="text-sm font-bold text-slate-900 dark:text-white leading-tight mb-2 group-hover:text-blue-600 transition-colors line-clamp-2">{task.title}</h4>
              
              <p className="text-xs text-slate-500 dark:text-slate-400 line-clamp-2 mb-4 leading-relaxed">{task.description}</p>
              
              <div className="flex items-center justify-between mt-auto pt-3 border-t border-slate-100 dark:border-slate-800">
                
                <div className="flex items-center gap-2">
                  {assignee ? (
                    <div className="flex items-center gap-1.5" title={assignee.name}>
                      <div className="w-5 h-5 rounded-full bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400 font-bold text-[9px] flex items-center justify-center">
                        {assignee.name.split(' ').map(n=>n[0]).join('').substring(0,2).toUpperCase()}
                      </div>
                    </div>
                  ) : (
                    <div className="w-5 h-5 rounded-full bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-800 border-dashed flex items-center justify-center" title="Sem responsável">
                      <span className="text-[10px] text-slate-400 dark:text-slate-500">?</span>
                    </div>
                  )}
                  
                  <div className="flex items-center gap-2 text-slate-400 dark:text-slate-500 ml-1">
                  </div>
                </div>

                <div className={`flex items-center gap-1 text-[10px] font-bold px-1.5 py-0.5 rounded ${isOverdue ? 'bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-400' : isToday(dueDate) ? 'bg-amber-50 dark:bg-amber-500/10 text-amber-600 dark:text-amber-400' : 'text-slate-500 dark:text-slate-400'}`}>
                  <CalendarIcon className="w-3 h-3" />
                  {format(dueDate, "dd/MM")}
                </div>
              </div>

            </div>
          </div>
        )}
      </Draggable>
      <TaskDetailModal task={task} open={isModalOpen} onOpenChange={setIsModalOpen} />
    </>
  );
}

function getDateColor(dueDateStr: string | undefined, status: string) {
  if (!dueDateStr || status === 'Aprovado') return 'text-slate-500 dark:text-slate-400';
  const date = parseISO(dueDateStr);
  
  if (isToday(date)) return 'text-amber-600 dark:text-amber-400 font-bold';
  if (isPast(date)) return 'text-red-600 dark:text-red-400 font-bold';
  return 'text-emerald-600 dark:text-emerald-400 font-bold';
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/tasks"
cat > "components/tasks/task-detail-modal.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Task, Category, Priority, Department, Status } from "@/lib/types";
import { X, CalendarIcon, Save, Edit2, ExternalLink, MessageSquare, Activity } from "lucide-react";
import { useState, useEffect } from "react";
import { useStore } from "@/lib/store";
import { format, parseISO, differenceInDays } from "date-fns";
import { ptBR } from "date-fns/locale";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

interface TaskDetailModalProps {
  task: Task;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}









export function TaskDetailModal({ task, open, onOpenChange }: TaskDetailModalProps) {
  const { updateTask, currentUser, users, addComment, statuses, categories, priorities, departments } = useStore();
  
  const [isEditing, setIsEditing] = useState(false);
  const [editedTask, setEditedTask] = useState<Partial<Task>>({});
  const [commentText, setCommentText] = useState("");

  useEffect(() => {
    if (open) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setIsEditing(false);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setEditedTask({
        title: task.title,
        description: task.description,
        category: task.category,
        priority: task.priority,
        dueDate: task.dueDate,
        referenceLinks: task.referenceLinks,
        notes: task.notes,
        requesterName: task.requesterName,
        department: task.department,
        externalConsultant: task.externalConsultant,
        internalConsultant: task.internalConsultant,
        status: task.status,
        assigneeId: task.assigneeId
      });
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setCommentText("");
    }
  }, [open, task]);

  const handleSave = () => {
    if (!currentUser) return;
    updateTask(task.id, editedTask, currentUser.id);
    toast.success("Solicitação atualizada com sucesso!");
    setIsEditing(false);
  };

  const handleAddComment = () => {
    if (!commentText.trim() || !currentUser) return;
    addComment(task.id, currentUser.id, commentText.trim());
    setCommentText("");
    toast.success("Comentário adicionado!");
  };

  const currentTask = isEditing ? { ...task, ...editedTask } : task;
  const dueDate = currentTask.dueDate ? parseISO(currentTask.dueDate) : undefined;
  
  const linksString = (currentTask.referenceLinks || []).join('\n');

  const handleLinksChange = (val: string) => {
    const arr = val.split(/[\n, ]+/).map(l => l.trim()).filter(l => l.length > 0);
    setEditedTask({...editedTask, referenceLinks: arr});
  };

  const createdDate = parseISO(task.createdAt);
  const totalDays = dueDate ? (differenceInDays(dueDate, createdDate) || 1) : 1;
  const daysPassed = differenceInDays(new Date(), createdDate);
  const progressPercent = Math.min(Math.max((daysPassed / totalDays) * 100, 0), 100);
  const daysLeft = dueDate ? differenceInDays(dueDate, new Date()) : 0;
  
  const currentAssignee = users.find(u => u.id === currentTask.assigneeId);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-[1200px] w-[95vw] max-h-[95vh] sm:h-[90vh] flex flex-col p-0 overflow-y-auto sm:overflow-hidden bg-slate-50 dark:bg-slate-950 border-none shadow-2xl font-sans sm:rounded-2xl [&>button]:hidden">
        
        {/* Header - Glassmorphism (Azul translúcido, desfocado) */}
        <div className="flex-none px-5 py-4 sm:px-8 sm:py-5 bg-blue-600/10 backdrop-blur-xl border-b border-blue-600/10 flex flex-col sm:flex-row sm:items-center justify-between gap-4 z-50">
          <div className="flex flex-col gap-2 flex-1 min-w-0">
            <div className="flex items-center gap-3">
              <span className="text-xs font-mono font-bold bg-blue-500/20 text-blue-700 dark:text-blue-400 px-2 py-1 rounded shadow-sm border border-blue-500/10">#{task.id.slice(0,6).toUpperCase()}</span>
              {isEditing ? (
                <Select value={currentTask.status} onValueChange={(val) => setEditedTask({...editedTask, status: val as Status})}>
                  <SelectTrigger className="h-7 text-xs font-bold bg-white dark:bg-slate-900/50 backdrop-blur-sm border-blue-500/20 text-blue-800 w-auto">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {statuses.map(s => <SelectItem key={s} value={s} className="text-xs">{s}</SelectItem>)}
                  </SelectContent>
                </Select>
              ) : (
                <span className="px-2.5 py-1 rounded text-[10px] font-bold uppercase tracking-wider bg-blue-500/20 text-blue-700 dark:text-blue-400 shadow-sm border border-blue-500/10">{currentTask.status}</span>
              )}
            </div>
            
            {isEditing ? (
              <Input 
                value={currentTask.title} 
                onChange={e => setEditedTask({...editedTask, title: e.target.value})}
                className="h-10 text-xl font-bold w-full max-w-2xl bg-white dark:bg-slate-900/60 backdrop-blur-md border-blue-500/20 focus-visible:ring-blue-500"
              />
            ) : (
              <DialogTitle className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white truncate pr-4 drop-shadow-sm">{currentTask.title}</DialogTitle>
            )}

            <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-slate-700 dark:text-slate-200 font-medium mt-1">
              <span className="flex items-center gap-1.5 bg-white dark:bg-slate-900/40 px-2 py-1 rounded-md border border-white/20 shadow-sm">
                <span className="text-slate-500 dark:text-slate-400">Solicitante:</span> 
                <span className="font-bold text-slate-900 dark:text-white">{currentTask.requesterName}</span>
              </span>
              <span className="flex items-center gap-1.5 bg-white dark:bg-slate-900/40 px-2 py-1 rounded-md border border-white/20 shadow-sm">
                <span className="text-slate-500 dark:text-slate-400">Última atualização:</span> 
                <span className="font-bold text-slate-900 dark:text-white">{format(parseISO(task.updatedAt || task.createdAt), "dd/MM/yyyy HH:mm", { locale: ptBR })}</span>
              </span>
            </div>
          </div>
          
          <div className="flex items-center gap-3 shrink-0 self-start sm:self-center">
            {!isEditing ? (
              <Button onClick={() => setIsEditing(true)} className="bg-white dark:bg-slate-900/60 hover:bg-white/90 text-blue-800 border border-blue-500/20 backdrop-blur-md shadow-sm h-10 gap-2 font-bold px-5 transition-all">
                <Edit2 className="w-4 h-4" /> Editar
              </Button>
            ) : (
              <Button onClick={handleSave} className="bg-blue-600 hover:bg-blue-700 text-white shadow-md h-10 gap-2 font-bold px-5 transition-all">
                <Save className="w-4 h-4" /> Salvar
              </Button>
            )}
            <Button type="button" variant="ghost" size="icon" onClick={() => onOpenChange(false)} className="h-10 w-10 rounded-full bg-white dark:bg-slate-900/40 hover:bg-white/80 text-slate-700 dark:text-slate-200 backdrop-blur-md border border-white/40 shadow-sm transition-all">
              <X className="w-4 h-4" />
            </Button>
          </div>
        </div>
        
        {/* Main Content Area - Fixing scroll by using flex-1 properly */}
        <div className="flex-1 w-full bg-slate-50 dark:bg-slate-950/50 sm:overflow-y-auto">
          
          {/* Executive Header - Underneath main title */}
          <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800/60 shadow-sm sticky top-0 z-40">
            <div className="flex overflow-x-auto p-4 sm:px-8">
              <div className="flex flex-nowrap items-center gap-6 w-full text-sm min-w-max">
                
                {/* Responsável */}
                <div className="flex flex-col gap-1.5 min-w-[150px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Responsável</span>
                  {isEditing ? (
                    <Select value={currentTask.assigneeId || "unassigned"} onValueChange={(val) => setEditedTask({...editedTask, assigneeId: (val === "unassigned" ? undefined : val) as string | undefined})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50 dark:bg-slate-950"><SelectValue>{currentTask.assigneeId ? users.find(u => u.id === currentTask.assigneeId)?.name : "Sem responsável"}</SelectValue></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="unassigned" className="text-xs">Sem responsável</SelectItem>
                        {users.map(u => (
                          <SelectItem key={u.id} value={u.id} className="text-xs">{u.name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="font-bold text-slate-800 dark:text-slate-100 h-8 flex items-center gap-2">
                      {currentAssignee ? (
                        <>
                          <div className="w-6 h-6 rounded-full bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400 flex items-center justify-center text-[10px] uppercase border border-blue-200">
                            {currentAssignee.name.split(' ').map(n=>n[0]).join('').substring(0,2)}
                          </div>
                          <span className="truncate text-sm">{currentAssignee.name}</span>
                        </>
                      ) : (
                        <span className="text-slate-400 dark:text-slate-500 italic text-sm">Nenhum</span>
                      )}
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* Categoria */}
                <div className="flex flex-col gap-1.5 min-w-[130px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Categoria</span>
                  {isEditing ? (
                    <Select value={currentTask.category} onValueChange={(val) => setEditedTask({...editedTask, category: val as Category})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50 dark:bg-slate-950"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {categories.map(c => <SelectItem key={c} value={c} className="text-xs">{c}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="font-bold text-slate-800 dark:text-slate-100 h-8 flex items-center text-sm">{currentTask.category}</div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* Prioridade */}
                <div className="flex flex-col gap-1.5 min-w-[110px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Prioridade</span>
                  {isEditing ? (
                    <Select value={currentTask.priority} onValueChange={(val) => setEditedTask({...editedTask, priority: val as Priority})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50 dark:bg-slate-950"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {priorities.map(p => <SelectItem key={p} value={p} className="text-xs">{p}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="h-8 flex items-center">
                      <span className={cn(
                        "px-2.5 py-1 rounded text-xs font-bold uppercase tracking-wider shadow-sm",
                        currentTask.priority === 'Alta' ? 'bg-orange-100 dark:bg-orange-500/15 text-orange-700 dark:text-orange-400 border border-orange-200' : 
                        currentTask.priority === 'Urgente' ? 'bg-red-100 dark:bg-red-500/15 text-red-700 dark:text-red-400 border border-red-200' : 'bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-800'
                      )}>
                        {currentTask.priority}
                      </span>
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* Prazo */}
                <div className="flex flex-col gap-1.5 min-w-[140px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Prazo Solicitado</span>
                  {isEditing ? (
                    <Popover>
                      <PopoverTrigger className={cn("flex h-8 w-full items-center justify-start rounded-md border border-input bg-slate-50 dark:bg-slate-950 px-2 py-1 text-xs font-semibold shadow-sm", !dueDate && "text-muted-foreground")}>
                        <CalendarIcon className="mr-2 h-3.5 w-3.5" />
                        {dueDate ? format(dueDate, "dd/MM/yyyy") : <span>Data</span>}
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0">
                        <Calendar mode="single" selected={dueDate} onSelect={(date) => setEditedTask({...editedTask, dueDate: date?.toISOString()})} />
                      </PopoverContent>
                    </Popover>
                  ) : (
                    <div className="h-8 flex items-center font-bold text-slate-800 dark:text-slate-100 gap-2 text-sm">
                      <CalendarIcon className="w-4 h-4 text-slate-400 dark:text-slate-500" />
                      {dueDate ? format(dueDate, "dd/MM/yyyy") : "Não definido"}
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* SLA / Dias Restantes */}
                <div className="flex flex-col gap-1.5 min-w-[150px] max-w-[200px] flex-1">
                  <div className="flex justify-between items-center text-[10px] font-bold uppercase tracking-wider">
                    <span className="text-slate-400 dark:text-slate-500">Dias Restantes</span>
                    <span className={daysLeft < 0 ? 'text-red-600 dark:text-red-400' : 'text-slate-700 dark:text-slate-200'}>{daysLeft < 0 ? 'Atrasado' : `${daysLeft} dias`}</span>
                  </div>
                  <div className="h-8 flex flex-col justify-center w-full gap-1.5">
                    <div className="h-2 w-full bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden border border-slate-200 dark:border-slate-800/50 shadow-inner">
                      <div 
                        className={cn(
                          "h-full rounded-full transition-all duration-500",
                          daysLeft < 0 ? 'bg-red-500' : progressPercent > 80 ? 'bg-amber-500' : 'bg-emerald-500'
                        )} 
                        style={{ width: `${progressPercent}%` }}
                      />
                    </div>
                  </div>
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div></div>
            </div>
          </div>

          {/* Main Body Content */}
          <div className="p-4 sm:p-6 lg:p-8 max-w-6xl mx-auto space-y-8 pb-16">
            
            {/* Briefing Section */}
            <div className="space-y-6">
              
              <div className="space-y-3">
                <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Descrição Completa</Label>
                {isEditing ? (
                  <Textarea 
                    value={currentTask.description} 
                    onChange={e => setEditedTask({...editedTask, description: e.target.value})}
                    className="min-h-[150px] resize-none bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 shadow-sm text-sm"
                  />
                ) : (
                  <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-5 sm:p-6 text-sm text-slate-800 dark:text-slate-100 whitespace-pre-wrap leading-relaxed">
                    {currentTask.description}
                  </div>
                )}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Links de Referência</Label>
                  {isEditing ? (
                    <Textarea 
                      value={linksString} 
                      onChange={e => handleLinksChange(e.target.value)}
                      placeholder="Cole os links de referência (Figma, Drive, etc) separados por vírgula ou linha"
                      className="min-h-[100px] resize-none bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 shadow-sm text-sm"
                    />
                  ) : (
                    <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-4 sm:p-5 text-sm text-slate-800 dark:text-slate-100 flex flex-col gap-3 min-h-[100px]">
                      {currentTask.referenceLinks && currentTask.referenceLinks.length > 0 ? (
                        currentTask.referenceLinks.map((link, i) => {
                          const isUrl = link.startsWith('http://') || link.startsWith('https://');
                          const href = isUrl ? link : `https://${link}`;
                          return (
                            <a key={i} href={href} target="_blank" rel="noopener noreferrer" className="text-blue-600 dark:text-blue-400 hover:text-blue-700 hover:underline inline-flex items-center gap-2 font-medium bg-blue-50 dark:bg-blue-500/10/50 hover:bg-blue-50 px-3 py-2 rounded-lg w-fit break-all transition-colors border border-blue-100">
                              <ExternalLink className="w-4 h-4 shrink-0" />
                              {link}
                            </a>
                          );
                        })
                      ) : (
                        <span className="text-slate-400 dark:text-slate-500 italic">Nenhum link fornecido.</span>
                      )}
                    </div>
                  )}
                </div>

                <div className="space-y-3">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Observações Extras</Label>
                  {isEditing ? (
                    <Textarea 
                      value={currentTask.notes || ""} 
                      onChange={e => setEditedTask({...editedTask, notes: e.target.value})}
                      className="min-h-[100px] resize-none bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 shadow-sm text-sm"
                      placeholder="Informações adicionais importantes..."
                    />
                  ) : (
                    <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-4 sm:p-5 text-sm text-slate-800 dark:text-slate-100 whitespace-pre-wrap min-h-[100px]">
                      {currentTask.notes || <span className="text-slate-400 dark:text-slate-500 italic">Nenhuma observação extra.</span>}
                    </div>
                  )}
                </div>
              </div>

            </div>

            {/* Interaction Section (Comments & Timeline) */}
            {!isEditing && (
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 pt-6 border-t border-slate-200 dark:border-slate-800">
                
                {/* Comments (2/3 width) */}
                <div className="lg:col-span-2 space-y-4">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-2">
                    <MessageSquare className="w-4 h-4" /> Comentários
                  </Label>
                  <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden flex flex-col">
                    <div className="p-4 sm:p-6 space-y-6 max-h-[600px] overflow-y-auto">
                      {task.comments.length === 0 ? (
                        <div className="text-center text-slate-400 dark:text-slate-500 text-sm italic py-8 bg-slate-50 dark:bg-slate-950 rounded-xl border border-dashed border-slate-200 dark:border-slate-800">Nenhum comentário ainda.</div>
                      ) : (
                        task.comments.map(comment => {
                          const user = users.find(u => u.id === comment.userId);
                          const isMe = user?.id === currentUser?.id;
                          return (
                            <div key={comment.id} className={`flex gap-3 ${isMe ? 'flex-row-reverse' : ''}`}>
                              <div className="w-9 h-9 rounded-full bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-800 flex items-center justify-center shrink-0 shadow-sm">
                                <span className="text-xs font-bold text-slate-600 dark:text-slate-300">
                                  {user?.name ? user.name.split(' ').map(n=>n[0]).join('').substring(0,2).toUpperCase() : "?"}
                                </span>
                              </div>
                              <div className={`flex flex-col max-w-[85%] ${isMe ? 'items-end' : 'items-start'}`}>
                                <div className="flex items-center gap-2 mb-1.5 px-1">
                                  <span className="text-xs font-bold text-slate-700 dark:text-slate-200">{user?.name}</span>
                                  <span className="text-[10px] text-slate-400 dark:text-slate-500 font-medium">{format(parseISO(comment.createdAt), "dd/MM/yyyy HH:mm")}</span>
                                </div>
                                <div className={`px-4 py-2.5 rounded-2xl text-sm shadow-sm ${isMe ? 'bg-blue-600 text-white rounded-tr-sm' : 'bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 rounded-tl-sm'}`}>
                                  {comment.text}
                                </div>
                              </div>
                            </div>
                          )
                        })
                      )}
                    </div>
                    <div className="p-3 sm:p-4 bg-slate-50 dark:bg-slate-950 border-t border-slate-100 dark:border-slate-800">
                      <div className="relative">
                        <Textarea 
                          placeholder="Escreva um comentário... (Use @ para mencionar)"
                          className="min-h-[70px] resize-none rounded-xl bg-white dark:bg-slate-900 pr-14 text-sm border-slate-200 dark:border-slate-800 shadow-sm focus-visible:ring-blue-500"
                          value={commentText}
                          onChange={e => setCommentText(e.target.value)}
                          onKeyDown={e => {
                            if(e.key === 'Enter' && !e.shiftKey) {
                              e.preventDefault();
                              handleAddComment();
                            }
                          }}
                        />
                        <Button 
                          size="icon"
                          className="absolute right-2 bottom-2 w-10 h-10 rounded-lg bg-blue-600 hover:bg-blue-700 text-white shadow-md transition-all"
                          onClick={handleAddComment}
                          disabled={!commentText.trim()}
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path></svg>
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Timeline (1/3 width) */}
                <div className="space-y-4">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-2">
                    <Activity className="w-4 h-4" /> Histórico Resumido
                  </Label>
                  <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-5 h-full min-h-[300px]">
                    <div className="space-y-5 relative before:absolute before:inset-0 before:ml-[11px] before:w-0.5 before:bg-slate-100 dark:before:bg-slate-800">
                      {task.timeline.slice(-8).reverse().map((event, i) => {
                        const user = users.find(u => u.id === event.userId);
                        return (
                          <div key={i} className="relative flex gap-3">
                            <div className="w-6 h-6 rounded-full bg-slate-50 dark:bg-slate-950 border-2 border-slate-200 dark:border-slate-800 flex items-center justify-center shrink-0 z-10">
                              <div className="w-1.5 h-1.5 rounded-full bg-slate-300 dark:bg-slate-600"></div>
                            </div>
                            <div className="pt-0.5">
                              <p className="text-[13px] text-slate-700 dark:text-slate-200 leading-tight">
                                <span className="font-semibold">{user?.name || "Sistema"}</span> {event.description}
                              </p>
                              <span className="text-[10px] text-slate-400 dark:text-slate-500 block mt-1 font-medium">{format(parseISO(event.createdAt), "dd/MM/yyyy HH:mm")}</span>
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  </div>
                </div>

              </div>
            )}
            
          </div>
        </div>
        
      </DialogContent>
    </Dialog>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "components/tasks"
cat > "components/tasks/task-form-modal.tsx" << 'GENESIS_HUB_EOF_dark1'

"use client";

import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useStore } from "@/lib/store";
import { Category, Priority, Department } from "@/lib/types";
import { toast } from "sonner";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { CalendarIcon, X } from "lucide-react";
import { format } from "date-fns";
import { ptBR } from "date-fns/locale";
import { cn } from "@/lib/utils";

interface TaskFormModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}







export function TaskFormModal({ open, onOpenChange }: TaskFormModalProps) {
  const { addTask, currentUser, categories, priorities, departments, statuses } = useStore();
  
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<Category | "">("");
  const [priority, setPriority] = useState<Priority | "">("");
  const [dueDate, setDueDate] = useState<Date | undefined>(undefined);
  const [referenceLinks, setReferenceLinks] = useState("");
  const [notes, setNotes] = useState("");
  const [requesterName, setRequesterName] = useState(currentUser?.name || "");
  const [department, setDepartment] = useState<Department | "">((currentUser?.department as Department) || "");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser) return;
    
    if (!title || !description || !category || !priority || !dueDate || !requesterName || !department) {
      toast.error("Preencha todos os campos obrigatórios");
      return;
    }

    addTask({
      title,
      description,
      category: category as Category,
      priority: priority as Priority,
      status: statuses[0] || "Triagem",
      requesterId: currentUser.id,
      requesterName,
      department: department as Department,
      dueDate: dueDate.toISOString(),
      referenceLinks: referenceLinks.split(/[\n, ]+/).map(l => l.trim()).filter(l => l.length > 0),
      notes: notes.trim() || undefined,
    });

    toast.success("Demanda criada com sucesso!");
    onOpenChange(false);
    
    // Reset form
    setTitle("");
    setDescription("");
    setCategory("");
    setPriority("");
    setDueDate(undefined);
    setReferenceLinks("");
    setNotes("");
    setRequesterName(currentUser?.name || "");
    setDepartment((currentUser?.department as Department) || "");
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[700px] w-[95vw] max-h-[90vh] flex flex-col p-0 overflow-hidden bg-white dark:bg-slate-900 border-none rounded-2xl shadow-2xl [&>button]:hidden">
        <DialogHeader className="px-6 py-4 border-b border-slate-100 dark:border-slate-800 flex flex-row items-center justify-between sticky top-0 bg-white dark:bg-slate-900 z-10">
          <DialogTitle className="text-xl font-bold">Nova Solicitação</DialogTitle>
          <Button type="button" variant="ghost" size="icon" onClick={() => onOpenChange(false)} className="h-8 w-8 rounded-full">
            <X className="w-4 h-4" />
          </Button>
        </DialogHeader>
        
        <div className="flex-1 overflow-y-auto px-6 py-4">
          <form id="task-form" onSubmit={handleSubmit} className="space-y-6 pb-8">
            <div className="space-y-4">

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pb-4 border-b border-slate-100 dark:border-slate-800">
                <div className="space-y-2">
                  <Label htmlFor="requesterName" className="text-xs font-semibold text-slate-600 dark:text-slate-300">Nome do Solicitante *</Label>
                  <Input 
                    id="requesterName"
                    value={requesterName} 
                    onChange={e => setRequesterName(e.target.value)}
                    className="h-10"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="text-xs font-semibold text-slate-600 dark:text-slate-300">Setor Solicitante *</Label>
                  <Select value={department} onValueChange={(val) => val && setDepartment(val as Department)}>
                    <SelectTrigger className="h-10"><SelectValue placeholder="Selecione o setor" /></SelectTrigger>
                    <SelectContent>
                      {departments.map(d => <SelectItem key={d} value={d}>{d}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="title" className="text-xs font-semibold text-slate-600 dark:text-slate-300">Título da Solicitação *</Label>
                <Input 
                  id="title"
                  value={title} 
                  onChange={e => setTitle(e.target.value)}
                  placeholder="Ex: Criar arte para redes sociais"
                  className="h-10"
                />
              </div>
              
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="text-xs font-semibold text-slate-600 dark:text-slate-300">Categoria *</Label>
                  <Select value={category} onValueChange={(val) => val && setCategory(val as Category)}>
                    <SelectTrigger className="h-10"><SelectValue placeholder="Selecione" /></SelectTrigger>
                    <SelectContent>
                      {categories.map(c => <SelectItem key={c} value={c}>{c}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                
                <div className="space-y-2">
                  <Label className="text-xs font-semibold text-slate-600 dark:text-slate-300">Prioridade *</Label>
                  <Select value={priority} onValueChange={(val) => val && setPriority(val as Priority)}>
                    <SelectTrigger className="h-10"><SelectValue placeholder="Selecione" /></SelectTrigger>
                    <SelectContent>
                      {priorities.map(p => <SelectItem key={p} value={p}>{p}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="space-y-2 flex flex-col">
                <Label className="text-xs font-semibold text-slate-600 dark:text-slate-300">Prazo Solicitado *</Label>
                <Popover>
                  <PopoverTrigger
                    className={cn(
                      "flex h-10 w-full items-center justify-start rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm ring-offset-background hover:bg-slate-50 dark:hover:bg-slate-800",
                      !dueDate && "text-muted-foreground"
                    )}
                  >
                    <CalendarIcon className="mr-2 h-4 w-4" />
                    {dueDate ? format(dueDate, "dd/MM/yyyy", { locale: ptBR }) : <span>Selecionar data</span>}
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0">
                    <Calendar 
                      mode="single" 
                      selected={dueDate} 
                      onSelect={setDueDate} 
                    />
                  </PopoverContent>
                </Popover>
              </div>

              <div className="space-y-2">
                <Label htmlFor="description" className="text-xs font-semibold text-slate-600 dark:text-slate-300">Descrição Completa *</Label>
                <Textarea 
                  id="description"
                  value={description} 
                  onChange={e => setDescription(e.target.value)}
                  placeholder="Detalhes da demanda..."
                  className="min-h-[100px]"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="referenceLinks" className="text-xs font-semibold text-slate-600 dark:text-slate-300">Links de Referência</Label>
                <Textarea 
                  id="referenceLinks"
                  value={referenceLinks} 
                  onChange={e => setReferenceLinks(e.target.value)}
                  placeholder="Links do Google Drive, Figma, Canva, Notion, etc."
                  className="min-h-[80px]"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="notes" className="text-xs font-semibold text-slate-600 dark:text-slate-300">Observações Extras</Label>
                <Textarea 
                  id="notes"
                  value={notes} 
                  onChange={e => setNotes(e.target.value)}
                  placeholder="Informações adicionais importantes..."
                  className="min-h-[80px]"
                />
              </div>

            </div>
          </form>
        </div>
        
        <div className="p-4 border-t border-slate-100 dark:border-slate-800 flex justify-end gap-3 bg-slate-50 dark:bg-slate-950">
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            Cancelar
          </Button>
          <Button type="submit" form="task-form" className="bg-blue-600 hover:bg-blue-700 text-white">
            Criar Solicitação
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "app/login"
cat > "app/login/page.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { Mail, Lock, Eye, EyeOff, ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { LOGO_URL } from "@/lib/branding";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase) {
      toast.error("Supabase não configurado.");
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      toast.error("Erro ao fazer login: " + error.message);
    } else {
      toast.success("Login efetuado com sucesso!");
      router.push("/");
    }
    setLoading(false);
  };

  return (
    <div className="min-h-screen w-full flex bg-[#0b1430] text-white overflow-hidden relative">
      {/* Grade de fundo futurista */}
      <div
        className="absolute inset-0 opacity-[0.07] pointer-events-none"
        style={{
          backgroundImage:
            "linear-gradient(to right, #6ea8ff 1px, transparent 1px), linear-gradient(to bottom, #6ea8ff 1px, transparent 1px)",
          backgroundSize: "48px 48px",
        }}
      />
      {/* Glow decorativo */}
      <div className="absolute -top-40 -left-40 w-[500px] h-[500px] bg-blue-600/20 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[500px] h-[500px] bg-indigo-500/20 rounded-full blur-[120px] pointer-events-none" />

      {/* Lado esquerdo — narrativa / marca */}
      <div className="hidden lg:flex flex-col justify-between w-1/2 p-14 relative z-10">
        <div className="flex items-center gap-3">
          <img src={LOGO_URL} alt="Genesis Hub" className="h-9 object-contain" />
          <span className="text-xs tracking-[0.3em] text-blue-300/70 uppercase">Marketing Ops</span>
        </div>

        <div>
          <div className="flex items-center gap-2 mb-6 text-emerald-400 text-sm">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-400" />
            </span>
            Sistema operando normalmente
          </div>
          <h1 className="text-4xl xl:text-5xl font-bold leading-tight mb-4">
            Toda solicitação de marketing,{" "}
            <span className="text-blue-400">visível em tempo real.</span>
          </h1>
          <p className="text-blue-200/60 max-w-md">
            O Genesis Hub organiza cada demanda em um kanban único — colaboradores
            acompanham suas tarefas, gestores enxergam atrasos antes que aconteçam.
          </p>

          <div className="flex gap-10 mt-10">
            <div>
              <div className="text-3xl font-bold">128</div>
              <div className="text-xs text-blue-300/50 uppercase tracking-wider">Demandas ativas</div>
            </div>
            <div>
              <div className="text-3xl font-bold">94%</div>
              <div className="text-xs text-blue-300/50 uppercase tracking-wider">No prazo</div>
            </div>
            <div>
              <div className="text-3xl font-bold">6</div>
              <div className="text-xs text-blue-300/50 uppercase tracking-wider">Times conectados</div>
            </div>
          </div>
        </div>

        <p className="text-xs text-blue-300/30">© {new Date().getFullYear()} Genesis Hub — todos os direitos reservados.</p>
      </div>

      {/* Lado direito — formulário */}
      <div className="flex flex-1 items-center justify-center p-6 relative z-10">
        <div className="w-full max-w-sm">
          <div className="lg:hidden flex justify-center mb-8">
            <img src={LOGO_URL} alt="Genesis Hub" className="h-10 object-contain" />
          </div>

          <h2 className="text-2xl font-bold mb-1">Bem-vindo de volta</h2>
          <p className="text-sm text-blue-200/50 mb-8">Acesse sua conta para acompanhar suas demandas.</p>

          <form onSubmit={handleLogin} className="space-y-5">
            <div className="space-y-1.5">
              <label htmlFor="email" className="text-xs font-medium text-blue-200/70">E-mail corporativo</label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-blue-300/40" />
                <input
                  id="email"
                  type="email"
                  placeholder="voce@empresa.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="w-full bg-white dark:bg-slate-900/5 border border-white/10 rounded-lg pl-10 pr-3 py-2.5 text-sm text-white placeholder:text-blue-300/30 outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
                />
              </div>
            </div>

            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label htmlFor="password" className="text-xs font-medium text-blue-200/70">Senha</label>
                <a href="/forgot-password" className="text-xs text-blue-400 hover:text-blue-300 hover:underline">
                  Esqueci minha senha
                </a>
              </div>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-blue-300/40" />
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full bg-white dark:bg-slate-900/5 border border-white/10 rounded-lg pl-10 pr-10 py-2.5 text-sm text-white outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-blue-300/40 hover:text-blue-200 transition-colors"
                  tabIndex={-1}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className={cn(
                "w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-medium rounded-lg py-2.5 transition-all",
                "disabled:opacity-60 disabled:cursor-not-allowed shadow-[0_0_20px_rgba(59,130,246,0.35)]"
              )}
            >
              {loading ? "Entrando..." : "Entrar"}
              {!loading && <ArrowRight className="w-4 h-4" />}
            </button>
          </form>

          <div className="flex items-center gap-3 my-7">
            <div className="flex-1 h-px bg-white dark:bg-slate-900/10" />
            <span className="text-[10px] uppercase tracking-widest text-blue-300/30">acesso restrito</span>
            <div className="flex-1 h-px bg-white dark:bg-slate-900/10" />
          </div>

          <p className="text-center text-xs text-blue-200/40">
            Ainda não tem acesso?{" "}
            <a href="mailto:contato@genesishub.com" className="text-blue-400 hover:text-blue-300 hover:underline">
              Fale com o gestor do seu setor
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "app/forgot-password"
cat > "app/forgot-password/page.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { LOGO_URL } from "@/lib/branding";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase) {
      toast.error("Supabase não configurado.");
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    if (error) {
      toast.error("Erro ao enviar e-mail: " + error.message);
    } else {
      toast.success("E-mail de recuperação enviado com sucesso! Verifique sua caixa de entrada.");
      router.push("/login");
    }
    setLoading(false);
  };

  return (
    <div className="flex h-screen w-full items-center justify-center bg-slate-50 dark:bg-slate-950">
      <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-xl p-8 border border-slate-100 dark:border-slate-800">
        <div className="flex flex-col items-center mb-8">
          <img src={LOGO_URL} alt="Genesis Hub" className="h-12 object-contain mb-4" />
          <h1 className="text-2xl font-bold text-slate-800 dark:text-slate-100">Recuperar Senha</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 text-center">Informe seu e-mail para receber um link de recuperação.</p>
        </div>
        <form onSubmit={handleReset} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">E-mail</Label>
            <Input 
              id="email" 
              type="email" 
              placeholder="seu@email.com" 
              value={email} 
              onChange={e => setEmail(e.target.value)}
              required
            />
          </div>
          <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700" disabled={loading}>
            {loading ? "Enviando..." : "Enviar Link"}
          </Button>
          <div className="text-center mt-4">
            <a href="/login" className="text-sm text-blue-600 dark:text-blue-400 hover:underline">Voltar para o Login</a>
          </div>
        </form>
      </div>
    </div>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "app/reset-password"
cat > "app/reset-password/page.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { LOGO_URL } from "@/lib/branding";

export default function ResetPasswordPage() {
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  useEffect(() => {
    // Check if we have a session to reset the password
    supabase?.auth.onAuthStateChange(async (event, session) => {
      if (event == "PASSWORD_RECOVERY") {
        console.log("Password recovery event received");
      }
    });
  }, []);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase) {
      toast.error("Supabase não configurado.");
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.updateUser({ password });
    
    if (error) {
      toast.error("Erro ao atualizar senha: " + error.message);
    } else {
      toast.success("Senha atualizada com sucesso!");
      router.push("/");
    }
    setLoading(false);
  };

  return (
    <div className="flex h-screen w-full items-center justify-center bg-slate-50 dark:bg-slate-950">
      <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-xl p-8 border border-slate-100 dark:border-slate-800">
        <div className="flex flex-col items-center mb-8">
          <img src={LOGO_URL} alt="Genesis Hub" className="h-12 object-contain mb-4" />
          <h1 className="text-2xl font-bold text-slate-800 dark:text-slate-100">Nova Senha</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 text-center">Digite sua nova senha para acessar o sistema.</p>
        </div>
        <form onSubmit={handleUpdate} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="password">Nova Senha</Label>
            <Input 
              id="password" 
              type="password" 
              placeholder="Digite a nova senha" 
              value={password} 
              onChange={e => setPassword(e.target.value)}
              required
              minLength={6}
            />
          </div>
          <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700" disabled={loading}>
            {loading ? "Salvando..." : "Atualizar Senha"}
          </Button>
        </form>
      </div>
    </div>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "app/invite"
cat > "app/invite/page.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";
import { useState, useEffect, Suspense } from "react";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { useRouter, useSearchParams } from "next/navigation";
import { Mail, Lock, Eye, EyeOff, ArrowRight, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";
import { LOGO_URL } from "@/lib/branding";

function FuturisticBackground() {
  return (
    <>
      <div
        className="absolute inset-0 opacity-[0.07] pointer-events-none"
        style={{
          backgroundImage:
            "linear-gradient(to right, #6ea8ff 1px, transparent 1px), linear-gradient(to bottom, #6ea8ff 1px, transparent 1px)",
          backgroundSize: "48px 48px",
        }}
      />
      <div className="absolute -top-40 -left-40 w-[500px] h-[500px] bg-blue-600/20 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-[500px] h-[500px] bg-indigo-500/20 rounded-full blur-[120px] pointer-events-none" />
    </>
  );
}

function InviteContent() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token");

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const [inviteData, setInviteData] = useState<{name: string, role: string, type?: string, department: string} | null>(null);

  useEffect(() => {
    if (token) {
      try {
        const decoded = JSON.parse(decodeURIComponent(escape(atob(token))));
        if (decoded.name && decoded.role && decoded.department) {
          // eslint-disable-next-line react-hooks/set-state-in-effect
          setInviteData(decoded);
        }
      } catch (e) {
        toast.error("Link de convite inválido ou corrompido.");
      }
    }
  }, [token]);

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase || !inviteData) return;
    setLoading(true);

    const { data: authData, error: authError } = await supabase.auth.signUp({ 
      email, 
      password,
      options: {
        data: {
          nome: inviteData.name,
          cargo: inviteData.role,
          role: inviteData.type || 'Colaborador',
          department: inviteData.department,
        }
      }
    });

    if (authError) {
      toast.error("Erro ao criar conta: " + authError.message);
      setLoading(false);
      return;
    }

    if (authData.user) {
      if (!authData.session) {
        toast.success("Conta criada! Verifique seu e-mail para confirmar o login.");
        router.push('/login');
        return;
      }

      const { error: dbError } = await supabase.from('users').upsert([{
        id: authData.user.id,
        name: inviteData.name,
        role: inviteData.type || 'Colaborador',
        department: inviteData.department,
        email: email
      }], { onConflict: 'id' });

      if (dbError) {
        toast.error("Conta criada, mas erro ao salvar perfil: " + dbError.message);
      } else {
        toast.success("Conta criada com sucesso! Você já pode acessar.");
        router.push("/");
      }
    }
    setLoading(false);
  };

  if (!inviteData) {
    return (
      <div className="min-h-screen w-full flex items-center justify-center bg-[#0b1430] text-white p-4 text-center relative overflow-hidden">
        <FuturisticBackground />
        <div className="relative z-10">
          <h1 className="text-2xl font-bold mb-2">Convite Inválido</h1>
          <p className="text-blue-200/60 mb-6">O link que você acessou não contém um convite válido.</p>
          <button
            onClick={() => router.push("/login")}
            className="border border-white/15 text-white/80 hover:bg-white/5 rounded-lg px-4 py-2 text-sm transition-colors"
          >
            Voltar para o Login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-[#0b1430] text-white p-4 relative overflow-hidden">
      <FuturisticBackground />

      <div className="w-full max-w-md bg-white dark:bg-slate-900/[0.04] backdrop-blur-sm rounded-2xl shadow-2xl p-8 border border-white/10 relative z-10">
        <div className="flex flex-col items-center mb-8">
          <img src={LOGO_URL} alt="Genesis Hub" className="h-11 object-contain mb-5" />
          <div className="flex items-center gap-1.5 text-xs text-blue-300/70 uppercase tracking-widest mb-3">
            <Sparkles className="w-3.5 h-3.5" />
            Convite recebido
          </div>
          <h1 className="text-2xl font-bold text-center leading-tight">Olá, {inviteData.name}</h1>
          <p className="text-sm text-blue-200/60 text-center mt-3 leading-relaxed">
            Você foi convidado para participar do <strong className="text-white">Genesis Hub</strong>.<br />
            Sua função será <strong className="text-white">{inviteData.role}</strong> no setor{" "}
            <strong className="text-white">{inviteData.department}</strong>.
            {inviteData.type && <><br />Tipo de acesso: <strong className="text-white">{inviteData.type}</strong></>}
          </p>
          <p className="text-sm font-medium text-blue-100/80 text-center mt-4">
            Para aceitar o convite, crie sua conta com e-mail e senha abaixo.
          </p>
        </div>

        <form onSubmit={handleRegister} className="space-y-5">
          <div className="space-y-1.5">
            <label htmlFor="email" className="text-xs font-medium text-blue-200/70">Seu e-mail</label>
            <div className="relative">
              <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-blue-300/40" />
              <input
                id="email"
                type="email"
                placeholder="seu@email.com"
                value={email}
                onChange={e => setEmail(e.target.value)}
                required
                className="w-full bg-white dark:bg-slate-900/5 border border-white/10 rounded-lg pl-10 pr-3 py-2.5 text-sm text-white placeholder:text-blue-300/30 outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <label htmlFor="password" className="text-xs font-medium text-blue-200/70">Crie uma senha</label>
            <div className="relative">
              <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-blue-300/40" />
              <input
                id="password"
                type={showPassword ? "text" : "password"}
                placeholder="Mínimo 6 caracteres"
                value={password}
                onChange={e => setPassword(e.target.value)}
                required
                minLength={6}
                className="w-full bg-white dark:bg-slate-900/5 border border-white/10 rounded-lg pl-10 pr-10 py-2.5 text-sm text-white placeholder:text-blue-300/30 outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
              />
              <button
                type="button"
                onClick={() => setShowPassword(v => !v)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-blue-300/40 hover:text-blue-200 transition-colors"
                tabIndex={-1}
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className={cn(
              "w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-500 text-white font-medium rounded-lg py-2.5 transition-all mt-2",
              "disabled:opacity-60 disabled:cursor-not-allowed shadow-[0_0_20px_rgba(59,130,246,0.35)]"
            )}
          >
            {loading ? "Criando conta..." : "Criar conta e acessar"}
            {!loading && <ArrowRight className="w-4 h-4" />}
          </button>
        </form>
      </div>
    </div>
  );
}

export default function InvitePage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen w-full flex items-center justify-center bg-[#0b1430]">
        <div className="w-8 h-8 rounded-full border-4 border-white/10 border-t-blue-500 animate-spin"></div>
      </div>
    }>
      <InviteContent />
    </Suspense>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "app/(app)/admin/settings"
cat > "app/(app)/admin/settings/page.tsx" << 'GENESIS_HUB_EOF_dark1'
"use client";
import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Trash2, Plus, Link as LinkIcon, Copy, Check, Pencil, Users as UsersIcon } from "lucide-react";
import { useStore } from "@/lib/store";
import { User } from "@/lib/types";

export default function SettingsPage() {
  const { roles, users, refreshTasks, stageOwners, addStageOwner, removeStageOwner } = useStore();
  const [departments, setDepartments] = useState<string[]>([]);
  const [statuses, setStatuses] = useState<string[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [priorities, setPriorities] = useState<string[]>([]);

  const [newDept, setNewDept] = useState("");
  const [newStatus, setNewStatus] = useState("");
  const [newCategory, setNewCategory] = useState("");
  const [newPriority, setNewPriority] = useState("");

  // Donos de etapa
  const [ownerStatus, setOwnerStatus] = useState("");
  const [ownerUserId, setOwnerUserId] = useState("");
  const [savingOwner, setSavingOwner] = useState(false);

  // Invite state
  const [inviteName, setInviteName] = useState("");
  const [inviteRole, setInviteRole] = useState("");
  const [inviteType, setInviteType] = useState("");
  const [inviteDept, setInviteDept] = useState("");
  const [generatedLink, setGeneratedLink] = useState("");
  const [copied, setCopied] = useState(false);

  // Edição de colaborador
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [editName, setEditName] = useState("");
  const [editRole, setEditRole] = useState(""); // Função (Cargo) -> coluna tipo_usuario
  const [editType, setEditType] = useState(""); // Tipo de Usuário -> coluna role
  const [editDept, setEditDept] = useState("");
  const [savingEdit, setSavingEdit] = useState(false);

  const fetchData = async () => {
    if (!supabase) return;
    const [deptRes, statusRes, catRes, prioRes] = await Promise.all([
      supabase.from("departments").select("name"),
      supabase.from("statuses").select("name"),
      supabase.from("categories").select("name"),
      supabase.from("priorities").select("name"),
    ]);

    if (deptRes.data) setDepartments(deptRes.data.map(d => d.name));
    if (statusRes.data) setStatuses(statusRes.data.map(s => s.name));
    if (catRes.data) setCategories(catRes.data.map(c => c.name));
    if (prioRes.data) setPriorities(prioRes.data.map(p => p.name));
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    fetchData();
  }, []);

  const handleAdd = async (table: string, value: string, setter: (val: string) => void) => {
    if (!value.trim() || !supabase) return;
    const { error } = await supabase.from(table).insert([{ name: value.trim() }]);
    if (error) {
      toast.error(`Erro ao adicionar: ${error.message}`);
    } else {
      toast.success("Adicionado com sucesso!");
      setter("");
      fetchData();
    }
  };

  const handleDelete = async (table: string, value: string) => {
    if (!supabase) return;
    const { error } = await supabase.from(table).delete().eq("name", value);
    if (error) {
      toast.error(`Erro ao remover: ${error.message}`);
    } else {
      toast.success("Removido com sucesso!");
      fetchData();
    }
  };

  const handleAddStageOwner = async () => {
    if (!ownerStatus || !ownerUserId) {
      toast.error("Escolha a etapa e o responsável.");
      return;
    }
    const alreadyExists = stageOwners.some(s => s.status === ownerStatus && s.userId === ownerUserId);
    if (alreadyExists) {
      toast.error("Essa pessoa já é responsável por essa etapa.");
      return;
    }
    setSavingOwner(true);
    await addStageOwner(ownerStatus, ownerUserId);
    setSavingOwner(false);
    setOwnerUserId("");
  };

  const openEditUser = (user: User) => {
    setEditingUser(user);
    setEditName(user.name || "");
    setEditRole(user.tipo_usuario || "");
    setEditType(user.role || "");
    setEditDept((user.department as string) || "");
  };

  const saveEditUser = async () => {
    if (!supabase || !editingUser) return;
    if (!editName.trim() || !editType) {
      toast.error("Nome e Tipo de Usuário são obrigatórios.");
      return;
    }
    setSavingEdit(true);
    const { error } = await supabase
      .from("users")
      .update({
        name: editName.trim(),
        tipo_usuario: editRole.trim() || null,
        role: editType,
        department: editDept || null,
      })
      .eq("id", editingUser.id);
    setSavingEdit(false);

    if (error) {
      toast.error("Erro ao salvar: " + error.message);
      return;
    }
    toast.success("Colaborador atualizado com sucesso!");
    setEditingUser(null);
    await refreshTasks();
  };

  const generateInviteLink = () => {
    if (!inviteName || !inviteRole || !inviteType || !inviteDept) {
      toast.error("Preencha todos os campos para gerar o link.");
      return;
    }

    const payload = JSON.stringify({
      name: inviteName,
      role: inviteRole,
      type: inviteType,
      department: inviteDept
    });
    
    // Create a base64 encoded token
    const token = btoa(unescape(encodeURIComponent(payload)));
    const link = `${window.location.origin}/invite?token=${token}`;
    
    setGeneratedLink(link);
    setCopied(false);
  };

  const copyLink = () => {
    if (generatedLink) {
      navigator.clipboard.writeText(generatedLink);
      setCopied(true);
      toast.success("Link copiado para a área de transferência!");
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const renderSection = (title: string, items: string[], newValue: string, setNewValue: (v: string) => void, table: string) => (
    <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
      <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 mb-4 uppercase">{title}</h3>
      <div className="flex gap-2 mb-4">
        <Input value={newValue} onChange={e => setNewValue(e.target.value)} placeholder={`Novo ${title.toLowerCase()}`} className="h-9" />
        <Button onClick={() => handleAdd(table, newValue, setNewValue)} size="sm" className="bg-blue-600 hover:bg-blue-700 h-9 shrink-0"><Plus className="w-4 h-4 mr-1" /> Adicionar</Button>
      </div>
      <div className="space-y-2 max-h-48 overflow-y-auto">
        {items.map(item => (
          <div key={item} className="flex items-center justify-between p-2 rounded bg-slate-50 dark:bg-slate-950 border border-slate-100 dark:border-slate-800">
            <span className="text-sm font-medium text-slate-700 dark:text-slate-200">{item}</span>
            <Button variant="ghost" size="icon" onClick={() => handleDelete(table, item)} className="h-7 w-7 text-red-500 dark:text-red-400 hover:text-red-700 hover:bg-red-50">
              <Trash2 className="w-4 h-4" />
            </Button>
          </div>
        ))}
        {items.length === 0 && <p className="text-xs text-slate-400 dark:text-slate-500 italic">Nenhum item cadastrado.</p>}
      </div>
    </div>
  );

  return (
    <>
      <div className="p-4 sm:p-8 max-w-6xl mx-auto space-y-8">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white">Configurações</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400">Cadastre colaboradores e gerencie os menus do sistema.</p>
        </div>

        {/* Cadastro de Colaborador */}
        <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm space-y-6">
          <div>
            <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100">Cadastrar Colaborador</h2>
            <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">Preencha os dados para gerar um link de convite exclusivo.</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4 items-end">
            <div className="space-y-2">
              <Label htmlFor="inviteName" className="text-xs">Nome do Colaborador</Label>
              <Input 
                id="inviteName" 
                value={inviteName} 
                onChange={e => setInviteName(e.target.value)} 
                placeholder="Ex: Gustavo" 
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="inviteRole" className="text-xs">Função (Cargo)</Label>
              <Input 
                id="inviteRole" 
                value={inviteRole} 
                onChange={e => setInviteRole(e.target.value)} 
                placeholder="Ex: Designer" 
              />
            </div>

            <div className="space-y-2">
              <Label className="text-xs">Tipo de Usuário</Label>
              <Select value={inviteType} onValueChange={(val) => setInviteType(val || "")}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione" />
                </SelectTrigger>
                <SelectContent>
                  {roles.map(r => (
                    <SelectItem key={r} value={r}>{r}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label className="text-xs">Setor</Label>
              <Select value={inviteDept} onValueChange={(val) => setInviteDept(val || "")}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione" />
                </SelectTrigger>
                <SelectContent>
                  {departments.map(d => (
                    <SelectItem key={d} value={d}>{d}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <Button onClick={generateInviteLink} className="w-full bg-slate-900 hover:bg-slate-800">
              <LinkIcon className="w-4 h-4 mr-2" />
              Gerar Link
            </Button>
          </div>

          {generatedLink && (
            <div className="mt-4 p-4 bg-blue-50 dark:bg-blue-500/10 border border-blue-100 rounded-lg flex flex-col gap-3 animate-in fade-in slide-in-from-top-4 duration-300">
              <p className="text-sm font-medium text-blue-900">
                Link gerado! Envie este link para o colaborador.
              </p>
              <div className="flex gap-2">
                <Input value={generatedLink} readOnly className="bg-white dark:bg-slate-900 border-blue-200 focus-visible:ring-blue-500" />
                <Button onClick={copyLink} variant="outline" className="bg-white dark:bg-slate-900 border-blue-200 hover:bg-blue-50 text-blue-700 dark:text-blue-400 shrink-0">
                  {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                </Button>
              </div>
            </div>
          )}
        </div>

        {/* Colaboradores Cadastrados */}
        <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <UsersIcon className="w-4 h-4 text-slate-500 dark:text-slate-400" />
            <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100">Colaboradores Cadastrados</h2>
          </div>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">Edite nome, função, tipo de usuário e setor de quem já tem conta no sistema.</p>

          <div className="space-y-2">
            {users.map(user => (
              <div key={user.id} className="flex flex-wrap items-center gap-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-950 border border-slate-100 dark:border-slate-800">
                <div className="flex-1 min-w-[140px]">
                  <p className="text-sm font-semibold text-slate-800 dark:text-slate-100">{user.name}</p>
                  <p className="text-xs text-slate-400 dark:text-slate-500">{user.email}</p>
                </div>
                <span className="text-xs text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 px-2 py-1 rounded min-w-[100px] text-center">
                  {user.tipo_usuario || "Sem função"}
                </span>
                <span className={`text-[10px] font-bold px-2 py-1 rounded uppercase ${
                  user.role === "Admin" ? "bg-violet-100 dark:bg-violet-500/15 text-violet-700" :
                  user.role === "Gestor" ? "bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400" :
                  "bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
                }`}>
                  {user.role}
                </span>
                <span className="text-xs text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 px-2 py-1 rounded min-w-[100px] text-center">
                  {(user.department as string) || "Sem setor"}
                </span>
                <Button variant="ghost" size="icon" onClick={() => openEditUser(user)} className="h-8 w-8 text-slate-500 dark:text-slate-400 hover:text-blue-600 hover:bg-blue-50 shrink-0">
                  <Pencil className="w-4 h-4" />
                </Button>
              </div>
            ))}
            {users.length === 0 && <p className="text-sm text-slate-400 dark:text-slate-500 italic">Nenhum colaborador cadastrado ainda.</p>}
          </div>
        </div>

        {/* Donos de Etapa */}
        <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-1">Donos de Etapa</h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">
            Escolha quem é avisado (no sino e por e-mail) toda vez que uma demanda chega numa etapa específica do Kanban — independente de quem é o responsável pela tarefa.
          </p>

          <div className="flex flex-wrap items-end gap-3 mb-5">
            <div className="flex-1 min-w-[160px] space-y-1.5">
              <Label className="text-xs">Etapa</Label>
              <Select value={ownerStatus} onValueChange={(value) => setOwnerStatus(value ?? "")}>
                <SelectTrigger><SelectValue placeholder="Selecione a etapa" /></SelectTrigger>
                <SelectContent>
                  {statuses.map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="flex-1 min-w-[160px] space-y-1.5">
              <Label className="text-xs">Responsável</Label>
              <Select value={ownerUserId} onValueChange={(value) => setOwnerUserId(value ?? "")}>
                <SelectTrigger><SelectValue>{ownerUserId ? users.find(u => u.id === ownerUserId)?.name : "Selecione a pessoa"}</SelectValue></SelectTrigger>
                <SelectContent>
                  {users.map(u => <SelectItem key={u.id} value={u.id}>{u.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <Button onClick={handleAddStageOwner} disabled={savingOwner} className="bg-blue-600 hover:bg-blue-700">
              <Plus className="w-4 h-4 mr-1" /> Adicionar
            </Button>
          </div>

          <div className="space-y-3">
            {statuses.filter(s => stageOwners.some(so => so.status === s)).map(status => (
              <div key={status} className="flex flex-wrap items-center gap-2 p-3 rounded-lg bg-slate-50 dark:bg-slate-950 border border-slate-100 dark:border-slate-800">
                <span className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase w-40 shrink-0">{status}</span>
                <div className="flex flex-wrap gap-2">
                  {stageOwners.filter(so => so.status === status).map(so => {
                    const owner = users.find(u => u.id === so.userId);
                    return (
                      <span key={so.id} className="inline-flex items-center gap-1.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-xs font-medium text-slate-700 dark:text-slate-200 px-2.5 py-1 rounded-full">
                        {owner?.name || "Usuário removido"}
                        <button onClick={() => removeStageOwner(so.id)} className="text-slate-400 dark:text-slate-500 hover:text-red-500">
                          <Trash2 className="w-3 h-3" />
                        </button>
                      </span>
                    );
                  })}
                </div>
              </div>
            ))}
            {stageOwners.length === 0 && (
              <p className="text-sm text-slate-400 dark:text-slate-500 italic">Nenhuma etapa com dono configurado ainda — ninguém recebe notificação automática por etapa.</p>
            )}
          </div>
        </div>

        {/* Opções do Sistema */}
        <div>
          <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-1">Menus do Sistema</h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">Adicione ou remova opções disponíveis ao abrir uma nova demanda.</p>
          
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
            {renderSection("Setor Solicitante", departments, newDept, setNewDept, "departments")}
            {renderSection("Categoria", categories, newCategory, setNewCategory, "categories")}
            {renderSection("Prioridade", priorities, newPriority, setNewPriority, "priorities")}
          </div>
        </div>
      </div>

      {/* Modal de edição de colaborador */}
      <Dialog open={!!editingUser} onOpenChange={(open) => !open && setEditingUser(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Editar Colaborador</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 pt-2">
            <div className="space-y-2">
              <Label htmlFor="editName" className="text-xs">Nome</Label>
              <Input id="editName" value={editName} onChange={e => setEditName(e.target.value)} placeholder="Ex: Gustavo" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="editRole" className="text-xs">Função (Cargo)</Label>
              <Input id="editRole" value={editRole} onChange={e => setEditRole(e.target.value)} placeholder="Ex: Designer" />
            </div>
            <div className="space-y-2">
              <Label className="text-xs">Tipo de Usuário</Label>
              <Select value={editType} onValueChange={(val) => setEditType(val || "")}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione" />
                </SelectTrigger>
                <SelectContent>
                  {roles.map(r => (
                    <SelectItem key={r} value={r}>{r}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs">Setor</Label>
              <Select value={editDept} onValueChange={(val) => setEditDept(val || "")}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione" />
                </SelectTrigger>
                <SelectContent>
                  {departments.map(d => (
                    <SelectItem key={d} value={d}>{d}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" onClick={() => setEditingUser(null)}>Cancelar</Button>
              <Button onClick={saveEditUser} disabled={savingEdit} className="bg-blue-600 hover:bg-blue-700">
                {savingEdit ? "Salvando..." : "Salvar alterações"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
GENESIS_HUB_EOF_dark1

mkdir -p "app/(app)/kanban"
cat > "app/(app)/kanban/page.tsx" << 'GENESIS_HUB_EOF_dark1'
import { Suspense } from 'react';
import { KanbanBoard } from '@/components/kanban/board';

export default function KanbanPage() {
  return (
    <Suspense fallback={<div className="flex h-full items-center justify-center"><div className="w-8 h-8 rounded-full border-4 border-slate-200 dark:border-slate-800 border-t-blue-600 animate-spin" /></div>}>
      <KanbanBoard />
    </Suspense>
  );
}
GENESIS_HUB_EOF_dark1

echo "Todos os arquivos foram atualizados."
git add -A
git commit -m "feat: modo escuro persistente com botao no header"
git push
echo "Commit e push feitos. Aguarde o deploy da Vercel."
