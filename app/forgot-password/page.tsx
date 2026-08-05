"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { LOGO_URL } from "@/lib/branding";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase) {
      toast.error("Supabase não configurado.");
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    });
    if (error) {
      toast.error("Erro ao enviar e-mail: " + error.message);
    } else {
      toast.success("E-mail de recuperação enviado com sucesso! Verifique sua caixa de entrada.");
      router.push("/login");
    }
    setLoading(false);
  };

  return (
    <div className="flex h-screen w-full items-center justify-center bg-slate-50 dark:bg-slate-950">
      <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-xl p-8 border border-slate-100 dark:border-slate-800">
        <div className="flex flex-col items-center mb-8">
          <img src={LOGO_URL} alt="Genesis Hub" className="h-12 object-contain mb-4" />
          <h1 className="text-2xl font-bold text-slate-800 dark:text-slate-100">Recuperar Senha</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 text-center">Informe seu e-mail para receber um link de recuperação.</p>
        </div>
        <form onSubmit={handleReset} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">E-mail</Label>
            <Input 
              id="email" 
              type="email" 
              placeholder="seu@email.com" 
              value={email} 
              onChange={e => setEmail(e.target.value)}
              required
            />
          </div>
          <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700" disabled={loading}>
            {loading ? "Enviando..." : "Enviar Link"}
          </Button>
          <div className="text-center mt-4">
            <a href="/login" className="text-sm text-blue-600 dark:text-blue-400 hover:underline">Voltar para o Login</a>
          </div>
        </form>
      </div>
    </div>
  );
}
