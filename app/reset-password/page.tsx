"use client";

import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { LOGO_URL } from "@/lib/branding";

export default function ResetPasswordPage() {
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  useEffect(() => {
    // Check if we have a session to reset the password
    supabase?.auth.onAuthStateChange(async (event, session) => {
      if (event == "PASSWORD_RECOVERY") {
        console.log("Password recovery event received");
      }
    });
  }, []);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase) {
      toast.error("Supabase não configurado.");
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.updateUser({ password });
    
    if (error) {
      toast.error("Erro ao atualizar senha: " + error.message);
    } else {
      toast.success("Senha atualizada com sucesso!");
      router.push("/");
    }
    setLoading(false);
  };

  return (
    <div className="flex h-screen w-full items-center justify-center bg-slate-50">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-8 border border-slate-100">
        <div className="flex flex-col items-center mb-8">
          <img src={LOGO_URL} alt="Genesis Hub" className="h-12 object-contain mb-4" />
          <h1 className="text-2xl font-bold text-slate-800">Nova Senha</h1>
          <p className="text-sm text-slate-500 text-center">Digite sua nova senha para acessar o sistema.</p>
        </div>
        <form onSubmit={handleUpdate} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="password">Nova Senha</Label>
            <Input 
              id="password" 
              type="password" 
              placeholder="Digite a nova senha" 
              value={password} 
              onChange={e => setPassword(e.target.value)}
              required
              minLength={6}
            />
          </div>
          <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700" disabled={loading}>
            {loading ? "Salvando..." : "Atualizar Senha"}
          </Button>
        </form>
      </div>
    </div>
  );
}
