"use client";
import { useState, useEffect } from "react";
import { supabase } from "@/lib/supabase";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Trash2, Plus, Link as LinkIcon, Copy, Check, Pencil, Users as UsersIcon } from "lucide-react";
import { useStore } from "@/lib/store";
import { User } from "@/lib/types";

export default function SettingsPage() {
  const { roles, users, refreshTasks, stageOwners, addStageOwner, removeStageOwner } = useStore();
  const [departments, setDepartments] = useState<string[]>([]);
  const [statuses, setStatuses] = useState<string[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [priorities, setPriorities] = useState<string[]>([]);

  const [newDept, setNewDept] = useState("");
  const [newStatus, setNewStatus] = useState("");
  const [newCategory, setNewCategory] = useState("");
  const [newPriority, setNewPriority] = useState("");

  // Donos de etapa
  const [ownerStatus, setOwnerStatus] = useState("");
  const [ownerUserId, setOwnerUserId] = useState("");
  const [savingOwner, setSavingOwner] = useState(false);

  // Invite state
  const [inviteName, setInviteName] = useState("");
  const [inviteRole, setInviteRole] = useState("");
  const [inviteType, setInviteType] = useState("");
  const [inviteDept, setInviteDept] = useState("");
  const [generatedLink, setGeneratedLink] = useState("");
  const [copied, setCopied] = useState(false);

  // Edição de colaborador
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [editName, setEditName] = useState("");
  const [editRole, setEditRole] = useState(""); // Função (Cargo) -> coluna tipo_usuario
  const [editType, setEditType] = useState(""); // Tipo de Usuário -> coluna role
  const [editDept, setEditDept] = useState("");
  const [savingEdit, setSavingEdit] = useState(false);

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

  const handleAddStageOwner = async () => {
    if (!ownerStatus || !ownerUserId) {
      toast.error("Escolha a etapa e o responsável.");
      return;
    }
    const alreadyExists = stageOwners.some(s => s.status === ownerStatus && s.userId === ownerUserId);
    if (alreadyExists) {
      toast.error("Essa pessoa já é responsável por essa etapa.");
      return;
    }
    setSavingOwner(true);
    await addStageOwner(ownerStatus, ownerUserId);
    setSavingOwner(false);
    setOwnerUserId("");
  };

  const openEditUser = (user: User) => {
    setEditingUser(user);
    setEditName(user.name || "");
    setEditRole(user.tipo_usuario || "");
    setEditType(user.role || "");
    setEditDept((user.department as string) || "");
  };

  const saveEditUser = async () => {
    if (!supabase || !editingUser) return;
    if (!editName.trim() || !editType) {
      toast.error("Nome e Tipo de Usuário são obrigatórios.");
      return;
    }
    setSavingEdit(true);
    const { error } = await supabase
      .from("users")
      .update({
        name: editName.trim(),
        tipo_usuario: editRole.trim() || null,
        role: editType,
        department: editDept || null,
      })
      .eq("id", editingUser.id);
    setSavingEdit(false);

    if (error) {
      toast.error("Erro ao salvar: " + error.message);
      return;
    }
    toast.success("Colaborador atualizado com sucesso!");
    setEditingUser(null);
    await refreshTasks();
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
    <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
      <h3 className="text-sm font-bold text-slate-800 dark:text-slate-100 mb-4 uppercase">{title}</h3>
      <div className="flex gap-2 mb-4">
        <Input value={newValue} onChange={e => setNewValue(e.target.value)} placeholder={`Novo ${title.toLowerCase()}`} className="h-9" />
        <Button onClick={() => handleAdd(table, newValue, setNewValue)} size="sm" className="bg-blue-600 hover:bg-blue-700 h-9 shrink-0"><Plus className="w-4 h-4 mr-1" /> Adicionar</Button>
      </div>
      <div className="space-y-2 max-h-48 overflow-y-auto">
        {items.map(item => (
          <div key={item} className="flex items-center justify-between p-2 rounded bg-slate-50 dark:bg-slate-950 border border-slate-100 dark:border-slate-800">
            <span className="text-sm font-medium text-slate-700 dark:text-slate-200">{item}</span>
            <Button variant="ghost" size="icon" onClick={() => handleDelete(table, item)} className="h-7 w-7 text-red-500 dark:text-red-400 hover:text-red-700 hover:bg-red-50">
              <Trash2 className="w-4 h-4" />
            </Button>
          </div>
        ))}
        {items.length === 0 && <p className="text-xs text-slate-400 dark:text-slate-500 italic">Nenhum item cadastrado.</p>}
      </div>
    </div>
  );

  return (
    <>
      <div className="p-4 sm:p-8 max-w-6xl mx-auto space-y-8">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white">Configurações</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400">Cadastre colaboradores e gerencie os menus do sistema.</p>
        </div>

        {/* Cadastro de Colaborador */}
        <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm space-y-6">
          <div>
            <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100">Cadastrar Colaborador</h2>
            <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">Preencha os dados para gerar um link de convite exclusivo.</p>
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
                  {roles.map(r => (
                    <SelectItem key={r} value={r}>{r}</SelectItem>
                  ))}
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
            <div className="mt-4 p-4 bg-blue-50 dark:bg-blue-500/10 border border-blue-100 rounded-lg flex flex-col gap-3 animate-in fade-in slide-in-from-top-4 duration-300">
              <p className="text-sm font-medium text-blue-900">
                Link gerado! Envie este link para o colaborador.
              </p>
              <div className="flex gap-2">
                <Input value={generatedLink} readOnly className="bg-white dark:bg-slate-900 border-blue-200 focus-visible:ring-blue-500" />
                <Button onClick={copyLink} variant="outline" className="bg-white dark:bg-slate-900 border-blue-200 hover:bg-blue-50 text-blue-700 dark:text-blue-400 shrink-0">
                  {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                </Button>
              </div>
            </div>
          )}
        </div>

        {/* Colaboradores Cadastrados */}
        <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <UsersIcon className="w-4 h-4 text-slate-500 dark:text-slate-400" />
            <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100">Colaboradores Cadastrados</h2>
          </div>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">Edite nome, função, tipo de usuário e setor de quem já tem conta no sistema.</p>

          <div className="space-y-2">
            {users.map(user => (
              <div key={user.id} className="flex flex-wrap items-center gap-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-950 border border-slate-100 dark:border-slate-800">
                <div className="flex-1 min-w-[140px]">
                  <p className="text-sm font-semibold text-slate-800 dark:text-slate-100">{user.name}</p>
                  <p className="text-xs text-slate-400 dark:text-slate-500">{user.email}</p>
                </div>
                <span className="text-xs text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 px-2 py-1 rounded min-w-[100px] text-center">
                  {user.tipo_usuario || "Sem função"}
                </span>
                <span className={`text-[10px] font-bold px-2 py-1 rounded uppercase ${
                  user.role === "Admin" ? "bg-violet-100 dark:bg-violet-500/15 text-violet-700" :
                  user.role === "Gestor" ? "bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400" :
                  "bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
                }`}>
                  {user.role}
                </span>
                <span className="text-xs text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 px-2 py-1 rounded min-w-[100px] text-center">
                  {(user.department as string) || "Sem setor"}
                </span>
                <Button variant="ghost" size="icon" onClick={() => openEditUser(user)} className="h-8 w-8 text-slate-500 dark:text-slate-400 hover:text-blue-600 hover:bg-blue-50 shrink-0">
                  <Pencil className="w-4 h-4" />
                </Button>
              </div>
            ))}
            {users.length === 0 && <p className="text-sm text-slate-400 dark:text-slate-500 italic">Nenhum colaborador cadastrado ainda.</p>}
          </div>
        </div>

        {/* Donos de Etapa */}
        <div className="bg-white dark:bg-slate-900 p-6 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm">
          <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-1">Donos de Etapa</h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">
            Escolha quem é avisado (no sino e por e-mail) toda vez que uma demanda chega numa etapa específica do Kanban — independente de quem é o responsável pela tarefa.
          </p>

          <div className="flex flex-wrap items-end gap-3 mb-5">
            <div className="flex-1 min-w-[160px] space-y-1.5">
              <Label className="text-xs">Etapa</Label>
              <Select value={ownerStatus} onValueChange={(value) => setOwnerStatus(value ?? "")}>
                <SelectTrigger><SelectValue placeholder="Selecione a etapa" /></SelectTrigger>
                <SelectContent>
                  {statuses.map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="flex-1 min-w-[160px] space-y-1.5">
              <Label className="text-xs">Responsável</Label>
              <Select value={ownerUserId} onValueChange={(value) => setOwnerUserId(value ?? "")}>
                <SelectTrigger><SelectValue>{ownerUserId ? users.find(u => u.id === ownerUserId)?.name : "Selecione a pessoa"}</SelectValue></SelectTrigger>
                <SelectContent>
                  {users.map(u => <SelectItem key={u.id} value={u.id}>{u.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <Button onClick={handleAddStageOwner} disabled={savingOwner} className="bg-blue-600 hover:bg-blue-700">
              <Plus className="w-4 h-4 mr-1" /> Adicionar
            </Button>
          </div>

          <div className="space-y-3">
            {statuses.filter(s => stageOwners.some(so => so.status === s)).map(status => (
              <div key={status} className="flex flex-wrap items-center gap-2 p-3 rounded-lg bg-slate-50 dark:bg-slate-950 border border-slate-100 dark:border-slate-800">
                <span className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase w-40 shrink-0">{status}</span>
                <div className="flex flex-wrap gap-2">
                  {stageOwners.filter(so => so.status === status).map(so => {
                    const owner = users.find(u => u.id === so.userId);
                    return (
                      <span key={so.id} className="inline-flex items-center gap-1.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-xs font-medium text-slate-700 dark:text-slate-200 px-2.5 py-1 rounded-full">
                        {owner?.name || "Usuário removido"}
                        <button onClick={() => removeStageOwner(so.id)} className="text-slate-400 dark:text-slate-500 hover:text-red-500">
                          <Trash2 className="w-3 h-3" />
                        </button>
                      </span>
                    );
                  })}
                </div>
              </div>
            ))}
            {stageOwners.length === 0 && (
              <p className="text-sm text-slate-400 dark:text-slate-500 italic">Nenhuma etapa com dono configurado ainda — ninguém recebe notificação automática por etapa.</p>
            )}
          </div>
        </div>

        {/* Opções do Sistema */}
        <div>
          <h2 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-1">Menus do Sistema</h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">Adicione ou remova opções disponíveis ao abrir uma nova demanda.</p>
          
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
            {renderSection("Setor Solicitante", departments, newDept, setNewDept, "departments")}
            {renderSection("Categoria", categories, newCategory, setNewCategory, "categories")}
            {renderSection("Prioridade", priorities, newPriority, setNewPriority, "priorities")}
          </div>
        </div>
      </div>

      {/* Modal de edição de colaborador */}
      <Dialog open={!!editingUser} onOpenChange={(open) => !open && setEditingUser(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Editar Colaborador</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 pt-2">
            <div className="space-y-2">
              <Label htmlFor="editName" className="text-xs">Nome</Label>
              <Input id="editName" value={editName} onChange={e => setEditName(e.target.value)} placeholder="Ex: Gustavo" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="editRole" className="text-xs">Função (Cargo)</Label>
              <Input id="editRole" value={editRole} onChange={e => setEditRole(e.target.value)} placeholder="Ex: Designer" />
            </div>
            <div className="space-y-2">
              <Label className="text-xs">Tipo de Usuário</Label>
              <Select value={editType} onValueChange={(val) => setEditType(val || "")}>
                <SelectTrigger>
                  <SelectValue placeholder="Selecione" />
                </SelectTrigger>
                <SelectContent>
                  {roles.map(r => (
                    <SelectItem key={r} value={r}>{r}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label className="text-xs">Setor</Label>
              <Select value={editDept} onValueChange={(val) => setEditDept(val || "")}>
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
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" onClick={() => setEditingUser(null)}>Cancelar</Button>
              <Button onClick={saveEditUser} disabled={savingEdit} className="bg-blue-600 hover:bg-blue-700">
                {savingEdit ? "Salvando..." : "Salvar alterações"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
