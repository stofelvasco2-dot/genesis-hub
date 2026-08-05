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
  Admin: "bg-violet-100 text-violet-700",
  Gestor: "bg-blue-100 text-blue-700",
  Colaborador: "bg-slate-100 text-slate-600",
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
        <KpiCard label="Ativas no total" value={activeTasks.length} border="border-l-slate-400" icon={<ListTodo className="w-4 h-4 text-slate-400" />} />
        <KpiCard label="Na Triagem" value={inTriagem.length} border="border-l-slate-400" icon={<Clock className="w-4 h-4 text-slate-400" />} />
        <KpiCard label="Aguardando Aprovação" value={awaitingApproval.length} border="border-l-purple-500" valueClass="text-purple-600" icon={<PauseCircle className="w-4 h-4 text-purple-400" />} />
        <KpiCard label="Urgentes Ativas" value={urgentActive.length} border="border-l-red-600" valueClass="text-red-700" icon={<Flame className="w-4 h-4 text-red-500" />} />
        <KpiCard label="Atrasadas" value={delayedTasks.length} border="border-l-red-500" valueClass="text-red-600" icon={<AlertCircle className="w-4 h-4 text-red-400" />} />
        <KpiCard label="Vencem Hoje" value={dueTodayTasks.length} border="border-l-amber-500" valueClass="text-amber-600" icon={<Clock className="w-4 h-4 text-amber-400" />} />
      </div>

      {/* Funil do Pipeline */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm shrink-0">
        <div className="px-5 pt-5 pb-1">
          <h4 className="text-sm font-bold text-slate-800">Funil do Pipeline</h4>
          <p className="text-xs text-slate-400 mt-0.5">Quantas demandas estão em cada etapa agora, em tempo real.</p>
        </div>
        <div className="px-5 pb-5 pt-3 space-y-2.5">
          {pipelineCounts.map(({ status, count }) => (
            <button
              key={status}
              onClick={() => router.push(`/kanban?status=${encodeURIComponent(status)}`)}
              className="w-full flex items-center gap-3 text-left group"
            >
              <span className="text-xs text-slate-600 w-40 shrink-0 truncate group-hover:text-slate-900">{status}</span>
              <div className="flex-1 h-3 rounded-full bg-slate-100 overflow-hidden">
                <div
                  className={`h-full rounded-full ${status === "Aprovado" ? "bg-emerald-500" : "bg-blue-500"} transition-all`}
                  style={{ width: `${(count / maxPipeline) * 100}%` }}
                />
              </div>
              <span className="text-sm font-bold text-slate-800 w-6 text-right shrink-0">{count}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Carga de Trabalho + Cards Parados */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 shrink-0">
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between px-5 pt-5 pb-1">
            <div>
              <h4 className="text-sm font-bold text-slate-800 flex items-center gap-2">
                <Users className="w-4 h-4 text-slate-400" /> Carga de Trabalho da Equipe
              </h4>
              <p className="text-xs text-slate-400 mt-0.5">Demandas ativas por responsável</p>
            </div>
            {unassignedCount > 0 && (
              <span className="text-[11px] font-semibold px-2.5 py-1 rounded-full bg-slate-100 text-slate-500 shrink-0">
                {unassignedCount} sem responsável
              </span>
            )}
          </div>
          <div className="px-5 pb-5 pt-3 divide-y divide-slate-100 max-h-80 overflow-y-auto">
            {workload.map(({ user, active, delayed }) => (
              <div key={user.id} className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 text-white text-[11px] font-bold flex items-center justify-center shrink-0">
                  {initialsFromName(user.name)}
                </div>
                <div className="w-32 shrink-0 min-w-0">
                  <p className="text-sm font-semibold text-slate-800 truncate">{user.name}</p>
                  <span className={`inline-block text-[10px] font-bold px-1.5 py-0.5 rounded uppercase mt-0.5 ${roleBadgeStyle[user.role] || "bg-slate-100 text-slate-600"}`}>
                    {user.role}
                  </span>
                </div>
                <div className="flex-1 flex items-center gap-2">
                  <div className="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
                    <div
                      className={`h-full rounded-full ${active === 0 ? "bg-slate-200" : delayed > 0 ? "bg-red-400" : "bg-blue-500"}`}
                      style={{ width: `${(active / maxActive) * 100}%` }}
                    />
                  </div>
                  <span className="text-sm font-bold text-slate-800 w-5 text-right shrink-0">{active}</span>
                </div>
                {delayed > 0 && (
                  <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-red-100 text-red-600 shrink-0">
                    {delayed}
                  </span>
                )}
              </div>
            ))}
            {workload.length === 0 && (
              <p className="text-sm text-slate-400 text-center py-4">Ninguém com demandas ativas no momento.</p>
            )}
          </div>
        </div>

        <div className="bg-white rounded-xl border border-slate-200 shadow-sm">
          <div className="px-5 pt-5 pb-1">
            <h4 className="text-sm font-bold text-slate-800 flex items-center gap-2">
              <PauseCircle className="w-4 h-4 text-orange-400" /> Cards Parados
            </h4>
            <p className="text-xs text-slate-400 mt-0.5">Sem nenhuma atualização há 3+ dias — mesmo sem estar atrasada no prazo.</p>
          </div>
          <div className="px-5 pb-5 pt-3 divide-y divide-slate-100 max-h-80 overflow-y-auto">
            {stuckTasks.map(({ task, stuckDays }) => (
              <button
                key={task.id}
                onClick={() => router.push(`/kanban?task=${task.id}`)}
                className="w-full flex items-center gap-3 py-3 first:pt-0 last:pb-0 text-left hover:bg-slate-50 -mx-2 px-2 rounded-lg transition-colors"
              >
                <span className="text-[10px] font-bold px-2 py-1 rounded-full bg-orange-100 text-orange-600 shrink-0 whitespace-nowrap">
                  {stuckDays}d parada
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-slate-800 truncate">{task.title}</p>
                  <p className="text-xs text-slate-400">{task.status}</p>
                </div>
                <ArrowRight className="w-4 h-4 text-slate-300 shrink-0" />
              </button>
            ))}
            {stuckTasks.length === 0 && (
              <p className="text-sm text-slate-400 text-center py-6 flex flex-col items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                Nenhum card parado no momento.
              </p>
            )}
          </div>
        </div>
      </div>

      {/* Demandas Atrasadas */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm shrink-0">
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <div>
            <h4 className="text-sm font-bold text-slate-800 flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-red-500" /> Demandas Atrasadas
            </h4>
            <p className="text-xs text-slate-400 mt-0.5">Prazo já vencido e ainda não aprovadas — ordenadas da mais urgente pra menos.</p>
          </div>
          {delayedTasks.length > 0 && (
            <span className="text-[11px] font-semibold px-2.5 py-1 rounded-full bg-red-100 text-red-600 shrink-0">
              {delayedTasks.length}
            </span>
          )}
        </div>
        <div className="px-5 pb-5 divide-y divide-slate-100">
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
                  className="w-full flex items-center gap-3 py-3 first:pt-0 last:pb-0 text-left hover:bg-slate-50 -mx-2 px-2 rounded-lg transition-colors"
                >
                  <span className="text-[10px] font-bold px-2 py-1 rounded-full bg-red-100 text-red-600 shrink-0 whitespace-nowrap">
                    {daysLate} dia{daysLate !== 1 ? "s" : ""}
                  </span>
                  <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded shrink-0 ${priorityBadgeStyle[task.priority] || "bg-slate-100 text-slate-600"}`}>
                    {task.priority}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">{task.title}</p>
                    <p className="text-xs text-slate-400">
                      {task.category} · venceu em {format(parseISO(task.dueDate), "dd/MM", { locale: ptBR })}
                      {assignee ? ` · ${assignee.name}` : " · sem responsável"}
                    </p>
                  </div>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-slate-100 text-slate-500 uppercase shrink-0">{task.status}</span>
                  <ArrowRight className="w-4 h-4 text-slate-300 shrink-0" />
                </button>
              );
            })}
          {delayedTasks.length === 0 && (
            <p className="text-sm text-slate-400 text-center py-6 flex flex-col items-center gap-2">
              <CheckCircle2 className="w-5 h-5 text-emerald-400" />
              Nenhuma demanda atrasada no momento.
            </p>
          )}
        </div>
      </div>

      {/* Performance / SLA + Tendência de Entregas */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 shrink-0">
        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col">
          <div className="flex items-center justify-between mb-4">
            <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider">Performance (SLA)</h4>
            <div className="flex items-center gap-1 bg-slate-100 rounded-lg p-0.5">
              {SLA_PERIODS.map((p) => (
                <button
                  key={p.days}
                  onClick={() => setSlaPeriod(p.days)}
                  className={`text-[11px] font-semibold px-2 py-1 rounded-md transition-colors ${
                    slaPeriod === p.days ? "bg-white text-slate-800 shadow-sm" : "text-slate-500 hover:text-slate-700"
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
                <path className="stroke-current text-slate-100" strokeWidth="4" fill="none" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                <path
                  className={`stroke-current ${sla.onTimePercentage >= 90 ? "text-green-500" : sla.onTimePercentage >= 70 ? "text-amber-500" : "text-red-500"}`}
                  strokeWidth="4"
                  strokeDasharray={`${sla.onTimePercentage}, 100`}
                  strokeLinecap="round"
                  fill="none"
                  d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center font-bold text-xl text-slate-800">{sla.onTimePercentage}%</div>
            </div>
            <div className="flex-1 ml-6 space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-[11px] font-medium text-slate-500">Entregues no período</span>
                <span className="text-sm font-bold text-slate-800">{sla.completedCount}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-[11px] font-medium text-slate-500">Tempo Médio Entrega</span>
                <span className="text-sm font-bold text-slate-800">{sla.avgDeliveryDays > 0 ? `${sla.avgDeliveryDays.toFixed(1)} dias` : "-"}</span>
              </div>
              <div className="flex justify-between items-center border-t border-slate-100 pt-2">
                <span className="text-[11px] font-medium text-slate-500">No prazo</span>
                <span className={`text-sm font-bold ${sla.onTimePercentage >= 90 ? "text-green-600" : sla.onTimePercentage >= 70 ? "text-amber-600" : "text-red-600"}`}>
                  {sla.onTimePercentage}%
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col">
          <h4 className="text-xs font-bold text-slate-400 uppercase mb-2 tracking-wider">Tendência de Entregas (8 semanas)</h4>
          <div className="flex-1 min-h-[160px]">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={trend} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="label" tick={{ fontSize: 11, fill: "#94a3b8" }} axisLine={false} tickLine={false} />
                <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: "#94a3b8" }} axisLine={false} tickLine={false} width={28} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8, border: "1px solid #e2e8f0" }}
                  labelFormatter={(label) => `Semana de ${label}`}
                  formatter={(value: number) => [`${value}`, "Entregues"]}
                />
                <Line type="monotone" dataKey="entregues" stroke="#3b82f6" strokeWidth={2} dot={{ r: 3 }} activeDot={{ r: 5 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Prioridade + Departamentos */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 shrink-0">
        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col">
          <h4 className="text-xs font-bold text-slate-400 uppercase mb-4 tracking-wider">Prioridade das Demandas Ativas</h4>
          <div className="space-y-3">
            {priorityCounts.length === 0 && <p className="text-sm text-slate-400">Nenhuma demanda ativa.</p>}
            {priorityCounts.map((p) => (
              <div key={p.name} className="flex items-center gap-3">
                <span className="text-xs text-slate-600 w-16 shrink-0">{p.name}</span>
                <div className="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
                  <div className={`h-full rounded-full ${priorityColor[p.name] || "bg-blue-500"}`} style={{ width: `${(p.total / maxPriority) * 100}%` }} />
                </div>
                <span className="text-xs font-bold text-slate-700 w-5 text-right shrink-0">{p.total}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col">
          <h4 className="text-xs font-bold text-slate-400 uppercase mb-4 tracking-wider">Departamentos que Mais Solicitam</h4>
          <div className="space-y-3 max-h-56 overflow-y-auto pr-1">
            {departmentCounts.length === 0 && <p className="text-sm text-slate-400">Nenhuma demanda ainda.</p>}
            {departmentCounts.map((d) => (
              <div key={d.name} className="flex items-center gap-3">
                <span className="text-xs text-slate-600 w-32 shrink-0 truncate" title={d.name}>{d.name}</span>
                <div className="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
                  <div className="h-full rounded-full bg-indigo-500" style={{ width: `${(d.total / maxDepartment) * 100}%` }} />
                </div>
                <span className="text-xs font-bold text-slate-700 w-5 text-right shrink-0">{d.total}</span>
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
  valueClass = "text-slate-900",
  icon,
}: {
  label: string;
  value: number;
  border: string;
  valueClass?: string;
  icon?: ReactNode;
}) {
  return (
    <div className={`bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 ${border}`}>
      <div className="flex items-center justify-between mb-1">
        <p className="text-[11px] font-semibold text-slate-500 uppercase">{label}</p>
        {icon}
      </div>
      <p className={`text-2xl font-bold ${valueClass}`}>{value}</p>
    </div>
  );
}
