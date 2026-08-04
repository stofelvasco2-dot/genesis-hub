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
      // Checa se essa tarefa já foi adicionada por outro caminho (o evento
      // de tempo real pode chegar e inserir uma versão "resumida" dela
      // antes desse trecho terminar sua própria busca). Se já existir,
      // substitui em vez de duplicar; senão, adiciona normalmente.
      setTasks(prev => {
        const idx = prev.findIndex(t => t.id === formatted.id);
        if (idx !== -1) {
          return prev.map((t, i) => (i === idx ? formatted : t));
        }
        return [formatted, ...prev];
      });

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
    // Cobre tanto quem manda só {assigneeId} (patch parcial) quanto o modal
    // de edição, que sempre reenvia o status atual junto (nesse caso,
    // "sem mudança de status" significa updates.status === status atual,
    // não necessariamente undefined).
    if (
      currentTask.status === "Triagem" &&
      (updates.status === undefined || updates.status === currentTask.status) &&
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

    // Antes isso era if/senão-se/senão: quando status E responsável mudavam
    // JUNTOS na mesma chamada (caso comum: atribuir alguém em Triagem avança
    // o status sozinho), só o evento de status era gravado — o de "atribuída
    // para fulano" era descartado. Agora os dois são checados e gravados
    // de forma independente, cada mudança real vira sua própria linha no
    // histórico.
    const newTimelineEntries: TimelineEvent[] = [];

    if (updates.status && updates.status !== currentTask.status) {
      const description = `Status alterado de ${currentTask.status} para ${updates.status}.`;
      const { data } = await supabase.from('timeline_events').insert([{
        task_id: id, type: 'status_changed', user_id: modifierId, description,
      }]).select().single();
      if (data) newTimelineEntries.push({ id: data.id, userId: data.user_id, type: data.type, description: data.description, createdAt: data.created_at });
    }

    if (updates.assigneeId !== undefined && updates.assigneeId !== currentTask.assigneeId) {
      const newAssignee = users.find(u => u.id === updates.assigneeId)?.name || "Alguém";
      const description = updates.assigneeId ? `Atribuída para ${newAssignee}.` : `Responsável removido.`;
      const { data } = await supabase.from('timeline_events').insert([{
        task_id: id, type: 'assigned', user_id: modifierId, description,
      }]).select().single();
      if (data) newTimelineEntries.push({ id: data.id, userId: data.user_id, type: data.type, description: data.description, createdAt: data.created_at });
    }

    if (newTimelineEntries.length === 0) {
      const { data } = await supabase.from('timeline_events').insert([{
        task_id: id, type: 'other', user_id: modifierId, description: `Tarefa atualizada.`,
      }]).select().single();
      if (data) newTimelineEntries.push({ id: data.id, userId: data.user_id, type: data.type, description: data.description, createdAt: data.created_at });
    }

    // Atualização otimista: aplica a mudança localmente na hora, sem esperar
    // nem recarregar TODAS as tabelas do banco. A tela nunca "pisca". Isso
    // agora inclui os eventos de histórico novos, pra aparecerem sem
    // precisar dar F5.
    setTasks(prev => prev.map(t => (t.id === id
      ? { ...t, ...updates, ...localExtras, timeline: [...t.timeline, ...newTimelineEntries] }
      : t)));

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