#!/bin/bash
set -e
echo "Atualizando arquivos do Genesis Hub..."

mkdir -p "lib"
cat > "lib/store.tsx" << 'GENESIS_HUB_EOF_7q1z9'
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
      supabase.from('statuses').select('name').order('order_index'),
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

  // Tempo real: assim que alguém muda um card ou cria/atualiza uma tarefa,
  // todo mundo com a tela aberta vê na hora — sem precisar dar F5. E o sino
  // de notificação aparece instantaneamente pra quem foi avisado.
  useEffect(() => {
    if (!supabase || !currentUser?.id) return;
    const client = supabase;

    const channel = client
      .channel(`realtime-${currentUser.id}`)
      // Notificações: só as que são PARA este usuário (o filtro já garante
      // isso, então nem precisamos checar de novo no código).
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${currentUser.id}` },
        (payload) => {
          const n = payload.new as any;
          setNotifications(prev => {
            if (prev.some(existing => existing.id === n.id)) return prev;
            return [{
              id: n.id, userId: n.user_id, taskId: n.task_id, title: n.title,
              message: n.message, type: n.type, read: n.read, createdAt: n.created_at,
            }, ...prev];
          });
        }
      )
      // Tarefas: qualquer criação/atualização/exclusão, de qualquer pessoa.
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'tasks' },
        (payload) => {
          if (payload.eventType === 'DELETE') {
            const oldId = (payload.old as any)?.id;
            if (oldId) setTasks(prev => prev.filter(t => t.id !== oldId));
            return;
          }

          const t = payload.new as any;
          if (!t) return;

          const mapped = {
            id: t.id,
            title: t.title,
            description: t.description,
            category: t.category,
            priority: t.priority,
            status: t.status,
            notes: t.notes,
            requesterId: t.requester_id,
            requesterName: t.requester_name,
            assigneeId: t.assignee_id,
            department: t.department,
            dueDate: t.due_date,
            referenceLinks: t.reference_links,
            createdAt: t.created_at,
            updatedAt: t.updated_at,
            startedAt: t.started_at,
            distributedAt: t.distributed_at,
            completedAt: t.completed_at,
            externalConsultant: t.external_consultant,
            internalConsultant: t.internal_consultant,
          };

          setTasks(prev => {
            const idx = prev.findIndex(existing => existing.id === t.id);
            if (idx === -1) {
              // Card novo criado por outra pessoa: entra na lista (sem
              // comments/timeline ainda — completam quando o card for aberto).
              if (payload.eventType !== 'INSERT') return prev;
              return [{ ...mapped, comments: [], timeline: [] } as Task, ...prev];
            }
            // Card existente: atualiza só os campos, preservando
            // comments/timeline que já estavam carregados localmente.
            return prev.map((existing, i) => (i === idx ? { ...existing, ...mapped } : existing));
          });
        }
      )
      .subscribe();

    return () => {
      client.removeChannel(channel);
    };
  }, [currentUser?.id]);

  const refreshTasks = async () => {
    await fetchData();
  };

  // Função central de notificação: grava no sino (tabela `notifications`) e
  // dispara o e-mail em segundo plano. Usada tanto pra atribuição direta
  // quanto pra "dono de etapa". Nunca notifica a própria pessoa que fez a ação.
  const notifyUser = async (userId: string, title: string, message: string, taskId?: string, type: Notification['type'] = 'other') => {
    if (!supabase || !userId) return;

    // Importante: NÃO usar .select() aqui. Quem está criando essa notificação
    // é sempre outra pessoa (o próprio dono nunca é notificado da sua ação),
    // e pedir a linha de volta conta como uma leitura (SELECT) pro Postgres —
    // que é barrada pela política "só o dono lê a própria notificação".
    // Isso fazia o insert inteiro falhar com erro de RLS, mesmo a política
    // de INSERT estando certa.
    const { error } = await supabase.from('notifications').insert([{
      user_id: userId, task_id: taskId || null, title, message, type,
    }]);

    if (error) {
      console.error("Falha ao criar notificação:", error.message, { userId, title, type });
      return;
    }

    const recipient = users.find(u => u.id === userId);
    if (recipient?.email) {
      fetch('/api/notify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to: recipient.email, title, message, taskId, recipientName: recipient.name }),
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

    // Regra de negócio: nenhuma demanda pode avançar pra frente de "Triagem"
    // sem um responsável definido. Se a mudança pedida tenta mudar o status
    // pra algo diferente de Triagem, e não há (nem vai haver, nessa mesma
    // chamada) um responsável, bloqueia e avisa em vez de salvar.
    const willHaveAssignee = updates.assigneeId !== undefined ? !!updates.assigneeId : !!currentTask.assigneeId;
    if (
      updates.status !== undefined &&
      updates.status !== currentTask.status &&
      updates.status !== "Triagem" &&
      !willHaveAssignee
    ) {
      toast.error("Atribua um responsável antes de mover essa demanda para frente.");
      return;
    }

    // Se a demanda está em Triagem e está ganhando responsável agora (e
    // ninguém pediu explicitamente outro status na mesma chamada), avança
    // ela sozinha pra "Atribuído, A Fazer" — sem precisar arrastar o card.
    if (
      currentTask.status === "Triagem" &&
      updates.status === undefined &&
      updates.assigneeId !== undefined &&
      updates.assigneeId &&
      !currentTask.assigneeId
    ) {
      updates = { ...updates, status: "Atribuído, A Fazer" as Status };
    }

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
GENESIS_HUB_EOF_7q1z9

mkdir -p "lib"
cat > "lib/branding.ts" << 'GENESIS_HUB_EOF_7q1z9'
// URL da logo usada em todo o sistema (login, convite, sidebar, e-mails).
// Prioriza a variável de ambiente NEXT_PUBLIC_LOGO_URL — assim que o arquivo
// for subido pro Supabase Storage, basta trocar essa variável na Vercel
// (Settings → Environment Variables) e fazer um redeploy; não precisa mexer
// em nenhum desses arquivos de novo.
export const LOGO_URL =
  process.env.NEXT_PUBLIC_LOGO_URL || "https://i.ibb.co/zp9RSKP/logo-genesis.png";
GENESIS_HUB_EOF_7q1z9

mkdir -p "app/(app)"
cat > "app/(app)/dashboard.tsx" << 'GENESIS_HUB_EOF_7q1z9'
"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useStore } from "@/lib/store";
import { isToday, isPast, parseISO } from "date-fns";
import { CheckCircle2, Clock, ListTodo, AlertCircle } from "lucide-react";

export default function DashboardPage() {
  const { tasks, currentUser, users } = useStore();

  const isGestorOrAdmin = currentUser?.role === "Admin" || currentUser?.role === "Gestor";
  
  // Se for colaborador, vê apenas suas tarefas no dashboard
  const displayTasks = isGestorOrAdmin 
    ? tasks 
    : tasks.filter(t => t.assigneeId === currentUser?.id || t.requesterId === currentUser?.id);

  
  const inTriagem = displayTasks.filter(t => t.status === "Triagem").length;
  const inProgress = displayTasks.filter(t => t.status !== "Aprovado").length;
  
  const delayed = displayTasks.filter(t => 
    t.status !== "Aprovado" && t.dueDate &&
    isPast(parseISO(t.dueDate)) && !isToday(parseISO(t.dueDate))
  ).length;

  const dueToday = displayTasks.filter(t => 
    t.status !== "Aprovado" && t.dueDate &&
    isToday(parseISO(t.dueDate))
  ).length;

  // Chart data for categories

  const categoriesCount = displayTasks.reduce((acc, task) => {
    acc[task.category] = (acc[task.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const chartData = Object.keys(categoriesCount).map(key => ({
    name: key,
    total: categoriesCount[key]
  }));

  // SLA Calculations
  const completedTasks = displayTasks.filter(t => t.status === "Aprovado" && t.completedAt);
  
  let avgDeliveryTime = 0;
  if (completedTasks.length > 0) {
    const totalDays = completedTasks.reduce((acc, task) => {
      const start = parseISO(task.createdAt);
      const end = parseISO(task.completedAt!);
      const diffTime = Math.abs(end.getTime() - start.getTime());
      const diffDays = diffTime / (1000 * 60 * 60 * 24);
      return acc + diffDays;
    }, 0);
    avgDeliveryTime = totalDays / completedTasks.length;
  }

  let slaPercentage = 0;
  const tasksWithDueDateAndCompleted = completedTasks.filter(t => t.dueDate);
  if (tasksWithDueDateAndCompleted.length > 0) {
    const onTimeCount = tasksWithDueDateAndCompleted.filter(t => {
       const due = parseISO(t.dueDate);
       const completed = parseISO(t.completedAt!);
       // Consider end of day for due date
       due.setHours(23, 59, 59, 999);
       return completed.getTime() <= due.getTime();
    }).length;
    slaPercentage = Math.round((onTimeCount / tasksWithDueDateAndCompleted.length) * 100);
  } else if (completedTasks.length > 0) {
    slaPercentage = 100;
  }

  const pendingTasks = displayTasks.filter(t => t.status !== "Aprovado");
  const bottleneckCounts = pendingTasks.reduce((acc, task) => {
    if (task.category) {
       acc[task.category] = (acc[task.category] || 0) + 1;
    }
    return acc;
  }, {} as Record<string, number>);
  
  let currentBottleneck = "Nenhum";
  let maxPending = 0;
  for (const [cat, count] of Object.entries(bottleneckCounts)) {
    if (count > maxPending) {
      maxPending = count;
      currentBottleneck = cat;
    }
  }

  // Carga de trabalho por pessoa — visão da equipe inteira (inclui Admins que
  // também são responsáveis por demandas, não só Colaboradores). Usa `tasks`
  // (todas), não `displayTasks`, porque essa seção só aparece pra quem já tem
  // visão geral (Admin/Gestor); um Colaborador nunca chega a ver essa parte.
  const activeCompanyTasks = tasks.filter(t => t.status !== "Aprovado");
  const workload = users
    .map(u => {
      const assigned = activeCompanyTasks.filter(t => t.assigneeId === u.id);
      const delayedCount = assigned.filter(t =>
        t.dueDate && isPast(parseISO(t.dueDate)) && !isToday(parseISO(t.dueDate))
      ).length;
      return { user: u, active: assigned.length, delayed: delayedCount };
    })
    .filter(w => w.active > 0)
    .sort((a, b) => b.active - a.active);

  const maxActive = Math.max(1, ...workload.map(w => w.active));
  const unassignedCount = activeCompanyTasks.filter(t => !t.assigneeId).length;

  const roleBadgeStyle: Record<string, string> = {
    Admin: "bg-violet-100 text-violet-700",
    Gestor: "bg-blue-100 text-blue-700",
    Colaborador: "bg-slate-100 text-slate-600",
  };

  const initials = (name?: string) =>
    (name || "?")
      .split(" ")
      .filter(Boolean)
      .slice(0, 2)
      .map(p => p[0]?.toUpperCase())
      .join("");

  return (
    <div className="p-6 space-y-6 flex-1 overflow-y-auto flex flex-col">
        {/* Top Metrics */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 shrink-0">
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-slate-400">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Na Triagem</p>
            <p className="text-2xl font-bold text-slate-900">{inTriagem}</p>
          </div>
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-blue-500">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Pendentes (Ativas)</p>
            <p className="text-2xl font-bold text-blue-600">{inProgress}</p>
          </div>
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-red-500">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Atrasadas</p>
            <p className="text-2xl font-bold text-red-600">{delayed}</p>
          </div>
          <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm border-l-4 border-l-amber-500">
            <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Vencem Hoje</p>
            <p className="text-2xl font-bold text-amber-600">{dueToday}</p>
          </div>
        </div>

        {/* Carga de Trabalho por Pessoa */}
        {isGestorOrAdmin && (
          <div className="bg-white rounded-xl border border-slate-200 shadow-sm shrink-0">
            <div className="flex items-center justify-between px-5 pt-5 pb-1">
              <div>
                <h4 className="text-sm font-bold text-slate-800">Carga de Trabalho da Equipe</h4>
                <p className="text-xs text-slate-400 mt-0.5">Demandas ativas por responsável, incluindo administradores</p>
              </div>
              {unassignedCount > 0 && (
                <span className="text-[11px] font-semibold px-2.5 py-1 rounded-full bg-slate-100 text-slate-500">
                  {unassignedCount} sem responsável
                </span>
              )}
            </div>
            <div className="px-5 pb-5 pt-3 divide-y divide-slate-100">
              {workload.map(({ user, active, delayed }) => (
                <div key={user.id} className="flex items-center gap-4 py-3 first:pt-0 last:pb-0">
                  <div className="w-9 h-9 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 text-white text-xs font-bold flex items-center justify-center shrink-0">
                    {initials(user.name)}
                  </div>
                  <div className="w-40 shrink-0 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">{user.name}</p>
                    <span className={`inline-block text-[10px] font-bold px-1.5 py-0.5 rounded uppercase mt-0.5 ${roleBadgeStyle[user.role] || "bg-slate-100 text-slate-600"}`}>
                      {user.role}
                    </span>
                  </div>
                  <div className="flex-1 flex items-center gap-3">
                    <div className="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
                      <div
                        className={`h-full rounded-full ${active === 0 ? "bg-slate-200" : delayed > 0 ? "bg-red-400" : "bg-blue-500"}`}
                        style={{ width: `${(active / maxActive) * 100}%` }}
                      />
                    </div>
                    <span className="text-sm font-bold text-slate-800 w-6 text-right">{active}</span>
                  </div>
                  {delayed > 0 && (
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-600 shrink-0 flex items-center gap-1">
                      <AlertCircle className="w-3 h-3" /> {delayed} atrasada{delayed > 1 ? "s" : ""}
                    </span>
                  )}
                </div>
              ))}
              {workload.length === 0 && (
                <p className="text-sm text-slate-400 text-center py-4">Ninguém com demandas ativas no momento.</p>
              )}
            </div>
          </div>
        )}

        {/* Kanban Snapshot */}
        <div className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-6 min-h-[300px]">
          {/* Column: A Fazer */}
          <div className="flex flex-col h-full">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-slate-600 uppercase flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-slate-400"></span> Triagem ({displayTasks.filter(t => t.status === "Triagem").length})
              </h3>
            </div>
            <div className="flex-1 bg-slate-100/50 rounded-xl p-3 space-y-3">
              {displayTasks.filter(t => t.status === "Triagem").slice(0, 3).map(task => {
                 return (
                  <div key={task.id} className="bg-white p-3 rounded-lg border border-slate-200 shadow-sm">
                    <div className="flex justify-between items-start mb-2">
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-orange-100 text-orange-700 uppercase">{task.priority}</span>
                      <span className="text-[10px] text-slate-400">#{task.id.slice(0,4)}</span>
                    </div>
                    <h4 className="text-sm font-bold text-slate-800 leading-tight mb-1">{task.title}</h4>
                  </div>
                 )
              })}
            </div>
          </div>

          {/* Column: Em Andamento */}
          <div className="flex flex-col h-full">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-slate-600 uppercase flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-blue-500"></span> Em Produção ({displayTasks.filter(t => t.status === "Em Produção").length})
              </h3>
            </div>
            <div className="flex-1 bg-slate-100/50 rounded-xl p-3 space-y-3">
              {displayTasks.filter(t => t.status === "Em Produção").slice(0, 3).map(task => {
                 return (
                  <div key={task.id} className="bg-white p-3 rounded-lg border border-slate-200 shadow-sm ring-2 ring-blue-500/10">
                    <div className="flex justify-between items-start mb-2">
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-red-100 text-red-700 uppercase">{task.priority}</span>
                      <span className="text-[10px] text-slate-400">#{task.id.slice(0,4)}</span>
                    </div>
                    <h4 className="text-sm font-bold text-slate-800 leading-tight mb-1">{task.title}</h4>
                  </div>
                 )
              })}
            </div>
          </div>

          {/* Column: Finalizado */}
          <div className="flex flex-col h-full">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-slate-600 uppercase flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-green-500"></span> Aprovado ({displayTasks.filter(t => t.status === "Aprovado").length})
              </h3>
            </div>
            <div className="flex-1 bg-slate-100/50 rounded-xl p-3 space-y-3">
              {displayTasks.filter(t => t.status === "Aprovado").slice(0, 3).map(task => (
                <div key={task.id} className="bg-white p-3 rounded-lg border border-slate-200 shadow-sm opacity-75">
                  <div className="flex justify-between items-start mb-2">
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-slate-100 text-slate-600 uppercase">{task.priority}</span>
                    <span className="text-[10px] text-slate-400">#{task.id.slice(0,4)}</span>
                  </div>
                  <h4 className="text-sm font-bold text-slate-800 leading-tight mb-1">{task.title}</h4>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Summary Charts (Simplified Row) */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 shrink-0">
          <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col">
            <h4 className="text-xs font-bold text-slate-400 uppercase mb-4 tracking-wider">Categorias mais solicitadas</h4>
            <div className="space-y-3 max-h-56 overflow-y-auto pr-1">
              {chartData.length === 0 && (
                <p className="text-sm text-slate-400">Nenhuma demanda ainda.</p>
              )}
              {[...chartData].sort((a, b) => b.total - a.total).map(c => {
                const maxCat = Math.max(1, ...chartData.map(d => d.total));
                return (
                  <div key={c.name} className="flex items-center gap-3">
                    <span className="text-xs text-slate-600 w-32 shrink-0 truncate" title={c.name}>{c.name}</span>
                    <div className="flex-1 h-2 rounded-full bg-slate-100 overflow-hidden">
                      <div className="h-full rounded-full bg-blue-500" style={{ width: `${(c.total / maxCat) * 100}%` }} />
                    </div>
                    <span className="text-xs font-bold text-slate-700 w-5 text-right shrink-0">{c.total}</span>
                  </div>
                );
              })}
            </div>
          </div>
          
          <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex flex-col">
            <h4 className="text-xs font-bold text-slate-400 uppercase mb-2 tracking-wider">Performance (SLA)</h4>
            <div className="flex items-center justify-between flex-1">
              <div className="relative w-24 h-24 shrink-0">
                 <svg viewBox="0 0 36 36" className="w-24 h-24">
                    <path className="stroke-current text-slate-100" strokeWidth="4" fill="none" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                    <path className={`stroke-current ${slaPercentage >= 90 ? 'text-green-500' : slaPercentage >= 70 ? 'text-amber-500' : 'text-red-500'}`} strokeWidth="4" strokeDasharray={`${slaPercentage}, 100`} strokeLinecap="round" fill="none" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                 </svg>
                 <div className="absolute inset-0 flex items-center justify-center font-bold text-xl text-slate-800">{slaPercentage}%</div>
              </div>
              <div className="flex-1 ml-6 space-y-2">
                 <div className="flex justify-between items-center">
                    <span className="text-[11px] font-medium text-slate-500">Tempo Médio Entrega</span>
                    <span className="text-sm font-bold text-slate-800">{avgDeliveryTime > 0 ? `${avgDeliveryTime.toFixed(1)} dias` : '-'}</span>
                 </div>
                 <div className="flex justify-between items-center">
                    <span className="text-[11px] font-medium text-slate-500">Eficiência Equipe</span>
                    <span className={`text-sm font-bold ${slaPercentage >= 90 ? 'text-green-600' : slaPercentage >= 70 ? 'text-amber-600' : 'text-red-600'}`}>{slaPercentage}%</span>
                 </div>
                 <div className="flex justify-between items-center border-t border-slate-100 pt-2">
                    <span className="text-[11px] font-medium text-slate-500">Gargalos Atuais</span>
                    <span className="text-sm font-bold text-red-500 uppercase text-[10px] truncate max-w-[100px]" title={currentBottleneck}>{currentBottleneck}</span>
                 </div>
              </div>
            </div>
          </div>
        </div>
      </div>
  );

}
GENESIS_HUB_EOF_7q1z9

mkdir -p "components/kanban"
cat > "components/kanban/column.tsx" << 'GENESIS_HUB_EOF_7q1z9'
"use client";

import { Droppable } from "@hello-pangea/dnd";
import { KanbanCard } from "./card";
import { Task, Status } from "@/lib/types";

interface KanbanColumnProps {
  column: { id: Status; title: string };
  tasks: Task[];
}

export function KanbanColumn({ column, tasks }: KanbanColumnProps) {
  let dotColor = "bg-slate-400";
  if (column.id === "Atribuído, A Fazer") dotColor = "bg-cyan-500";
  if (column.id === "Em Produção") dotColor = "bg-blue-500";
  if (column.id === "Aprovado") dotColor = "bg-green-500";
  if (column.id === "Revisão Interna") dotColor = "bg-purple-500";
  if (column.id === "Ajustes Solicitados") dotColor = "bg-orange-500";
  if (column.id === "Aguardando Aprovação") dotColor = "bg-yellow-500";

  return (
    <div className="flex flex-col w-80 shrink-0 h-full min-h-0">
      <div className="flex items-center justify-between mb-4 px-1 shrink-0">
        <h3 className="text-sm font-bold text-slate-700 uppercase flex items-center gap-2 tracking-wider">
          <span className={`w-2 h-2 rounded-full ${dotColor}`}></span> 
          {column.title}
        </h3>
        <span className="text-xs font-bold text-slate-400 bg-slate-200/50 px-2 py-0.5 rounded-full">
          {tasks.length}
        </span>
      </div>

      <Droppable droppableId={column.id}>
        {(provided, snapshot) => (
          <div
            {...provided.droppableProps}
            ref={provided.innerRef}
            className={`flex-1 min-h-0 overflow-y-auto bg-slate-200/30 rounded-xl p-3 flex flex-col gap-3 transition-colors ${
              snapshot.isDraggingOver ? "bg-slate-200/50" : ""
            }`}
          >
            {tasks.map((task, index) => (
              <KanbanCard key={task.id} task={task} index={index} />
            ))}
            {provided.placeholder}
          </div>
        )}
      </Droppable>
    </div>
  );
}
GENESIS_HUB_EOF_7q1z9

mkdir -p "components/layout"
cat > "components/layout/sidebar.tsx" << 'GENESIS_HUB_EOF_7q1z9'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { LayoutDashboard, KanbanSquare, ListTodo, Settings, Users, LogOut } from "lucide-react";
import { useStore } from "@/lib/store";
import { LOGO_URL } from "@/lib/branding";

const NAV_ITEMS = [
  { name: "Dashboard", href: "/", icon: LayoutDashboard },
  { name: "Kanban", href: "/kanban", icon: KanbanSquare },
  { name: "Todas as Tarefas", href: "/tasks", icon: ListTodo },
];

const ADMIN_ITEMS = [
  { name: "Configurações", href: "/admin/settings", icon: Settings },
];

export function Sidebar({ isOpen, setIsOpen, isMobile }: { isOpen: boolean; setIsOpen: (val: boolean) => void; isMobile: boolean }) {
  const pathname = usePathname();
  const { currentUser, signOut } = useStore();

  const isAdminOrGestor = currentUser?.role === 'Admin' || currentUser?.role === 'Gestor';

  return (
    <aside className={cn(
      "bg-slate-900 flex flex-col border-r border-slate-200 h-full overflow-hidden transition-all duration-300",
      isOpen ? "w-64" : "w-16"
    )}>
      <div className={cn("p-4 border-b border-slate-800 flex items-center h-16", isOpen ? "justify-between" : "justify-center")}>
        <div className={cn("flex items-center gap-3", !isOpen && "hidden")}>
          <img src={LOGO_URL} alt="Genesis Hub" className="h-8 object-contain" />
        </div>
        {!isOpen && (
          <img src={LOGO_URL} alt="Genesis Hub" className="h-8 w-8 object-cover rounded-lg" />
        )}
      </div>

      <nav className="flex-1 py-4 flex flex-col gap-1 px-3 overflow-y-auto">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.name}
              href={item.href}
              title={item.name}
              className={cn(
                "flex items-center rounded-md text-sm font-medium transition-colors h-10",
                isOpen ? "px-3 gap-3" : "justify-center",
                isActive 
                  ? "bg-slate-800 text-white" 
                  : "text-slate-400 hover:bg-slate-800 hover:text-white"
              )}
            >
              <item.icon className={cn("shrink-0", isOpen ? "w-5 h-5" : "w-6 h-6", isActive ? "opacity-100" : "opacity-80")} />
              {isOpen && <span className="truncate">{item.name}</span>}
            </Link>
          );
        })}

        {isAdminOrGestor && (
          <>
            <div className={cn("mt-6 mb-2 px-3 text-[10px] font-bold text-slate-500 uppercase tracking-wider", !isOpen && "hidden text-center")}>
              {isOpen ? "Gestão" : "..."}
            </div>
            {ADMIN_ITEMS.map((item) => {
              const isActive = pathname.startsWith(item.href);
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  title={item.name}
                  className={cn(
                    "flex items-center rounded-md text-sm font-medium transition-colors h-10",
                    isOpen ? "px-3 gap-3" : "justify-center",
                    isActive 
                      ? "bg-slate-800 text-white" 
                      : "text-slate-400 hover:bg-slate-800 hover:text-white"
                  )}
                >
                  <item.icon className={cn("shrink-0", isOpen ? "w-5 h-5" : "w-6 h-6", isActive ? "opacity-100" : "opacity-80")} />
                  {isOpen && <span className="truncate">{item.name}</span>}
                </Link>
              );
            })}
          </>
        )}
      </nav>

      <div className="p-4 border-t border-slate-800 flex flex-col gap-4">
        {currentUser && (
          <div className={cn("flex items-center", isOpen ? "gap-3 justify-between" : "justify-center flex-col gap-2")}>
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold text-xs border border-blue-500/40 shrink-0">
                {currentUser.name ? currentUser.name.split(' ').map((n: string) => n[0]).join('').substring(0, 2).toUpperCase() : 'U'}
              </div>
              {isOpen && (
                <div className="flex flex-col truncate max-w-[120px]">
                  <span className="text-xs font-semibold text-white truncate">{currentUser.name}</span>
                  <span className="text-[10px] text-slate-500 uppercase truncate">{currentUser.role}</span>
                </div>
              )}
            </div>
            <button 
              onClick={signOut}
              title="Sair"
              className={cn("text-slate-500 hover:text-red-400 transition-colors", !isOpen && "mt-2")}
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>
    </aside>
  );
}
GENESIS_HUB_EOF_7q1z9

mkdir -p "app/forgot-password"
cat > "app/forgot-password/page.tsx" << 'GENESIS_HUB_EOF_7q1z9'
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
    <div className="flex h-screen w-full items-center justify-center bg-slate-50">
      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-8 border border-slate-100">
        <div className="flex flex-col items-center mb-8">
          <img src={LOGO_URL} alt="Genesis Hub" className="h-12 object-contain mb-4" />
          <h1 className="text-2xl font-bold text-slate-800">Recuperar Senha</h1>
          <p className="text-sm text-slate-500 text-center">Informe seu e-mail para receber um link de recuperação.</p>
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
            <a href="/login" className="text-sm text-blue-600 hover:underline">Voltar para o Login</a>
          </div>
        </form>
      </div>
    </div>
  );
}
GENESIS_HUB_EOF_7q1z9

mkdir -p "app/reset-password"
cat > "app/reset-password/page.tsx" << 'GENESIS_HUB_EOF_7q1z9'
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
GENESIS_HUB_EOF_7q1z9

mkdir -p "app/login"
cat > "app/login/page.tsx" << 'GENESIS_HUB_EOF_7q1z9'
"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { Mail, Lock, Eye, EyeOff, ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { LOGO_URL } from "@/lib/branding";

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
          <img src={LOGO_URL} alt="Genesis Hub" className="h-9 object-contain" />
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
            <img src={LOGO_URL} alt="Genesis Hub" className="h-10 object-contain" />
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
GENESIS_HUB_EOF_7q1z9

mkdir -p "app/invite"
cat > "app/invite/page.tsx" << 'GENESIS_HUB_EOF_7q1z9'
"use client";
import { useState, useEffect, Suspense } from "react";
import { supabase } from "@/lib/supabase";
import { toast } from "sonner";
import { useRouter, useSearchParams } from "next/navigation";
import { Mail, Lock, Eye, EyeOff, ArrowRight, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";
import { LOGO_URL } from "@/lib/branding";

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
          <img src={LOGO_URL} alt="Genesis Hub" className="h-11 object-contain mb-5" />
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
GENESIS_HUB_EOF_7q1z9

mkdir -p "app/api/notify"
cat > "app/api/notify/route.ts" << 'GENESIS_HUB_EOF_7q1z9'
import { NextResponse } from "next/server";
import { LOGO_URL } from "@/lib/branding";

// Envia e-mail de notificação via Resend. A RESEND_API_KEY nunca é exposta
// ao navegador — só existe aqui no servidor, igual à SUPABASE_SERVICE_ROLE_KEY
// usada em /api/invite.
export async function POST(req: Request) {
  try {
    const { to, title, message, taskId, recipientName } = await req.json();

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

    // Se veio o ID da demanda, o botão leva direto pra ela (mesmo deep-link
    // que o sino usa) em vez de só abrir o Kanban genérico.
    const targetUrl = taskId ? `${appUrl}/kanban?task=${taskId}` : `${appUrl}/kanban`;
    const firstName = recipientName ? String(recipientName).split(" ")[0] : null;

    // E-mail escuro, com a MESMA paleta da tela de login (#0b1430, azul
    // blue-600/blue-400). As duas metatags de color-scheme são essenciais:
    // sem elas, o Gmail (principalmente no app) "acha" que precisa inverter
    // as cores no modo escuro do celular, e faz isso pela metade — clareia
    // o fundo mas não ajusta a logo/texto, ficando ilegível. Com elas, o
    // Gmail entende que o e-mail já foi feito pra modo escuro e não mexe.
    // A estrutura em <table> (em vez de <div>) é o padrão da indústria pra
    // e-mail, porque clientes de e-mail (Gmail, Outlook, Apple Mail) cada
    // um respeita um pedaço diferente do CSS — tabela com bgcolor é o que
    // funciona de forma consistente em todos.
    const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta name="color-scheme" content="dark" />
<meta name="supported-color-schemes" content="dark" />
<title>${title}</title>
</head>
<body style="margin:0; padding:0; background-color:#0b1430;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0b1430;">
    <tr>
      <td align="center" style="padding:40px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px; background-color:#111a3d; border:1px solid rgba(255,255,255,0.08); border-radius:16px;">
          <tr>
            <td style="padding:32px; font-family:Arial,Helvetica,sans-serif;">
              <img src="${LOGO_URL}" alt="Genesis Hub" width="140" style="display:block; margin:0 0 24px; border:0;" />
              <p style="color:#60A5FA; font-size:11px; letter-spacing:1.5px; text-transform:uppercase; margin:0 0 10px;">Genesis Hub</p>
              ${firstName ? `<p style="color:#93C5FD; font-size:14px; margin:0 0 6px;">Olá, ${firstName}</p>` : ""}
              <h2 style="color:#ffffff; font-size:20px; margin:0 0 14px;">${title}</h2>
              ${message ? `<p style="color:#BFDBFE; font-size:14px; line-height:1.6; margin:0 0 26px;">${message}</p>` : ""}
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background-color:#2563EB; border-radius:8px;">
                    <a href="${targetUrl}" style="display:inline-block; padding:13px 22px; font-size:14px; font-weight:600; color:#ffffff; text-decoration:none;">
                      Ver demanda no Genesis Hub
                    </a>
                  </td>
                </tr>
              </table>
              <p style="color:#5b6b99; font-size:11px; margin:28px 0 0;">Você recebeu esse e-mail porque está envolvido(a) nessa demanda no Genesis Hub.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

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
GENESIS_HUB_EOF_7q1z9

echo "Todos os arquivos foram atualizados."
git add -A
git commit -m "nova etapa Atribuido A Fazer, logo via storage, correcao dashboard"
git push
echo "Commit e push feitos. Aguarde o deploy da Vercel."