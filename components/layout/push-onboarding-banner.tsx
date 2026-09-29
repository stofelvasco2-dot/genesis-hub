"use client";

import { useEffect, useState } from "react";
import { X, Share, SquarePlus, BellRing } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { useStore } from "@/lib/store";
import { getPushState, subscribeToPush, isPushSupported } from "@/lib/push";
import { toast } from "sonner";

// iPhone/iPad: só reconhece Safari como "iOS" clássico via userAgent, mais
// o caso do iPad moderno que se disfarça de Mac (mesmo touch de um Mac de
// verdade não existe, então maxTouchPoints > 1 é o jeito de diferenciar).
function isIOS(): boolean {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent;
  const isClassicIOS = /iPad|iPhone|iPod/.test(ua);
  const isModernIPad = navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1;
  return isClassicIOS || isModernIPad;
}

// "Instalado na tela de início" — sem isso, o iOS nem expõe a API de push
// pro navegador, então o botão do sino simplesmente não aparece.
function isStandalone(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(display-mode: standalone)").matches || (window.navigator as any).standalone === true;
}

const DISMISS_KEY = "genesis-hub-push-banner-dismissed";

export function PushOnboardingBanner() {
  const { currentUser } = useStore();
  const [visible, setVisible] = useState(false);
  const [needsInstall, setNeedsInstall] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let dismissed = false;
    try {
      dismissed = window.localStorage.getItem(DISMISS_KEY) === "1";
    } catch {
      // Sem acesso ao localStorage (aba anônima etc.) — trata como "não dispensado".
    }
    if (dismissed) return;

    if (isIOS() && !isStandalone()) {
      // iPhone/iPad que ainda não instalou o app na tela de início: o
      // navegador nem tem a API de push disponível nesse caso — precisa
      // instalar primeiro, então mostra o passo a passo em vez do sino.
      setNeedsInstall(true);
      setVisible(true);
      return;
    }

    if (!isPushSupported()) return;

    getPushState().then((state) => {
      if (state === "unsubscribed") setVisible(true);
    });
    // eslint-disable-next-line react-hooks/set-state-in-effect
  }, []);

  const dismiss = () => {
    setVisible(false);
    try {
      window.localStorage.setItem(DISMISS_KEY, "1");
    } catch {}
  };

  const handleActivate = async () => {
    if (!currentUser) return;
    setLoading(true);
    const ok = await subscribeToPush(currentUser.id);
    setLoading(false);
    if (ok) {
      toast.success("Notificações push ativadas!");
      dismiss();
    } else {
      toast.error("Não foi possível ativar. Tente pelo sino no topo da tela.");
    }
  };

  if (!visible) return null;

  // No iPhone/iPad sem instalar ainda, o passo a passo continua como faixa
  // (não dá pra "ativar" nada por popup nesse caso — precisa instalar
  // primeiro, é só orientação).
  if (needsInstall) {
    return (
      <div className="bg-blue-50 dark:bg-blue-500/10 border-b border-blue-200 dark:border-blue-500/20 px-4 py-3 flex items-start gap-3 text-sm shrink-0">
        <BellRing className="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0 mt-0.5" />
        <div className="flex-1 min-w-0">
          <p className="font-semibold text-blue-900 dark:text-blue-200">Ative as notificações no seu iPhone/iPad</p>
          <ol className="text-blue-800 dark:text-blue-300/80 mt-1.5 space-y-1 list-decimal list-inside">
            <li>Toque no botão <Share className="w-3.5 h-3.5 inline mx-0.5 -mt-0.5" /> Compartilhar, na barra do Safari</li>
            <li>Escolha <SquarePlus className="w-3.5 h-3.5 inline mx-0.5 -mt-0.5" /> "Adicionar à Tela de Início"</li>
            <li>Abra o Genesis Hub pelo ícone que aparecer na tela de início (não pelo Safari)</li>
            <li>Toque no sino no topo do app pra ativar</li>
          </ol>
        </div>
        <button onClick={dismiss} className="text-blue-400 hover:text-blue-600 dark:hover:text-blue-200 shrink-0" title="Dispensar">
          <X className="w-4 h-4" />
        </button>
      </div>
    );
  }

  // Nos outros casos (Android, desktop, ou iPhone já instalado): popup
  // central, sem precisar de nenhum botão fixo no cabeçalho — a pessoa só
  // vê isso uma vez, decide, e pronto.
  return (
    <Dialog open onOpenChange={(o) => !o && dismiss()}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <div className="w-11 h-11 rounded-full bg-blue-100 dark:bg-blue-500/15 flex items-center justify-center mb-2">
            <BellRing className="w-5 h-5 text-blue-600 dark:text-blue-400" />
          </div>
          <DialogTitle>Ativar notificações?</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-slate-500 dark:text-slate-400 -mt-2">
          Você recebe um aviso na hora, mesmo com o app fechado, quando alguém te atribuir uma demanda, mencionar você ou comentar numa demanda sua.
        </p>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={dismiss}>Agora não</Button>
          <Button onClick={handleActivate} disabled={loading} className="bg-blue-600 hover:bg-blue-700">
            {loading ? "Ativando..." : "Sim, ativar"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
