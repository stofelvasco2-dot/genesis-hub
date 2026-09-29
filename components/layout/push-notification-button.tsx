"use client";

import { useEffect, useState } from "react";
import { Bell, BellOff, BellRing } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useStore } from "@/lib/store";
import { getPushState, subscribeToPush, unsubscribeFromPush, isPushSupported, type PushState } from "@/lib/push";
import { toast } from "sonner";

export function PushNotificationButton() {
  const { currentUser } = useStore();
  const [state, setState] = useState<PushState>("unsubscribed");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!isPushSupported()) {
      setState("unsupported");
      return;
    }
    getPushState().then(setState);
  }, []);

  if (state === "unsupported") return null;

  const handleClick = async () => {
    if (!currentUser) return;
    setLoading(true);

    if (state === "subscribed") {
      await unsubscribeFromPush();
      setState("unsubscribed");
      toast.success("Notificações push desativadas neste navegador.");
    } else if (state === "denied") {
      toast.error("Notificações bloqueadas para este site. Ative nas configurações do navegador (ícone de cadeado ao lado do endereço).");
    } else {
      const ok = await subscribeToPush(currentUser.id);
      if (ok) {
        setState("subscribed");
        toast.success("Notificações push ativadas! Você vai receber avisos mesmo com o app fechado.");
      } else {
        setState(await getPushState());
        toast.error("Não foi possível ativar as notificações push.");
      }
    }

    setLoading(false);
  };

  const icon =
    state === "subscribed" ? <BellRing className="w-5 h-5 text-emerald-500" /> :
    state === "denied" ? <BellOff className="w-5 h-5" /> :
    <Bell className="w-5 h-5" />;

  const title =
    state === "subscribed" ? "Notificações push ativas neste navegador (clique pra desativar)" :
    state === "denied" ? "Notificações bloqueadas — ative nas configurações do navegador" :
    "Ativar notificações push (avisa mesmo com o app fechado)";

  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={handleClick}
      disabled={loading}
      title={title}
      className="relative inline-flex items-center justify-center size-8 shrink-0 rounded-lg text-slate-500 hover:bg-muted hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition-colors"
    >
      {icon}
    </Button>
  );
}
