"use client";

import { AppLayout } from "@/components/layout/app-layout";
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

  return (
    <AppLayout>
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
    </AppLayout>
  );

}
