"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { Mail, Lock, Eye, EyeOff, ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";

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
          <img src="https://i.ibb.co/zp9RSKP/logo-genesis.png" alt="Genesis Hub" className="h-9 object-contain" />
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
            <img src="https://i.ibb.co/zp9RSKP/logo-genesis.png" alt="Genesis Hub" className="h-10 object-contain" />
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
                  className="w-full bg-white/5 border border-white/10 rounded-lg pl-10 pr-3 py-2.5 text-sm text-white placeholder:text-blue-300/30 outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
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
                  className="w-full bg-white/5 border border-white/10 rounded-lg pl-10 pr-10 py-2.5 text-sm text-white outline-none focus:border-blue-400/60 focus:bg-white/[0.07] transition-colors"
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
            <div className="flex-1 h-px bg-white/10" />
            <span className="text-[10px] uppercase tracking-widest text-blue-300/30">acesso restrito</span>
            <div className="flex-1 h-px bg-white/10" />
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