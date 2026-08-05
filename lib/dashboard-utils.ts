import {
  parseISO,
  isPast,
  isToday,
  isWithinInterval,
  startOfDay,
  addDays,
  subDays,
  subWeeks,
  startOfWeek,
  differenceInCalendarDays,
  format,
} from "date-fns";
import { ptBR } from "date-fns/locale";
import { Task } from "./types";

// Uma tarefa é considerada "atrasada" quando já passou do prazo e ainda não
// foi aprovada. "isToday" fica de fora de propósito: vence hoje é uma
// categoria separada, não atraso.
export const isTaskDelayed = (t: Task): boolean =>
  t.status !== "Aprovado" && !!t.dueDate && isPast(parseISO(t.dueDate)) && !isToday(parseISO(t.dueDate));

export const isTaskDueToday = (t: Task): boolean =>
  t.status !== "Aprovado" && !!t.dueDate && isToday(parseISO(t.dueDate));

// Vence nos próximos 7 dias, mas não é "atrasada" nem "vence hoje" (evita
// contar a mesma tarefa em mais de um balde).
export const isTaskDueThisWeek = (t: Task): boolean => {
  if (t.status === "Aprovado" || !t.dueDate) return false;
  if (isTaskDelayed(t) || isTaskDueToday(t)) return false;
  const due = parseISO(t.dueDate);
  const today = startOfDay(new Date());
  return isWithinInterval(due, { start: today, end: addDays(today, 7) });
};

// Há quanto tempo a tarefa não recebe nenhuma atualização (mudança de
// status, comentário etc.) — sinal de que travou, mesmo que o prazo
// formal ainda não tenha vencido.
export const daysSinceUpdate = (t: Task): number => {
  const ref = t.updatedAt || t.createdAt;
  if (!ref) return 0;
  return Math.max(0, differenceInCalendarDays(new Date(), parseISO(ref)));
};

export type SlaSummary = {
  completedCount: number;
  avgDeliveryDays: number;
  onTimePercentage: number;
};

// Calcula SLA (tempo médio de entrega e % de tarefas entregues no prazo)
// olhando só para as tarefas concluídas dentro da janela de dias pedida.
export function computeSla(tasks: Task[], periodDays: number): SlaSummary {
  const cutoff = subDays(new Date(), periodDays);
  const completed = tasks.filter(
    (t) => t.status === "Aprovado" && t.completedAt && parseISO(t.completedAt) >= cutoff
  );

  let avgDeliveryDays = 0;
  if (completed.length > 0) {
    const totalDays = completed.reduce((acc, t) => {
      const start = parseISO(t.createdAt);
      const end = parseISO(t.completedAt!);
      return acc + Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
    }, 0);
    avgDeliveryDays = totalDays / completed.length;
  }

  let onTimePercentage = 0;
  const withDueDate = completed.filter((t) => t.dueDate);
  if (withDueDate.length > 0) {
    const onTime = withDueDate.filter((t) => {
      const due = parseISO(t.dueDate);
      due.setHours(23, 59, 59, 999);
      return parseISO(t.completedAt!).getTime() <= due.getTime();
    }).length;
    onTimePercentage = Math.round((onTime / withDueDate.length) * 100);
  } else if (completed.length > 0) {
    onTimePercentage = 100;
  }

  return { completedCount: completed.length, avgDeliveryDays, onTimePercentage };
}

export type WeeklyTrendPoint = { key: string; label: string; entregues: number };

// Monta a série "entregas por semana" das últimas N semanas, pra dar uma
// visão de tendência (subindo, caindo, estável) em vez de só uma foto do
// momento.
export function buildWeeklyDeliveryTrend(tasks: Task[], weeks = 8): WeeklyTrendPoint[] {
  const now = new Date();
  const buckets: WeeklyTrendPoint[] = [];
  for (let i = weeks - 1; i >= 0; i--) {
    const weekStart = startOfWeek(subWeeks(now, i), { weekStartsOn: 1 });
    buckets.push({
      key: format(weekStart, "yyyy-MM-dd"),
      label: format(weekStart, "dd/MM", { locale: ptBR }),
      entregues: 0,
    });
  }

  tasks.forEach((t) => {
    if (t.status !== "Aprovado" || !t.completedAt) return;
    const weekStart = startOfWeek(parseISO(t.completedAt), { weekStartsOn: 1 });
    const key = format(weekStart, "yyyy-MM-dd");
    const bucket = buckets.find((b) => b.key === key);
    if (bucket) bucket.entregues += 1;
  });

  return buckets;
}

export const priorityColor: Record<string, string> = {
  Urgente: "bg-red-500",
  Alta: "bg-amber-500",
  Normal: "bg-blue-500",
  Baixa: "bg-slate-400",
};

export const priorityBadgeStyle: Record<string, string> = {
  Urgente: "bg-red-100 text-red-700",
  Alta: "bg-amber-100 text-amber-700",
  Normal: "bg-blue-100 text-blue-700",
  Baixa: "bg-slate-100 text-slate-600",
};

export const initialsFromName = (name?: string): string =>
  (name || "?")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join("");
