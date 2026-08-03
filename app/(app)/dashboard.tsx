"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useStore } from "@/lib/store";
import { isToday, isPast, parseISO } from "date-fns";
import { CheckCircle2, Clock, ListTodo, AlertCircle } from "lucide-react";
import { Bar, BarChart, ResponsiveContainer, XAxis, YAxis, Tooltip } from "recharts";

export default function DashboardPage() {
  const { tasks, currentUser, users } = useStore();

  const isGestorOrAdmin = currentUser?.role === "Admin" || currentUser?.role === "Gestor";
  
  // Se for colaborador, vê apenas suas tarefas no dashboard
  const displayTasks = isGestorOrAdmin 
    ? tasks 
    : tasks.filter(t => t.assigneeId === currentUser?.id || t.requesterId === currentUser?.id);

  
  const inTriagem = displayTasks.filter(t => t.status === "Triagem").length;
  const inProgress = displayTasks.filter(t => t.status !== "Aprovado").length;
  
  const delayed = displayTasks.filter(t => 
    t.status !== "Aprovado" && t.dueDate &&
    isPast(parseISO(t.dueDate)) && !isToday(parseISO(t.dueDate))
  ).length;

  const dueToday = displayTasks.filter(t => 
    t.status !== "Aprovado" && t.dueDate &&
    isToday(parseISO(t.dueDate))
  ).length;

  // Chart data for categories

  const categoriesCount = displayTasks.reduce((acc, task) => {
    acc[task.category] = (acc[task.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const chartData = Object.keys(categoriesCount).map(key => ({
    name: key,
    total: categoriesCount[key]
  }));

  // SLA Calculations
  const completedTasks = displayTasks.filter(t => t.status === "Aprovado" && t.completedAt);
  
  let avgDeliveryTime = 0;
  if (completedTasks.length > 0) {
    const totalDays = completedTasks.reduce((acc, task) => {
      const start = parseISO(task.createdAt);
      const end = parseISO(task.completedAt!);
      const diffTime = Math.abs(end.getTime() - start.getTime());
      const diffDays = diffTime / (1000 * 60 * 60 * 24);
      return acc + diffDays;
    }, 0);
    avgDeliveryTime = totalDays / completedTasks.length;
  }

  let slaPercentage = 0;
  const tasksWithDueDateAndCompleted = completedTasks.filter(t => t.dueDate);
  if (tasksWithDueDateAndCompleted.length > 0) {
    const onTimeCount = tasksWithDueDateAndCompleted.filter(t => {
       const due = parseISO(t.dueDate);
       const completed = parseISO(t.completedAt!);
       // Consider end of day for due date
       due.setHours(23, 59, 59, 999);
       return completed.getTime() <= due.getTime();
    }).length;
    slaPercentage = Math.round((onTimeCount / tasksWithDueDateAndCompleted.length) * 100);
  } else if (completedTasks.length > 0) {
    slaPercentage = 100;
  }

  const pendingTasks = displayTasks.filter(t => t.status !== "Aprovado");
  const bottleneckCounts = pendingTasks.reduce((acc, task) => {
    if (task.category) {
       acc[task.category] = (acc[task.category] || 0) + 1;
    }
    return acc;
  }, {} as Record<string, number>);
  
  let currentBottleneck = "Nenhum";
  let maxPending = 0;
  for (const [cat, count] of Object.entries(bottleneckCounts)) {
    if (count > maxPending) {
      maxPending = count;
      currentBottleneck = cat;
    }
  }

  // Carga de trabalho por pessoa — visão da equipe inteira (inclui Admins que
  // também são responsáveis por demandas, não só Colaboradores). Usa `tasks`
  // (todas), não `displayTasks`, porque essa seção só aparece pra quem já tem
  // visão geral (Admin/Gestor); um Colaborador nunca chega a ver essa parte.
  const activeCompanyTasks = tasks.filter(t => t.status !== "Aprovado");
  const workload = users
    .map(u => {
      const assigned = activeCompanyTasks.filter(t => t.assigneeId === u.id);
      const delayedCount = assigned.filter(t =>
        t.dueDate && isPast(parseISO(t.dueDate)) && !isToday(parseISO(t.dueDate))
      ).length;
      return { user: u, active: assigned.length, delayed: delayedCount };
    })
    .filter(w => w.active > 0)
    .sort((a, b) => b.active - a.active);

  const maxActive = Math.max(1, ...workload.map(w => w.active));
  const unassignedCount = activeCompanyTasks.filter(t => !t.assigneeId).length;

  const roleBadgeStyle: Record<string, string> = {
    Admin: "bg-violet-100 text-violet-700",
    Gestor: "bg-blue-100 text-blue-700",
    Colaborador: "bg-slate-100 text-slate-600",
  };

  const initials = (name?: string) =>
    (name || "?")
      .split(" ")
      .filter(Boolean)
      .slice(0, 2)
      .map(p => p[0]?.toUpperCase())
      .join("");

  return (
    <div className="p-6 space-y-6 flex-1 overflow-y-auto flex flex-col">
        {/* Top Metrics */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 shrink-0">
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-slate-400">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Na Triagem</p>
            <p className="text-2xl font-bold text-slate-900">{inTriagem}</p>
          </div>
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-blue-500">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Pendentes (Ativas)</p>
            <p className="text-2xl font-bold text-blue-600">{inProgress}</p>
          </div>
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-red-500">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Atrasadas</p>
            <p className="text-2xl font-bold text-red-600">{delayed}</p>
          </div>
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-amber-500">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Vencem Hoje</p>
            <p className="text-2xl font-bold text-amber-600">{dueToday}</p>
          </div>
        </div>

        {/* Carga de Trabalho por Pessoa */}
        {isGestorOrAdmin && (
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm shrink-0">
            <div className="flex items-center justify-between px-5 pt-5 pb-1">
              <div>
                <h4 className="text-sm font-bold text-slate-800">Carga de Trabalho da Equipe</h4>
                <p className="text-xs text-slate-400 mt-0.5">Demandas ativas por responsável, incluindo administradores</p>
              </div>
              {unassignedCount > 0 && (
                <span className="text-[11px] font-semibold px-2.5 py-1 rounded-full bg-slate-100 text-slate-500">
                  {unassignedCount} sem responsável
                </span>
              )}
            </div>
            <div className="px-5 pb-5 pt-3 divide-y divide-slate-100">
              {workload.map(({ user, active, delayed }) => (
                <div key={user.id} className="flex items-center gap-4 py-3 first:pt-0 last:pb-0">
                  <div className="w-9 h-9 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 text-white text-xs font-bold flex items-center justify-center shrink-0">
                    {initials(user.name)}
                  </div>
                  <div className="w-40 shrink-0 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">{user.name}</p>
                    <span className={`inline-block text-[10px] font-bold px-1.5 py-0.5 rounded uppercase mt-0.5 ${roleBadgeStyle[user.role] || "bg-slate-100 text-slate-600"}`}>
                      {user.role}
                    </span>
                  </div>
                  <div className="flex-1 flex items-center gap-3">
                    <div className="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
                      <div
                        className={`h-full rounded-full ${active === 0 ? "bg-slate-200" : delayed > 0 ? "bg-red-400" : "bg-blue-500"}`}
                        style={{ width: `${(active / maxActive) * 100}%` }}
                      />
                    </div>
                    <span className="text-sm font-bold text-slate-800 w-6 text-right">{active}</span>
                  </div>
                  {delayed > 0 && (
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-600 shrink-0 flex items-center gap-1">
                      <AlertCircle className="w-3 h-3" /> {delayed} atrasada{delayed > 1 ? "s" : ""}
                    </span>
                  )}
                </div>
              ))}
              {workload.length === 0 && (
                <p className="text-sm text-slate-400 text-center py-4">Ninguém com demandas ativas no momento.</p>
              )}
            </div>
          </div>
        )}

        {/* Kanban Snapshot */}
        <div className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-6 min-h-[300px]">
          {/* Column: A Fazer */}
          <div className="flex flex-col h-full">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-slate-600 uppercase flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-slate-400"></span> Triagem ({displayTasks.filter(t => t.status === "Triagem").length})
              </h3>
            </div>
            <div className="flex-1 bg-slate-100/50 rounded-xl p-3 space-y-3">
              {displayTasks.filter(t => t.status === "Triagem").slice(0, 3).map(task => {
                 return (
                  <div key={task.id} className="bg-white p-3 rounded-lg border border-slate-200 shadow-sm">
                    <div className="flex justify-between items-start mb-2">
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-orange-100 text-orange-700 uppercase">{task.priority}</span>
                      <span className="text-[10px] text-slate-400">#{task.id.slice(0,4)}</span>
                    </div>
                    <h4 className="text-sm font-bold text-slate-800 leading-tight mb-1">{task.title}</h4>
                  </div>
                 )
              })}
            </div>
          </div>

          {/* Column: Em Andamento */}
          <div className="flex flex-col h-full">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-slate-600 uppercase flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-blue-500"></span> Em Produção ({displayTasks.filter(t => t.status === "Em Produção").length})
              </h3>
            </div>
            <div className="flex-1 bg-slate-100/50 rounded-xl p-3 space-y-3">
              {displayTasks.filter(t => t.status === "Em Produção").slice(0, 3).map(task => {
                 return (
                  <div key={task.id} className="bg-white p-3 rounded-lg border border-slate-200 shadow-sm ring-2 ring-blue-500/10">
                    <div className="flex justify-between items-start mb-2">
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-red-100 text-red-700 uppercase">{task.priority}</span>
                      <span className="text-[10px] text-slate-400">#{task.id.slice(0,4)}</span>
                    </div>
                    <h4 className="text-sm font-bold text-slate-800 leading-tight mb-1">{task.title}</h4>
                  </div>
                 )
              })}
            </div>
          </div>

          {/* Column: Finalizado */}
          <div className="flex flex-col h-full">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-slate-600 uppercase flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-green-500"></span> Aprovado ({displayTasks.filter(t => t.status === "Aprovado").length})
              </h3>
            </div>
            <div className="flex-1 bg-slate-100/50 rounded-xl p-3 space-y-3">
              {displayTasks.filter(t => t.status === "Aprovado").slice(0, 3).map(task => (
                <div key={task.id} className="bg-white p-3 rounded-lg border border-slate-200 shadow-sm opacity-75">
                  <div className="flex justify-between items-start mb-2">
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-slate-100 text-slate-600 uppercase">{task.priority}</span>
                    <span className="text-[10px] text-slate-400">#{task.id.slice(0,4)}</span>
                  </div>
                  <h4 className="text-sm font-bold text-slate-800 leading-tight mb-1">{task.title}</h4>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Summary Charts (Simplified Row) */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 h-64 shrink-0">
          <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col h-full">
            <h4 className="text-xs font-bold text-slate-400 uppercase mb-4 tracking-wider">Categorias mais solicitadas</h4>
            <div className="flex-1 h-full w-full">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData}>
                  <XAxis dataKey="name" stroke="#94a3b8" fontSize={10} tickLine={false} axisLine={false} />
                  <Tooltip cursor={{fill: '#f1f5f9'}} contentStyle={{ borderRadius: '8px', border: '1px solid #e2e8f0', boxShadow: '0 1px 2px 0 rgb(0 0 0 / 0.05)' }} />
                  <Bar dataKey="total" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
          
          <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col h-full">
            <h4 className="text-xs font-bold text-slate-400 uppercase mb-2 tracking-wider">Performance (SLA)</h4>
            <div className="flex items-center justify-between h-full">
              <div className="relative w-24 h-24">
                 <svg viewBox="0 0 36 36" className="w-24 h-24">
                    <path className="stroke-current text-slate-100" strokeWidth="4" fill="none" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                    <path className={`stroke-current ${slaPercentage >= 90 ? 'text-green-500' : slaPercentage >= 70 ? 'text-amber-500' : 'text-red-500'}`} strokeWidth="4" strokeDasharray={`${slaPercentage}, 100`} strokeLinecap="round" fill="none" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                 </svg>
                 <div className="absolute inset-0 flex items-center justify-center font-bold text-xl text-slate-800">{slaPercentage}%</div>
              </div>
              <div className="flex-1 ml-6 space-y-2">
                 <div className="flex justify-between items-center">
                    <span className="text-[11px] font-medium text-slate-500">Tempo Médio Entrega</span>
                    <span className="text-sm font-bold text-slate-800">{avgDeliveryTime > 0 ? `${avgDeliveryTime.toFixed(1)} dias` : '-'}</span>
                 </div>
                 <div className="flex justify-between items-center">
                    <span className="text-[11px] font-medium text-slate-500">Eficiência Equipe</span>
                    <span className={`text-sm font-bold ${slaPercentage >= 90 ? 'text-green-600' : slaPercentage >= 70 ? 'text-amber-600' : 'text-red-600'}`}>{slaPercentage}%</span>
                 </div>
                 <div className="flex justify-between items-center border-t border-slate-100 pt-2">
                    <span className="text-[11px] font-medium text-slate-500">Gargalos Atuais</span>
                    <span className="text-sm font-bold text-red-500 uppercase text-[10px]">{currentBottleneck}</span>
                 </div>
              </div>
            </div>
          </div>
        </div>
      </div>
  );

}