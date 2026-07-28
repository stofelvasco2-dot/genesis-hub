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
      // Se não houver sessão, significa que a confirmação de e-mail está ativada.
      // O usuário não está logado, então o upsert falhará por causa do RLS.
      if (!authData.session) {
        toast.success("Conta criada! Verifique seu e-mail para confirmar o login.");
        router.push('/login');
        return;
      }

      // Se a confirmação de e-mail estiver desativada (recomendado), a sessão existe e podemos fazer o upsert.
      // O trigger on_auth_user_created (banco de dados) já deve ter criado a linha em "users"
      // no momento do signUp acima; este upsert só garante nome/cargo/departamento corretos.
      const { error: dbError } = await supabase.from('users').upsert([{
        id: authData.user.id,
        name: inviteData.name,
        role: inviteData.role,
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
      <div className="flex flex-col items-center justify-center min-h-screen bg-blue-950 p-4 text-center">
        <h1 className="text-2xl font-bold text-white mb-2">Convite Inválido</h1>
        <p className="text-blue-200 mb-6">O link que você acessou não contém um convite válido.</p>
        <Button onClick={() => router.push("/login")} variant="outline" className="border-blue-700 text-blue-950 hover:bg-blue-100">Voltar para o Login</Button>
      </div>
    );
  }

  return (
    <div className="flex h-screen w-full items-center justify-center bg-blue-950 p-4">
      <div className="w-full max-w-md bg-blue-900 rounded-2xl shadow-xl p-8 border border-blue-800">
        <div className="flex flex-col items-center mb-8">
          <img src="https://i.ibb.co/zp9RSKP/logo-genesis.png" alt="Genesis Hub" className="h-12 object-contain mb-4" />
          <h1 className="text-2xl font-bold text-white text-center leading-tight">Olá, {inviteData.name}</h1>
          <p className="text-sm text-blue-200 text-center mt-2">
            Você foi convidado para participar do <strong>Genesis Hub</strong>. <br/>
            Sua função será <strong>{inviteData.role}</strong> no setor <strong>{inviteData.department}</strong>.
            {inviteData.type && <><br/>Tipo de acesso: <strong>{inviteData.type}</strong></>}
          </p>
          <p className="text-sm font-medium text-blue-100 text-center mt-4">
            Para aceitar o convite, crie sua conta com e-mail e senha abaixo.
          </p>
        </div>

        <form onSubmit={handleRegister} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email" className="text-white">Seu E-mail</Label>
            <Input 
              id="email" 
              type="email" 
              placeholder="seu@email.com" 
              value={email} 
              onChange={e => setEmail(e.target.value)}
              required
              className="bg-blue-950 border-blue-800 text-white placeholder:text-blue-400"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password" className="text-white">Crie uma Senha</Label>
            <Input 
              id="password" 
              type="password" 
              placeholder="Mínimo 6 caracteres"
              value={password} 
              onChange={e => setPassword(e.target.value)}
              required
              minLength={6}
              className="bg-blue-950 border-blue-800 text-white placeholder:text-blue-400"
            />
          </div>

          <Button type="submit" className="w-full bg-blue-600 hover:bg-blue-500 mt-2 text-white" disabled={loading}>
            {loading ? "Criando Conta..." : "Criar Conta e Acessar"}
          </Button>
        </form>
      </div>
    </div>
  );
}

export default function InvitePage() {
  return (
    <Suspense fallback={<div className="flex h-screen w-full items-center justify-center bg-blue-950"><div className="w-8 h-8 rounded-full border-4 border-blue-900 border-t-blue-500 animate-spin"></div></div>}>
      <InviteContent />
    </Suspense>
  );
} 