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
