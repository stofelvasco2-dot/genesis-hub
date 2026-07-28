"use client";
import { useState, useEffect, Suspense } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { useRouter, useSearchParams } from "next/navigation";

function InviteContent() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token");
  
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
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
          tipo_usuario: inviteData.type || 'Colaborador',
        }
      }
    });

    if (authError) {
      toast.error("Erro ao criar conta: " + authError.message);
      setLoading(false);
      return;
    }

    if (authData.user) {
      // Se não houver sessão, significa que a confirmação de e-mail está ativada.
      // O usuário não está logado, então o upsert falhará por causa do RLS.
      if (!authData.session) {
        toast.success("Conta criada! Verifique seu e-mail para confirmar o login.");
        router.push('/login');
        return;
      }

      // Se a confirmação de e-mail estiver desativada (recomendado), a sessão existe e podemos fazer o upsert
      const { error: dbError } = await supabase.from('perfis').upsert([{
        id: authData.user.id,
        nome: inviteData.name,
        cargo: inviteData.role,
        tipo_usuario: inviteData.type || 'Colaborador',
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
      <div className="flex flex-col items-center justify-center min-h-screen bg-slate-50 p-4 text-center">
        <h1 className="text-2xl font-bold text-slate-800 mb-2">Convite Inválido</h1>
        <p className="text-slate-500 mb-6">O link que você acessou não contém um convite válido.</p>
        <Button onClick={() => router.push("/login")} variant="outline">Voltar para o Login</Button>
      </div>
    );
  }

  return (
    <div className="flex h-screen w-full items-center justify-center bg-slate-50 p-4">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-8 border border-slate-100">
        <div className="flex flex-col items-center mb-8">
          <img src="https://i.ibb.co/zp9RSKP/logo-genesis.png" alt="Genesis Hub" className="h-12 object-contain mb-4" />
          <h1 className="text-2xl font-bold text-slate-800 text-center leading-tight">Olá, {inviteData.name}</h1>
          <p className="text-sm text-slate-500 text-center mt-2">
            Você foi convidado para participar do <strong>Genesis Hub</strong>. <br/>
            Sua função será <strong>{inviteData.role}</strong> no setor <strong>{inviteData.department}</strong>.
            {inviteData.type && <><br/>Tipo de acesso: <strong>{inviteData.type}</strong></>}
          </p>
          <p className="text-sm font-medium text-slate-700 text-center mt-4">
            Para aceitar o convite, crie sua conta com e-mail e senha abaixo.
          </p>
        </div>

        <form onSubmit={handleRegister} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">Seu E-mail</Label>
            <Input 
              id="email" 
              type="email" 
              placeholder="seu@email.com" 
              value={email} 
              onChange={e => setEmail(e.target.value)}
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">Crie uma Senha</Label>
            <Input 
              id="password" 
              type="password" 
              placeholder="Mínimo 6 caracteres"
              value={password} 
              onChange={e => setPassword(e.target.value)}
              required
              minLength={6}
            />
          </div>

          <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-700 mt-2" disabled={loading}>
            {loading ? "Criando Conta..." : "Criar Conta e Acessar"}
          </Button>
        </form>
      </div>
    </div>
  );
}

export default function InvitePage() {
  return (
    <Suspense fallback={<div className="flex h-screen w-full items-center justify-center bg-slate-50"><div className="w-8 h-8 rounded-full border-4 border-slate-200 border-t-blue-600 animate-spin"></div></div>}>
      <InviteContent />
    </Suspense>
  );
}
