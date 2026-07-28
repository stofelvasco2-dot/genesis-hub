"use client";
import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { Trash2, Plus, Link as LinkIcon, Copy, Check } from "lucide-react";
import { useStore } from "@/lib/store";

export default function SettingsPage() {
  const { roles } = useStore();
  const [departments, setDepartments] = useState<string[]>([]);
  const [statuses, setStatuses] = useState<string[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [priorities, setPriorities] = useState<string[]>([]);

  const [newDept, setNewDept] = useState("");
  const [newStatus, setNewStatus] = useState("");
  const [newCategory, setNewCategory] = useState("");
  const [newPriority, setNewPriority] = useState("");

  // Invite state
  const [inviteName, setInviteName] = useState("");
  const [inviteRole, setInviteRole] = useState("");
  const [inviteType, setInviteType] = useState("");
  const [inviteDept, setInviteDept] = useState("");
  const [generatedLink, setGeneratedLink] = useState("");
  const [copied, setCopied] = useState(false);

  const fetchData = async () => {
    if (!supabase) return;
    const [deptRes, statusRes, catRes, prioRes] = await Promise.all([
      supabase.from("departments").select("name"),
      supabase.from("statuses").select("name"),
      supabase.from("categories").select("name"),
      supabase.from("priorities").select("name"),
    ]);

    if (deptRes.data) setDepartments(deptRes.data.map(d => d.name));
    if (statusRes.data) setStatuses(statusRes.data.map(s => s.name));
    if (catRes.data) setCategories(catRes.data.map(c => c.name));
    if (prioRes.data) setPriorities(prioRes.data.map(p => p.name));
  };

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    fetchData();
  }, []);

  const handleAdd = async (table: string, value: string, setter: (val: string) => void) => {
    if (!value.trim() || !supabase) return;
    const { error } = await supabase.from(table).insert([{ name: value.trim() }]);
    if (error) {
      toast.error(`Erro ao adicionar: ${error.message}`);
    } else {
      toast.success("Adicionado com sucesso!");
      setter("");
      fetchData();
    }
  };

  const handleDelete = async (table: string, value: string) => {
    if (!supabase) return;
    const { error } = await supabase.from(table).delete().eq("name", value);
    if (error) {
      toast.error(`Erro ao remover: ${error.message}`);
    } else {
      toast.success("Removido com sucesso!");
      fetchData();
    }
  };

  const generateInviteLink = () => {
    if (!inviteName || !inviteRole || !inviteType || !inviteDept) {
      toast.error("Preencha todos os campos para gerar o link.");
      return;
    }

    const payload = JSON.stringify({
      name: inviteName,
      role: inviteRole,
      type: inviteType,
      department: inviteDept
    });
    
    // Create a base64 encoded token
    const token = btoa(unescape(encodeURIComponent(payload)));
    const link = `${window.location.origin}/invite?token=${token}`;
    
    setGeneratedLink(link);
    setCopied(false);
  };

  const copyLink = () => {
    if (generatedLink) {
      navigator.clipboard.writeText(generatedLink);
      setCopied(true);
      toast.success("Link copiado para a área de transferência!");
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const renderSection = (title: string, items: string[], newValue: string, setNewValue: (v: string) => void, table: string) => (
    <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
      <h3 className="text-sm font-bold text-slate-800 mb-4 uppercase">{title}</h3>
      <div className="flex gap-2 mb-4">
        <Input value={newValue} onChange={e => setNewValue(e.target.value)} placeholder={`Novo ${title.toLowerCase()}`} className="h-9" />
        <Button onClick={() => handleAdd(table, newValue, setNewValue)} size="sm" className="bg-blue-600 hover:bg-blue-700 h-9 shrink-0"><Plus className="w-4 h-4 mr-1" /> Adicionar</Button>
      </div>
      <div className="space-y-2 max-h-48 overflow-y-auto">
        {items.map(item => (
          <div key={item} className="flex items-center justify-between p-2 rounded bg-slate-50 border border-slate-100">
            <span className="text-sm font-medium text-slate-700">{item}</span>
            <Button variant="ghost" size="icon" onClick={() => handleDelete(table, item)} className="h-7 w-7 text-red-500 hover:text-red-700 hover:bg-red-50">
              <Trash2 className="w-4 h-4" />
            </Button>
          </div>
        ))}
        {items.length === 0 && <p className="text-xs text-slate-400 italic">Nenhum item cadastrado.</p>}
      </div>
    </div>
  );

  return (
      <div className="p-4 sm:p-8 max-w-6xl mx-auto space-y-8">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Configurações</h1>
          <p className="text-sm text-slate-500">Cadastre colaboradores e gerencie os menus do sistema.</p>
        </div>

        {/* Cadastro de Colaborador */}
        <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm space-y-6">
          <div>
            <h2 className="text-lg font-bold text-slate-800">Cadastrar Colaborador</h2>
            <p className="text-sm text-slate-500 mb-4">Preencha os dados para gerar um link de convite exclusivo.</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4 items-end">
            <div className="space-y-2">
              <Label htmlFor="inviteName" className="text-xs">Nome do Colaborador</Label>
              <Input 
                id="inviteName" 
                value={inviteName} 
                onChange={e => setInviteName(e.target.value)} 
                placeholder="Ex: Gustavo" 
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="inviteRole" className="text-xs">Função (Cargo)</Label>
              <Input 
                id="inviteRole" 
                value={inviteRole} 
                onChange={e => setInviteRole(e.target.value)} 
                placeholder="Ex: Designer" 
              />
            </div>

            <div className="space-y-2">
              <Label className="text-xs">Tipo de Usuário</Label>
              <Select value={inviteType} onValueChange={(val) => setInviteType(val || "")}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="Admin">Admin</SelectItem>
                  <SelectItem value="Colaborador">Colaborador</SelectItem>
                  <SelectItem value="Gestor">Gestor</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label className="text-xs">Setor</Label>
              <Select value={inviteDept} onValueChange={(val) => setInviteDept(val || "")}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione" />
                </SelectTrigger>
                <SelectContent>
                  {departments.map(d => (
                    <SelectItem key={d} value={d}>{d}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <Button onClick={generateInviteLink} className="w-full bg-slate-900 hover:bg-slate-800">
              <LinkIcon className="w-4 h-4 mr-2" />
              Gerar Link
            </Button>
          </div>

          {generatedLink && (
            <div className="mt-4 p-4 bg-blue-50 border border-blue-100 rounded-lg flex flex-col gap-3 animate-in fade-in slide-in-from-top-4 duration-300">
              <p className="text-sm font-medium text-blue-900">
                Link gerado! Envie este link para o colaborador.
              </p>
              <div className="flex gap-2">
                <Input value={generatedLink} readOnly className="bg-white border-blue-200 focus-visible:ring-blue-500" />
                <Button onClick={copyLink} variant="outline" className="bg-white border-blue-200 hover:bg-blue-50 text-blue-700 shrink-0">
                  {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                </Button>
              </div>
            </div>
          )}
        </div>

        {/* Opções do Sistema */}
        <div>
          <h2 className="text-lg font-bold text-slate-800 mb-1">Menus do Sistema</h2>
          <p className="text-sm text-slate-500 mb-4">Adicione ou remova opções disponíveis ao abrir uma nova demanda.</p>
          
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
            {renderSection("Setor Solicitante", departments, newDept, setNewDept, "departments")}
            {renderSection("Categoria", categories, newCategory, setNewCategory, "categories")}
            {renderSection("Prioridade", priorities, newPriority, setNewPriority, "priorities")}
          </div>
        </div>
      </div>
  );
}