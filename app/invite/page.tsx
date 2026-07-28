"use client";
import { useState, useEffect, Suspense } from "react";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { useRouter, useSearchParams } from "next/navigation";
import { Mail, Lock, Eye, EyeOff, ArrowRight, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";

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
          tipo_usuario: inviteData.role,
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
        tipo_usuario: inviteData.role,
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

      <div className="w-full max-w-md bg-white/[0.04] backdrop-blur-sm rounded-2xl shadow-2xl p-8 border border-white/10 relative z-10">
        <div className="flex flex-col items-center mb-8">
          <img src="https://i.ibb.co/zp9RSKP/logo-genesis.png" alt="Genesis Hub" className="h-11 object-contain mb-5" />
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
                className="w-full bg-white/5 border border-white/10 rounded-lg pl-10 pr-3 py-2.5 text-sm text-white placeholder:text-blue-300/30 outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
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
                className="w-full bg-white/5 border border-white/10 rounded-lg pl-10 pr-10 py-2.5 text-sm text-white placeholder:text-blue-300/30 outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
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