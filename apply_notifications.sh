#!/bin/bash
set -e
echo "Atualizando arquivos do Genesis Hub..."

mkdir -p "lib"
cat > "lib/store.tsx" << 'GENESIS_HUB_EOF_9f3k2'
"use client";
import React, { createContext, useContext, useState, useEffect, useRef } from "react";
import { Task, User, Category, Priority, Status, Comment, TimelineEvent, Notification, StageOwner } from "./types";
import { supabase } from "./supabase";
import { useRouter, usePathname } from "next/navigation";
import { toast } from "sonner";

type StoreContextType = {
  users: User[];
  currentUser: User | null;
  tasks: Task[];
  departments: string[];
  categories: string[];
  priorities: string[];
  statuses: string[];
  roles: string[];
  notifications: Notification[];
  unreadCount: number;
  stageOwners: StageOwner[];
  isLoaded: boolean;
  addTask: (task: Omit<Task, "id" | "createdAt" | "comments" | "timeline" | "updatedAt">) => Promise<void>;
  updateTask: (id: string, updates: Partial<Task>, modifierId: string) => Promise<void>;
  addComment: (taskId: string, userId: string, text: string) => Promise<void>;
  moveTaskStatus: (taskId: string, newStatus: string, modifierId: string) => Promise<void>;
  refreshTasks: () => Promise<void>;
  signOut: () => Promise<void>;
  addOption: (type: 'departments' | 'categories' | 'priorities', name: string) => Promise<void>;
  removeOption: (type: 'departments' | 'categories' | 'priorities', name: string) => Promise<void>;
  markNotificationRead: (id: string) => Promise<void>;
  markAllNotificationsRead: () => Promise<void>;
  addStageOwner: (status: string, userId: string) => Promise<void>;
  removeStageOwner: (id: string) => Promise<void>;
};

const StoreContext = createContext<StoreContextType | undefined>(undefined);

