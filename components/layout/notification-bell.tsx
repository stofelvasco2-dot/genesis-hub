"use client";

import { Bell, UserPlus, ArrowRightCircle, Info, CheckCheck, MessageSquare, CalendarClock } from "lucide-react";
import { Button } from "@/components/ui/button";
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
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="relative text-slate-500 hover:text-slate-700 shrink-0">
          <Bell className="w-5 h-5" />
          {unreadCount > 0 && (
            <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center">
              {unreadCount > 9 ? "9+" : unreadCount}
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80 p-0 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100">
          <p className="text-sm font-bold text-slate-800">Notificações</p>
          {unreadCount > 0 && (
            <button
              onClick={() => markAllNotificationsRead()}
              className="text-xs text-blue-600 hover:text-blue-700 font-medium flex items-center gap-1"
            >
              <CheckCheck className="w-3.5 h-3.5" /> Marcar todas como lidas
            </button>
          )}
        </div>
        <div className="max-h-96 overflow-y-auto divide-y divide-slate-50">
          {notifications.length === 0 && (
            <p className="text-sm text-slate-400 text-center py-10">Nenhuma notificação por aqui.</p>
          )}
          {notifications.map(n => (
            <button
              key={n.id}
              onClick={() => openNotification(n.id, n.read, n.taskId)}
              className={`w-full text-left px-4 py-3 flex gap-3 hover:bg-slate-50 transition-colors ${!n.read ? "bg-blue-50/50" : ""}`}
            >
              <div className="mt-0.5 shrink-0">{typeIcon[n.type] || typeIcon.other}</div>
              <div className="flex-1 min-w-0">
                <p className={`text-sm ${!n.read ? "font-semibold text-slate-800" : "text-slate-600"}`}>{n.title}</p>
                {n.message && <p className="text-xs text-slate-500 mt-0.5 line-clamp-2">{n.message}</p>}
                <p className="text-[11px] text-slate-400 mt-1">
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