async function resolveCurrentUser(session: any): Promise<User | null> {
  if (!supabase) return null;

  // Busca por ID (não por e-mail) — é o vínculo real e evita duplicidade/atraso do trigger.
  const { data: existingUser } = await supabase.from("users").select("*").eq("id", session.user.id).maybeSingle();
  if (existingUser) return existingUser;

  // Autocura: se por algum motivo o trigger do banco (on_auth_user_created) não
  // criou a linha ainda, criamos aqui mesmo, usando os metadados do cadastro/convite.
  const meta = session.user.user_metadata || {};
  const newUser = {
    id: session.user.id,
    email: session.user.email,
    name: meta.nome || meta.name || session.user.email?.split("@")[0] || "Usuário",
    role: meta.cargo || meta.role || "Colaborador",
    department: meta.department || null,
  };

  const { data: createdUser } = await supabase.from("users").insert([newUser]).select().single();
  return createdUser || null;
}

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [users, setUsers] = useState<User[]>([]);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [tasks, setTasks] = useState<Task[]>([]);
  
  const [departments, setDepartments] = useState<string[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [priorities, setPriorities] = useState<string[]>([]);
  const [statuses, setStatuses] = useState<string[]>([]);
  const [roles, setRoles] = useState<string[]>([]);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [stageOwners, setStageOwners] = useState<StageOwner[]>([]);
  
  const [isLoaded, setIsLoaded] = useState(false);
  const router = useRouter();
  const pathname = usePathname();

  // Refs pra sempre ler o valor mais atual dentro do efeito de auth sem
  // precisar recriar (e re-executar) o efeito a cada navegação.
  const pathnameRef = useRef(pathname);
  const routerRef = useRef(router);
  const currentUserIdRef = useRef<string | null>(null);
  const hasLoadedOnceRef = useRef(false);

  useEffect(() => {
    pathnameRef.current = pathname;
  }, [pathname]);
  useEffect(() => {
    routerRef.current = router;
  }, [router]);
  useEffect(() => {
    currentUserIdRef.current = currentUser?.id ?? null;
  }, [currentUser]);

  const fetchData = async () => {
    if (!supabase) return;
    // Só mostra o spinner de tela cheia na primeira carga. Recargas
    // posteriores (refreshTasks, reconexão etc.) acontecem em segundo plano,
    // sem substituir a tela inteira — é isso que fazia tudo "piscar".
    if (!hasLoadedOnceRef.current) setIsLoaded(false);
    
    const [usersRes, tasksRes, deptRes, catRes, prioRes, statRes, roleRes, notifRes, stageOwnerRes] = await Promise.all([
      supabase.from('users').select('*'),
      supabase.from('tasks').select('*, comments(*), timeline_events(*)'),
      supabase.from('departments').select('name'),
      supabase.from('categories').select('name'),
      supabase.from('priorities').select('name'),
      supabase.from('statuses').select('name'),
      supabase.from('roles').select('name'),
      supabase.from('notifications').select('*').order('created_at', { ascending: false }).limit(50),
      supabase.from('stage_owners').select('*'),
    ]);

    if (usersRes.data) setUsers(usersRes.data);
    if (deptRes.data) setDepartments(deptRes.data.map(d => d.name));
    if (catRes.data) setCategories(catRes.data.map(c => c.name));
    if (prioRes.data) setPriorities(prioRes.data.map(p => p.name));
    if (statRes.data) setStatuses(statRes.data.map(s => s.name));
    if (roleRes.data) setRoles(roleRes.data.map(r => r.name));
    if (notifRes.data) {
      setNotifications(notifRes.data.map((n: any) => ({
        id: n.id, userId: n.user_id, taskId: n.task_id, title: n.title,
        message: n.message, type: n.type, read: n.read, createdAt: n.created_at,
      })));
    }
    if (stageOwnerRes.data) {
      setStageOwners(stageOwnerRes.data.map((s: any) => ({ id: s.id, status: s.status, userId: s.user_id })));
    }

    if (tasksRes.data) {
      const formattedTasks: Task[] = tasksRes.data.map(t => ({
        ...t,
        requesterId: t.requester_id,
        requesterName: t.requester_name,
        assigneeId: t.assignee_id,
        dueDate: t.due_date,
        referenceLinks: t.reference_links,
        createdAt: t.created_at,
        updatedAt: t.updated_at,
        startedAt: t.started_at,
        distributedAt: t.distributed_at,
        completedAt: t.completed_at,
        externalConsultant: t.external_consultant,
        internalConsultant: t.internal_consultant,
        comments: (t.comments || []).map((c: any) => ({
          ...c, userId: c.user_id, createdAt: c.created_at
        })),
        timeline: (t.timeline_events || []).map((e: any) => ({
          ...e, userId: e.user_id, createdAt: e.created_at
        })).sort((a: any, b: any) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
      }));
      setTasks(formattedTasks);
    }
    
    setIsLoaded(true);
    hasLoadedOnceRef.current = true;
  };

  // Roda só uma vez, na montagem do app — não a cada troca de rota/aba.
  // É isso que fazia a tela (e a sidebar) piscar toda vez que você navegava
  // dentro do sistema: antes, esse efeito tinha [pathname, router] como
  // dependência, então recarregava tudo do zero a cada clique no menu.
  useEffect(() => {
    const initAuth = async () => {
      if (!supabase) {
        setIsLoaded(true);
        return;
      }
      
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session?.user) {
        const resolvedUser = await resolveCurrentUser(session);
        if (resolvedUser) {
          setCurrentUser(resolvedUser);
        } else {
          toast.error("Usuário não encontrado na base de dados do sistema.");
          await supabase!.auth.signOut();
        }
        fetchData();
      } else {
        setIsLoaded(true);
        const publicRoutes = ['/login', '/forgot-password', '/reset-password', '/invite'];
        if (!publicRoutes.includes(pathnameRef.current)) {
          routerRef.current.push('/login');
        }
      }

      const { data: authListener } = supabase.auth.onAuthStateChange(async (event, session) => {
        if (event === 'SIGNED_IN' && session?.user) {
          // O Supabase reemite SIGNED_IN sempre que a aba do navegador volta a
          // ficar em foco (checagem/renovação de sessão), não só num login de
          // verdade. Se já é o mesmo usuário carregado, ignora — evita
          // recarregar tudo e piscar a tela ao voltar de outra aba.
          if (currentUserIdRef.current === session.user.id) return;

          const resolvedUser = await resolveCurrentUser(session);
          if (resolvedUser) {
            setCurrentUser(resolvedUser);
          } else {
            toast.error("Usuário não encontrado na base de dados do sistema.");
            await supabase!.auth.signOut();
          }
          fetchData();
          if (pathnameRef.current === '/login') {
            routerRef.current.push('/');
          }
        } else if (event === 'SIGNED_OUT') {
          setCurrentUser(null);
          setTasks([]);
          hasLoadedOnceRef.current = false;
          routerRef.current.push('/login');
        }
      });

      return () => {
        authListener.subscription.unsubscribe();
      };
    };
    initAuth();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Se um usuário desloga e outro loga sem dar refresh na página (troca de
  // conta), garante o redirecionamento mesmo fora do fluxo normal de rota.
  useEffect(() => {
    if (!currentUser && isLoaded) {
      const publicRoutes = ['/login', '/forgot-password', '/reset-password', '/invite'];
      if (!publicRoutes.includes(pathname)) {
        router.push('/login');
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUser, isLoaded, pathname]);

  const refreshTasks = async () => {
    await fetchData();
  };

  // Função central de notificação: grava no sino (tabela `notifications`) e
  // dispara o e-mail em segundo plano. Usada tanto pra atribuição direta
  // quanto pra "dono de etapa". Nunca notifica a própria pessoa que fez a ação.
  const notifyUser = async (userId: string, title: string, message: string, taskId?: string, type: Notification['type'] = 'other') => {
    if (!supabase || !userId) return;

    const { data } = await supabase.from('notifications').insert([{
      user_id: userId, task_id: taskId || null, title, message, type,
    }]).select().single();

    if (data) {
      setNotifications(prev => [{
        id: data.id, userId: data.user_id, taskId: data.task_id, title: data.title,
        message: data.message, type: data.type, read: data.read, createdAt: data.created_at,
      }, ...prev]);
    }

    const recipient = users.find(u => u.id === userId);
    if (recipient?.email) {
      fetch('/api/notify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: recipient.email, title, message, taskId }),
      }).catch(() => {
        // Falha de e-mail nunca deve travar o fluxo do usuário no app.
      });
    }
  };

  const markNotificationRead = async (id: string) => {
    if (!supabase) return;
    setNotifications(prev => prev.map(n => (n.id === id ? { ...n, read: true } : n)));
    await supabase.from('notifications').update({ read: true }).eq('id', id);
  };

  const markAllNotificationsRead = async () => {
    if (!supabase || !currentUser) return;
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
    await supabase.from('notifications').update({ read: true }).eq('user_id', currentUser.id).eq('read', false);
  };

  const addStageOwner = async (status: string, userId: string) => {
    if (!supabase) return;
    const { error } = await supabase.from('stage_owners').insert([{ status, user_id: userId }]);
    if (error) {
      toast.error('Erro ao adicionar responsável: ' + error.message);
      return;
    }
    await refreshTasks();
  };

  const removeStageOwner = async (id: string) => {
    if (!supabase) return;
    const { error } = await supabase.from('stage_owners').delete().eq('id', id);
    if (error) {
      toast.error('Erro ao remover responsável: ' + error.message);
      return;
    }
    setStageOwners(prev => prev.filter(s => s.id !== id));
  };

  const addTask = async (taskData: any) => {
    if (!supabase) return;
    const { data, error } = await supabase.from('tasks').insert([{
      title: taskData.title,
      description: taskData.description,
      category: taskData.category,
      priority: taskData.priority,
      status: taskData.status,
      requester_id: taskData.requesterId,
      requester_name: taskData.requesterName,
      department: taskData.department,
      due_date: taskData.dueDate,
      reference_links: taskData.referenceLinks,
      notes: taskData.notes
    }]).select().single();

    if (error) {
      toast.error('Erro ao criar tarefa: ' + error.message);
      return;
    }

    await supabase.from('timeline_events').insert([{
      task_id: data.id,
      type: 'created',
      user_id: taskData.requesterId,
      description: 'Solicitação criada.'
    }]);

    // Busca só a tarefa recém-criada (com comments/timeline) e insere na lista local.
    // Evita recarregar as 7 tabelas do banco só pra criar 1 tarefa.
    const { data: fullTask } = await supabase
      .from('tasks')
      .select('*, comments(*), timeline_events(*)')
      .eq('id', data.id)
      .single();

    if (fullTask) {
      const formatted: Task = {
        ...fullTask,
        requesterId: fullTask.requester_id,
        requesterName: fullTask.requester_name,
        assigneeId: fullTask.assignee_id,
        dueDate: fullTask.due_date,
        referenceLinks: fullTask.reference_links,
        createdAt: fullTask.created_at,
        updatedAt: fullTask.updated_at,
        startedAt: fullTask.started_at,
        distributedAt: fullTask.distributed_at,
        completedAt: fullTask.completed_at,
        externalConsultant: fullTask.external_consultant,
        internalConsultant: fullTask.internal_consultant,
        comments: (fullTask.comments || []).map((c: any) => ({ ...c, userId: c.user_id, createdAt: c.created_at })),
        timeline: (fullTask.timeline_events || []).map((e: any) => ({ ...e, userId: e.user_id, createdAt: e.created_at }))
          .sort((a: any, b: any) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()),
      };
      setTasks(prev => [formatted, ...prev]);

      // Se a etapa inicial da tarefa (normalmente "Triagem") tem dono
      // configurado, avisa essa pessoa que chegou uma demanda nova.
      const owners = stageOwners.filter(s => s.status === formatted.status && s.userId !== taskData.requesterId);
      for (const owner of owners) {
        await notifyUser(
          owner.userId,
          `Nova demanda em ${formatted.status}`,
          `"${formatted.title}" foi criada por ${formatted.requesterName} e está aguardando em ${formatted.status}.`,
          formatted.id,
          'stage_owner'
        );
      }
    }
  };

  const updateTask = async (id: string, updates: Partial<Task>, modifierId: string) => {
    if (!supabase) return;

    const currentTask = tasks.find(t => t.id === id);
    if (!currentTask) return;

    const dbUpdates: any = {};
    if (updates.title !== undefined) dbUpdates.title = updates.title;
    if (updates.description !== undefined) dbUpdates.description = updates.description;
    if (updates.category !== undefined) dbUpdates.category = updates.category;
    if (updates.priority !== undefined) dbUpdates.priority = updates.priority;
    if (updates.status !== undefined) dbUpdates.status = updates.status;
    if (updates.assigneeId !== undefined) dbUpdates.assignee_id = updates.assigneeId;
    if (updates.dueDate !== undefined) dbUpdates.due_date = updates.dueDate;
    if (updates.referenceLinks !== undefined) dbUpdates.reference_links = updates.referenceLinks;
    if (updates.notes !== undefined) dbUpdates.notes = updates.notes;
    if (updates.externalConsultant !== undefined) dbUpdates.external_consultant = updates.externalConsultant;
    if (updates.internalConsultant !== undefined) dbUpdates.internal_consultant = updates.internalConsultant;

    // Carimbos automáticos do ciclo de vida da tarefa — sem isso, started_at/
    // distributed_at/completed_at ficavam sempre NULL e o card de "Performance
    // (SLA)" do dashboard nunca tinha dado pra calcular nada (sempre 0%/"-").
    const now = new Date().toISOString();
    const localExtras: Partial<Task> = {};

    if (updates.status !== undefined && updates.status !== currentTask.status) {
      // Primeira vez que sai de "Triagem": marca início do atendimento.
      if (currentTask.status === "Triagem" && !currentTask.startedAt) {
        dbUpdates.started_at = now;
        localExtras.startedAt = now;
      }
      // Chegou em "Aprovado": marca conclusão (pra contar no SLA).
      if (updates.status === "Aprovado") {
        dbUpdates.completed_at = now;
        localExtras.completedAt = now;
      }
      // Reaberta depois de aprovada (voltou de "Aprovado" pra outro status):
      // limpa completed_at, senão o SLA continuaria contando ela como concluída.
      if (currentTask.status === "Aprovado" && updates.status !== "Aprovado") {
        dbUpdates.completed_at = null;
        localExtras.completedAt = undefined;
      }
    }

    // Primeira vez que a tarefa recebe um responsável: marca distribuição.
    if (
      updates.assigneeId !== undefined &&
      updates.assigneeId &&
      updates.assigneeId !== currentTask.assigneeId &&
      !currentTask.distributedAt
    ) {
      dbUpdates.distributed_at = now;
      localExtras.distributedAt = now;
    }

    const { error } = await supabase.from('tasks').update(dbUpdates).eq('id', id);
    
    if (error) {
      toast.error('Erro ao atualizar: ' + error.message);
      return;
    }

    if (updates.status && updates.status !== currentTask.status) {
      await supabase.from('timeline_events').insert([{
        task_id: id,
        type: 'status_changed',
        user_id: modifierId,
        description: `Status alterado de ${currentTask.status} para ${updates.status}.`
      }]);
    } else if (updates.assigneeId !== undefined && updates.assigneeId !== currentTask.assigneeId) {
      const newAssignee = users.find(u => u.id === updates.assigneeId)?.name || "Alguém";
      await supabase.from('timeline_events').insert([{
        task_id: id,
        type: 'assigned',
        user_id: modifierId,
        description: updates.assigneeId ? `Atribuída para ${newAssignee}.` : `Responsável removido.`
      }]);
    } else {
      await supabase.from('timeline_events').insert([{
        task_id: id,
        type: 'other',
        user_id: modifierId,
        description: `Tarefa atualizada.`
      }]);
    }

    // Atualização otimista: aplica a mudança localmente na hora, sem esperar
    // nem recarregar TODAS as tabelas do banco. A tela nunca "pisca".
    setTasks(prev => prev.map(t => (t.id === id ? { ...t, ...updates, ...localExtras } : t)));

    // Notifica quem virou responsável pela demanda (se não foi ele mesmo que se atribuiu).
    if (
      updates.assigneeId !== undefined &&
      updates.assigneeId &&
      updates.assigneeId !== currentTask.assigneeId &&
      updates.assigneeId !== modifierId
    ) {
      const modifier = users.find(u => u.id === modifierId)?.name || "Alguém";
      await notifyUser(
        updates.assigneeId,
        `Demanda atribuída a você`,
        `${modifier} atribuiu "${currentTask.title}" para você.`,
        id,
        'assigned'
      );
    }

    // Notifica o(s) dono(s) configurado(s) da nova etapa (Configurações → Donos de Etapa).
    if (updates.status !== undefined && updates.status !== currentTask.status) {
      const owners = stageOwners.filter(s => s.status === updates.status && s.userId !== modifierId);
      for (const owner of owners) {
        await notifyUser(
          owner.userId,
          `Demanda chegou em ${updates.status}`,
          `"${currentTask.title}" mudou para ${updates.status} e precisa da sua atenção.`,
          id,
          'stage_owner'
        );
      }
    }

    // Notifica quem tem relação direta com a tarefa (responsável e quem
    // pediu) quando o prazo muda — quem fez a mudança não recebe aviso dela mesma.
    if (updates.dueDate !== undefined && updates.dueDate !== currentTask.dueDate) {
      const modifier = users.find(u => u.id === modifierId)?.name || "Alguém";
      const fmt = (d?: string | null) => (d ? new Date(d).toLocaleDateString("pt-BR") : "sem prazo definido");
      const interested = new Set([currentTask.assigneeId, currentTask.requesterId].filter(Boolean) as string[]);
      interested.delete(modifierId);
      for (const uid of interested) {
        await notifyUser(
          uid,
          `Prazo alterado`,
          `${modifier} alterou o prazo de "${currentTask.title}" de ${fmt(currentTask.dueDate)} para ${fmt(updates.dueDate)}.`,
          id,
          'due_date_changed'
        );
      }
    }
  };

  const moveTaskStatus = async (id: string, newStatus: string, modifierId: string) => {
    await updateTask(id, { status: newStatus }, modifierId);
  };

  const addComment = async (taskId: string, userId: string, text: string) => {
    if (!supabase) return;
    
    const { error } = await supabase.from('comments').insert([{
      task_id: taskId,
      user_id: userId,
      text
    }]);

    if (error) {
      toast.error('Erro ao comentar: ' + error.message);
      return;
    }

    await supabase.from('timeline_events').insert([{
      task_id: taskId,
      type: 'commented',
      user_id: userId,
      description: 'comentou na demanda.'
    }]);

    // Notifica responsável e quem pediu a demanda sobre o comentário novo
    // (menos quem comentou, óbvio).
    const commentedTask = tasks.find(t => t.id === taskId);
    if (commentedTask) {
      const commenter = users.find(u => u.id === userId)?.name || "Alguém";
      const preview = text.length > 120 ? text.slice(0, 120) + "…" : text;
      const interested = new Set([commentedTask.assigneeId, commentedTask.requesterId].filter(Boolean) as string[]);
      interested.delete(userId);
      for (const uid of interested) {
        await notifyUser(
          uid,
          `Novo comentário em "${commentedTask.title}"`,
          `${commenter}: "${preview}"`,
          taskId,
          'commented'
        );
      }
    }

    await refreshTasks();
  };
  
  const signOut = async () => {
    if (supabase) await supabase.auth.signOut();
  };

  const addOption = async (type: 'departments' | 'categories' | 'priorities', name: string) => {
    if (!supabase) return;
    const { error } = await supabase.from(type).insert([{ name }]);
    if (error) {
      toast.error(`Erro ao adicionar ${type}: ` + error.message);
      return;
    }
    await refreshTasks();
  };

  const removeOption = async (type: 'departments' | 'categories' | 'priorities', name: string) => {
    if (!supabase) return;
    const { error } = await supabase.from(type).delete().eq('name', name);
    if (error) {
      toast.error(`Erro ao remover ${type}: ` + error.message);
      return;
    }
    await refreshTasks();
  };

  if (!isLoaded) {
    return <div className="flex h-screen items-center justify-center bg-slate-50"><div className="w-8 h-8 rounded-full border-4 border-slate-200 border-t-blue-600 animate-spin"></div></div>;
  }

  const unreadCount = notifications.filter(n => !n.read).length;

  return (
    <StoreContext.Provider value={{ 
      users, currentUser, tasks, departments, categories, priorities, statuses, roles, 
      notifications, unreadCount, stageOwners,
      isLoaded, addTask, updateTask, addComment, moveTaskStatus, refreshTasks, signOut,
      addOption, removeOption, markNotificationRead, markAllNotificationsRead,
      addStageOwner, removeStageOwner
    }}>
      {children}
    </StoreContext.Provider>
  );
}

export function useStore() {
  const context = useContext(StoreContext);
  if (context === undefined) {
    throw new Error("useStore must be used within a StoreProvider");
  }
  return context;
}
GENESIS_HUB_EOF_9f3k2

mkdir -p "lib"
cat > "lib/types.ts" << 'GENESIS_HUB_EOF_9f3k2'
export type Role = string;

export type Department = string;

export type User = {
  id: string;
  name: string;
  role: Role;
  tipo_usuario?: string;
  avatar?: string;
  email?: string;
  department?: Department | string;
};

export type Category = string;

export type Priority = string;

export type Status = string;

export type Comment = {
  id: string;
  userId: string;
  text: string;
  createdAt: string;
};

export type TimelineEvent = {
  id: string;
  type: 'created' | 'assigned' | 'status_changed' | 'commented' | 'transferred' | 'completed' | 'other';
  userId: string;
  description: string;
  createdAt: string;
};

export type Task = {
  id: string;
  title: string;
  description: string;
  category: Category;
  priority: Priority;
  status: Status;
  requesterId: string;
  requesterName: string;
  department: Department | string;
  assigneeId?: string;
  createdAt: string;
  dueDate: string;
  comments: Comment[];
  timeline: TimelineEvent[];
  referenceLinks?: string[];
  notes?: string;
  updatedAt?: string;
  startedAt?: string;
  distributedAt?: string;
  completedAt?: string;
  externalConsultant?: string;
  internalConsultant?: string;
};

export type Notification = {
  id: string;
  userId: string;
  taskId?: string;
  title: string;
  message?: string;
  type: 'assigned' | 'stage_owner' | 'commented' | 'due_date_changed' | 'other';
  read: boolean;
  createdAt: string;
};

export type StageOwner = {
  id: string;
  status: Status;
  userId: string;
};
GENESIS_HUB_EOF_9f3k2

mkdir -p "components/kanban"
cat > "components/kanban/board.tsx" << 'GENESIS_HUB_EOF_9f3k2'
"use client";

import { useStore } from "@/lib/store";
import { DragDropContext, DropResult } from "@hello-pangea/dnd";
import { KanbanColumn } from "./column";
import { Status, Task } from "@/lib/types";
import { useState, useEffect } from "react";
import { LayoutGrid, List, Trello } from "lucide-react";
import { Button } from "@/components/ui/button";
import { format, parseISO, isPast, isToday } from "date-fns";
import { ptBR } from "date-fns/locale";
import { TaskDetailModal } from "@/components/tasks/task-detail-modal";
import { useSearchParams, useRouter } from "next/navigation";

export function KanbanBoard() {
  const { tasks, currentUser, moveTaskStatus, users, statuses } = useStore();
  const [view, setView] = useState<"kanban" | "list" | "cards">("kanban");

  // Deep-link: clicar numa notificação leva pra /kanban?task=<id> e abre o
  // modal dessa tarefa direto, sem precisar caçar o card na tela.
  const searchParams = useSearchParams();
  const router = useRouter();
  const deepLinkTaskId = searchParams.get("task");
  const deepLinkTask = deepLinkTaskId ? tasks.find(t => t.id === deepLinkTaskId) : undefined;
  const closeDeepLink = () => router.replace("/kanban");

  const onDragEnd = (result: DropResult) => {
    const { destination, source, draggableId } = result;
    if (!destination) return;
    if (destination.droppableId === source.droppableId && destination.index === source.index) return;
    if (currentUser) {
      moveTaskStatus(draggableId, destination.droppableId as Status, currentUser.id);
    }
  };

  // Admin e Gestor enxergam todas as demandas, independente de quem criou ou
  // é o responsável — igual à mesma regra já usada no Dashboard e em Tarefas.
  // Colaborador só vê o que ele criou ou o que foi atribuído a ele.
  const isGestorOrAdmin = currentUser?.role === "Admin" || currentUser?.role === "Gestor";
  const displayTasks = isGestorOrAdmin
    ? tasks
    : tasks.filter(t => t.assigneeId === currentUser?.id || t.requesterId === currentUser?.id);

  return (
    <>
      <div className="flex flex-col h-full min-h-0 overflow-hidden space-y-6 p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 shrink-0">
          <div>
            <h2 className="text-3xl font-bold tracking-tight">Demandas</h2>
            <p className="text-muted-foreground mt-2">Acompanhamento e execução das demandas.</p>
          </div>
          
          <div className="flex items-center gap-2 bg-slate-100 p-1 rounded-lg self-start">
            <Button
              variant={view === "kanban" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setView("kanban")}
              className="h-8 gap-2"
            >
              <Trello className="w-4 h-4" />
              <span className="hidden sm:inline">Kanban</span>
            </Button>
            <Button
              variant={view === "list" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setView("list")}
              className="h-8 gap-2"
            >
              <List className="w-4 h-4" />
              <span className="hidden sm:inline">Lista</span>
            </Button>
            <Button
              variant={view === "cards" ? "secondary" : "ghost"}
              size="sm"
              onClick={() => setView("cards")}
              className="h-8 gap-2"
            >
              <LayoutGrid className="w-4 h-4" />
              <span className="hidden sm:inline">Cards</span>
            </Button>
          </div>
        </div>

        {view === "kanban" && (
          <DragDropContext onDragEnd={onDragEnd}>
            <div className="flex flex-1 min-h-0 gap-6 overflow-x-auto overflow-y-hidden pb-4">
              {statuses.map(status => {
                const colTasks = displayTasks.filter(t => t.status === status);
                return <KanbanColumn key={status} column={{ id: status, title: status }} tasks={colTasks} />;
              })}
            </div>
          </DragDropContext>
        )}

        {view === "list" && (
          <div className="flex-1 min-h-0 overflow-y-auto bg-white rounded-xl border border-slate-200">
            <table className="w-full text-sm text-left">
              <thead className="bg-slate-50 text-slate-500 text-xs uppercase font-bold border-b border-slate-200 sticky top-0">
                <tr>
                  <th className="px-6 py-4">ID</th>
                  <th className="px-6 py-4">Título</th>
                  <th className="px-6 py-4">Status</th>
                  <th className="px-6 py-4">Prioridade</th>
                  <th className="px-6 py-4">Responsável</th>
                  <th className="px-6 py-4">Prazo</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200">
                {displayTasks.map(task => {
                  const assignee = users.find(u => u.id === task.assigneeId);
                  return (
                    <TaskRow key={task.id} task={task} assignee={assignee} />
                  );
                })}
                {displayTasks.length === 0 && (
                  <tr>
                    <td colSpan={6} className="px-6 py-8 text-center text-slate-500">
                      Nenhuma demanda encontrada.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}

        {view === "cards" && (
          <div className="flex-1 min-h-0 overflow-y-auto grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 pb-4">
            {displayTasks.map(task => {
              const assignee = users.find(u => u.id === task.assigneeId);
              return (
                <TaskGridCard key={task.id} task={task} assignee={assignee} />
              );
            })}
          </div>
        )}
      </div>

      {deepLinkTask && (
        <TaskDetailModal
          task={deepLinkTask}
          open={true}
          onOpenChange={(open) => { if (!open) closeDeepLink(); }}
        />
      )}
    </>
  );
}

function TaskRow({ task, assignee }: { task: Task; assignee?: { name: string } }) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  return (
    <>
      <tr onClick={() => setIsModalOpen(true)} className="hover:bg-slate-50 cursor-pointer transition-colors group">
        <td className="px-6 py-4 font-mono text-slate-400 group-hover:text-slate-600">#{task.id.slice(0, 4)}</td>
        <td className="px-6 py-4 font-medium text-slate-900">{task.title}</td>
        <td className="px-6 py-4">
          <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-slate-100 text-slate-600 uppercase tracking-wider">
            {task.status}
          </span>
        </td>
        <td className="px-6 py-4">
          <span className={`px-2.5 py-1 rounded text-[11px] font-bold uppercase tracking-wider ${task.priority === 'Alta' ? 'bg-orange-100 text-orange-700' : task.priority === 'Urgente' ? 'bg-red-100 text-red-700' : 'bg-slate-100 text-slate-600'}`}>
            {task.priority}
          </span>
        </td>
        <td className="px-6 py-4">
          {assignee ? (
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-bold text-[10px] flex items-center justify-center">
                {assignee.name.split(' ').map((n: string) => n[0]).join('').substring(0, 2).toUpperCase()}
              </div>
              <span className="text-slate-600">{assignee.name}</span>
            </div>
          ) : (
            <span className="text-slate-400 text-xs italic">Não atribuído</span>
          )}
        </td>
        <td className={`px-6 py-4 ${getDateColor(task.dueDate, task.status)}`}>
          {task.dueDate ? format(parseISO(task.dueDate), "dd/MM/yyyy", { locale: ptBR }) : '-'}
        </td>
      </tr>
      <TaskDetailModal task={task} open={isModalOpen} onOpenChange={setIsModalOpen} />
    </>
  );
}

function TaskGridCard({ task, assignee }: { task: Task; assignee?: { name: string } }) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  return (
    <>
      <div onClick={() => setIsModalOpen(true)} className="bg-white rounded-xl border border-slate-200 p-5 shadow-sm hover:shadow-md transition-shadow cursor-pointer flex flex-col h-full">
        <div className="flex justify-between items-start mb-3">
          <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${task.priority === 'Alta' ? 'bg-orange-100 text-orange-700' : task.priority === 'Urgente' ? 'bg-red-100 text-red-700' : 'bg-slate-100 text-slate-600'}`}>
            {task.priority}
          </span>
          <span className="px-2 py-0.5 bg-slate-50 border border-slate-200 rounded text-[10px] font-bold text-slate-500 uppercase tracking-wider">
            {task.status}
          </span>
        </div>
        <h3 className="font-bold text-slate-900 mb-2 leading-tight">{task.title}</h3>
        <p className="text-xs text-slate-500 line-clamp-2 mb-4 flex-1">{task.description}</p>
        
        <div className="flex items-center justify-between pt-4 border-t border-slate-100 mt-auto">
          {assignee ? (
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-full bg-blue-100 text-blue-700 font-bold text-[10px] flex items-center justify-center">
                {assignee.name.split(' ').map((n: string) => n[0]).join('').substring(0, 2).toUpperCase()}
              </div>
              <span className="text-xs font-medium text-slate-600 truncate max-w-[100px]">{assignee.name}</span>
            </div>
          ) : (
            <span className="text-slate-400 text-xs italic">Não atribuído</span>
          )}
          <span className={`text-xs font-semibold ${getDateColor(task.dueDate, task.status)}`}>
            {task.dueDate ? format(parseISO(task.dueDate), "dd/MM", { locale: ptBR }) : '-'}
          </span>
        </div>
      </div>
      <TaskDetailModal task={task} open={isModalOpen} onOpenChange={setIsModalOpen} />
    </>
  );
}

function getDateColor(dueDateStr: string | undefined, status: string) {
  if (!dueDateStr || status === 'Aprovado') return 'text-slate-500';
  const date = parseISO(dueDateStr);
  
  if (isToday(date)) return 'text-amber-600 font-bold';
  if (isPast(date)) return 'text-red-600 font-bold';
  return 'text-emerald-600 font-bold';
}
GENESIS_HUB_EOF_9f3k2

mkdir -p "components/layout"
cat > "components/layout/notification-bell.tsx" << 'GENESIS_HUB_EOF_9f3k2'
"use client";

import { Bell, UserPlus, ArrowRightCircle, Info, CheckCheck, MessageSquare, CalendarClock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { useStore } from "@/lib/store";
import { formatDistanceToNow } from "date-fns";
import { ptBR } from "date-fns/locale";
import { useRouter } from "next/navigation";

const typeIcon: Record<string, React.ReactNode> = {
  assigned: <UserPlus className="w-4 h-4 text-blue-600" />,
  stage_owner: <ArrowRightCircle className="w-4 h-4 text-violet-600" />,
  commented: <MessageSquare className="w-4 h-4 text-emerald-600" />,
  due_date_changed: <CalendarClock className="w-4 h-4 text-amber-600" />,
  other: <Info className="w-4 h-4 text-slate-500" />,
};

export function NotificationBell() {
  const { notifications, unreadCount, markNotificationRead, markAllNotificationsRead } = useStore();
  const router = useRouter();

  const openNotification = (id: string, read: boolean, taskId?: string) => {
    if (!read) markNotificationRead(id);
    if (taskId) router.push(`/kanban?task=${taskId}`);
  };

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="relative text-slate-500 hover:text-slate-700 shrink-0">
          <Bell className="w-5 h-5" />
          {unreadCount > 0 && (
            <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center">
              {unreadCount > 9 ? "9+" : unreadCount}
            </span>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80 p-0 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100">
          <p className="text-sm font-bold text-slate-800">Notificações</p>
          {unreadCount > 0 && (
            <button
              onClick={() => markAllNotificationsRead()}
              className="text-xs text-blue-600 hover:text-blue-700 font-medium flex items-center gap-1"
            >
              <CheckCheck className="w-3.5 h-3.5" /> Marcar todas como lidas
            </button>
          )}
        </div>
        <div className="max-h-96 overflow-y-auto divide-y divide-slate-50">
          {notifications.length === 0 && (
            <p className="text-sm text-slate-400 text-center py-10">Nenhuma notificação por aqui.</p>
          )}
          {notifications.map(n => (
            <button
              key={n.id}
              onClick={() => openNotification(n.id, n.read, n.taskId)}
              className={`w-full text-left px-4 py-3 flex gap-3 hover:bg-slate-50 transition-colors ${!n.read ? "bg-blue-50/50" : ""}`}
            >
              <div className="mt-0.5 shrink-0">{typeIcon[n.type] || typeIcon.other}</div>
              <div className="flex-1 min-w-0">
                <p className={`text-sm ${!n.read ? "font-semibold text-slate-800" : "text-slate-600"}`}>{n.title}</p>
                {n.message && <p className="text-xs text-slate-500 mt-0.5 line-clamp-2">{n.message}</p>}
                <p className="text-[11px] text-slate-400 mt-1">
                  {formatDistanceToNow(new Date(n.createdAt), { addSuffix: true, locale: ptBR })}
                </p>
              </div>
              {!n.read && <span className="w-2 h-2 rounded-full bg-blue-500 shrink-0 mt-1.5" />}
            </button>
          ))}
        </div>
      </PopoverContent>
    </Popover>
  );
}
GENESIS_HUB_EOF_9f3k2

mkdir -p "app/(app)/kanban"
cat > "app/(app)/kanban/page.tsx" << 'GENESIS_HUB_EOF_9f3k2'
import { Suspense } from 'react';
import { KanbanBoard } from '@/components/kanban/board';

export default function KanbanPage() {
  return (
    <Suspense fallback={<div className="flex h-full items-center justify-center"><div className="w-8 h-8 rounded-full border-4 border-slate-200 border-t-blue-600 animate-spin" /></div>}>
      <KanbanBoard />
    </Suspense>
  );
}
GENESIS_HUB_EOF_9f3k2

mkdir -p "components/layout"
cat > "components/layout/header.tsx" << 'GENESIS_HUB_EOF_9f3k2'
"use client";

import { PlusCircle, Menu, PanelLeft } from "lucide-react";
import { TaskFormModal } from "@/components/tasks/task-form-modal";
import { NotificationBell } from "@/components/layout/notification-bell";
import { useState } from "react";
import { Button } from "@/components/ui/button";

export function Header({ toggleSidebar, isSidebarOpen, isMobile }: { toggleSidebar?: () => void, isSidebarOpen?: boolean, isMobile?: boolean }) {
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <header className="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-4 sm:px-8 sticky top-0 z-10 shrink-0">
      <div className="flex items-center gap-4 flex-1 overflow-hidden">
        {toggleSidebar && isMobile && (
          <Button variant="ghost" size="icon" onClick={toggleSidebar} className="text-slate-500 hover:text-slate-700 shrink-0">
            <Menu className="w-5 h-5" />
          </Button>
        )}
        <h1 className="text-lg sm:text-xl font-bold text-slate-800 tracking-tight truncate">Gestão de Demandas</h1>
      </div>
      
      <div className="flex items-center gap-2 sm:gap-4 ml-4 shrink-0">
        <NotificationBell />
        <Button 
          onClick={() => setIsModalOpen(true)} 
          className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-3 sm:px-4 py-2 rounded-md text-sm font-semibold transition-colors shadow-sm"
        >
          <PlusCircle className="w-4 h-4" />
          <span className="hidden sm:inline">Nova Demanda</span>
          <span className="sm:hidden">Nova</span>
        </Button>
      </div>
      
      <TaskFormModal open={isModalOpen} onOpenChange={setIsModalOpen} />
    </header>
  );
}
GENESIS_HUB_EOF_9f3k2

mkdir -p "app/(app)/admin/settings"
cat > "app/(app)/admin/settings/page.tsx" << 'GENESIS_HUB_EOF_9f3k2'
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
    <>
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

        {/* Colaboradores Cadastrados */}
        <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
          <div className="flex items-center gap-2 mb-1">
            <UsersIcon className="w-4 h-4 text-slate-500" />
            <h2 className="text-lg font-bold text-slate-800">Colaboradores Cadastrados</h2>
          </div>
          <p className="text-sm text-slate-500 mb-4">Edite nome, função, tipo de usuário e setor de quem já tem conta no sistema.</p>

          <div className="space-y-2">
            {users.map(user => (
              <div key={user.id} className="flex flex-wrap items-center gap-3 p-3 rounded-lg bg-slate-50 border border-slate-100">
                <div className="flex-1 min-w-[140px]">
                  <p className="text-sm font-semibold text-slate-800">{user.name}</p>
                  <p className="text-xs text-slate-400">{user.email}</p>
                </div>
                <span className="text-xs text-slate-600 bg-white border border-slate-200 px-2 py-1 rounded min-w-[100px] text-center">
                  {user.tipo_usuario || "Sem função"}
                </span>
                <span className={`text-[10px] font-bold px-2 py-1 rounded uppercase ${
                  user.role === "Admin" ? "bg-violet-100 text-violet-700" :
                  user.role === "Gestor" ? "bg-blue-100 text-blue-700" :
                  "bg-slate-200 text-slate-600"
                }`}>
                  {user.role}
                </span>
                <span className="text-xs text-slate-600 bg-white border border-slate-200 px-2 py-1 rounded min-w-[100px] text-center">
                  {(user.department as string) || "Sem setor"}
                </span>
                <Button variant="ghost" size="icon" onClick={() => openEditUser(user)} className="h-8 w-8 text-slate-500 hover:text-blue-600 hover:bg-blue-50 shrink-0">
                  <Pencil className="w-4 h-4" />
                </Button>
              </div>
            ))}
            {users.length === 0 && <p className="text-sm text-slate-400 italic">Nenhum colaborador cadastrado ainda.</p>}
          </div>
        </div>

        {/* Donos de Etapa */}
        <div className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
          <h2 className="text-lg font-bold text-slate-800 mb-1">Donos de Etapa</h2>
          <p className="text-sm text-slate-500 mb-4">
            Escolha quem é avisado (no sino e por e-mail) toda vez que uma demanda chega numa etapa específica do Kanban — independente de quem é o responsável pela tarefa.
          </p>

          <div className="flex flex-wrap items-end gap-3 mb-5">
            <div className="flex-1 min-w-[160px] space-y-1.5">
              <Label className="text-xs">Etapa</Label>
              <Select value={ownerStatus} onValueChange={setOwnerStatus}>
                <SelectTrigger><SelectValue placeholder="Selecione a etapa" /></SelectTrigger>
                <SelectContent>
                  {statuses.map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="flex-1 min-w-[160px] space-y-1.5">
              <Label className="text-xs">Responsável</Label>
              <Select value={ownerUserId} onValueChange={setOwnerUserId}>
                <SelectTrigger><SelectValue placeholder="Selecione a pessoa" /></SelectTrigger>
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
              <div key={status} className="flex flex-wrap items-center gap-2 p-3 rounded-lg bg-slate-50 border border-slate-100">
                <span className="text-xs font-bold text-slate-500 uppercase w-40 shrink-0">{status}</span>
                <div className="flex flex-wrap gap-2">
                  {stageOwners.filter(so => so.status === status).map(so => {
                    const owner = users.find(u => u.id === so.userId);
                    return (
                      <span key={so.id} className="inline-flex items-center gap-1.5 bg-white border border-slate-200 text-xs font-medium text-slate-700 px-2.5 py-1 rounded-full">
                        {owner?.name || "Usuário removido"}
                        <button onClick={() => removeStageOwner(so.id)} className="text-slate-400 hover:text-red-500">
                          <Trash2 className="w-3 h-3" />
                        </button>
                      </span>
                    );
                  })}
                </div>
              </div>
            ))}
            {stageOwners.length === 0 && (
              <p className="text-sm text-slate-400 italic">Nenhuma etapa com dono configurado ainda — ninguém recebe notificação automática por etapa.</p>
            )}
          </div>
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
GENESIS_HUB_EOF_9f3k2

mkdir -p "app/api/notify"
cat > "app/api/notify/route.ts" << 'GENESIS_HUB_EOF_9f3k2'
import { NextResponse } from "next/server";

// Envia e-mail de notificação via Resend. A RESEND_API_KEY nunca é exposta
// ao navegador — só existe aqui no servidor, igual à SUPABASE_SERVICE_ROLE_KEY
// usada em /api/invite.
export async function POST(req: Request) {
  try {
    const { to, title, message, taskId } = await req.json();

    const apiKey = process.env.RESEND_API_KEY;
    const fromEmail = process.env.RESEND_FROM_EMAIL;
    const appUrl = process.env.NEXT_PUBLIC_APP_URL || "https://genesis-hub1.vercel.app";

    if (!apiKey || !fromEmail) {
      // Não derruba o app por causa de e-mail: só loga e segue.
      console.error("RESEND_API_KEY ou RESEND_FROM_EMAIL não configurados.");
      return NextResponse.json({ skipped: true }, { status: 200 });
    }

    if (!to) {
      return NextResponse.json({ error: "Destinatário (to) não informado." }, { status: 400 });
    }

    const html = `
      <div style="font-family: -apple-system, Arial, sans-serif; max-width: 480px; margin: 0 auto; background:#0B1224; padding:32px; border-radius:16px; color:#E2E8F0;">
        <p style="color:#7AA2FF; font-size:12px; letter-spacing:1px; text-transform:uppercase; margin:0 0 12px;">Genesis Hub</p>
        <h2 style="color:#fff; font-size:20px; margin:0 0 16px;">${title}</h2>
        ${message ? `<p style="font-size:14px; color:#94A3B8; margin:0 0 24px; line-height:1.5;">${message}</p>` : ""}
        <a href="${appUrl}/kanban" style="display:inline-block; background:linear-gradient(135deg,#5B8DFF,#2F6FEE); color:#fff; text-decoration:none; padding:12px 20px; border-radius:8px; font-size:14px; font-weight:600;">
          Ver no Genesis Hub
        </a>
      </div>
    `;

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to,
        subject: title,
        html,
      }),
    });

    if (!resendRes.ok) {
      const errText = await resendRes.text();
      console.error("Erro ao enviar e-mail via Resend:", errText);
      return NextResponse.json({ error: errText }, { status: 502 });
    }

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error("Erro no endpoint de notificação:", error);
    return NextResponse.json({ error: error.message || "Internal Server Error" }, { status: 500 });
  }
}
GENESIS_HUB_EOF_9f3k2

echo "Todos os arquivos foram atualizados."
git add -A
git commit -m "notificacoes: sino, e-mail, donos de etapa"
git push
echo "Commit e push feitos. Aguarde o deploy da Vercel."