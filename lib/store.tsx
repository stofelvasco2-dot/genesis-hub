"use client";
import React, { createContext, useContext, useState, useEffect } from "react";
import { Task, User, Category, Priority, Status, Comment, TimelineEvent } from "./types";
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
  isLoaded: boolean;
  addTask: (task: Omit<Task, "id" | "createdAt" | "comments" | "timeline" | "updatedAt">) => Promise<void>;
  updateTask: (id: string, updates: Partial<Task>, modifierId: string) => Promise<void>;
  addComment: (taskId: string, userId: string, text: string) => Promise<void>;
  moveTaskStatus: (taskId: string, newStatus: string, modifierId: string) => Promise<void>;
  refreshTasks: () => Promise<void>;
  signOut: () => Promise<void>;
  addOption: (type: 'departments' | 'categories' | 'priorities', name: string) => Promise<void>;
  removeOption: (type: 'departments' | 'categories' | 'priorities', name: string) => Promise<void>;
};

const StoreContext = createContext<StoreContextType | undefined>(undefined);

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const [users, setUsers] = useState<User[]>([]);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [tasks, setTasks] = useState<Task[]>([]);
  
  const [departments, setDepartments] = useState<string[]>([]);
  const [categories, setCategories] = useState<string[]>([]);
  const [priorities, setPriorities] = useState<string[]>([]);
  const [statuses, setStatuses] = useState<string[]>([]);
  const [roles, setRoles] = useState<string[]>([]);
  
  const [isLoaded, setIsLoaded] = useState(false);
  const router = useRouter();
  const pathname = usePathname();

  const fetchData = async () => {
    if (!supabase) return;
    setIsLoaded(false);
    
    const [usersRes, tasksRes, deptRes, catRes, prioRes, statRes, roleRes] = await Promise.all([
      supabase.from('users').select('*'),
      supabase.from('tasks').select('*, comments(*), timeline_events(*)'),
      supabase.from('departments').select('name'),
      supabase.from('categories').select('name'),
      supabase.from('priorities').select('name'),
      supabase.from('statuses').select('name'),
      supabase.from('roles').select('name'),
    ]);

    if (usersRes.data) setUsers(usersRes.data);
    if (deptRes.data) setDepartments(deptRes.data.map(d => d.name));
    if (catRes.data) setCategories(catRes.data.map(c => c.name));
    if (prioRes.data) setPriorities(prioRes.data.map(p => p.name));
    if (statRes.data) setStatuses(statRes.data.map(s => s.name));
    if (roleRes.data) setRoles(roleRes.data.map(r => r.name));

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
  };

  useEffect(() => {
    const initAuth = async () => {
      if (!supabase) {
        setIsLoaded(true);
        return;
      }
      
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session?.user) {
        const { data: existingUser } = await supabase!.from("users").select("*").eq("email", session.user.email).single();
        if (existingUser) {
          setCurrentUser(existingUser);
        } else if (session.user.email === "gustavostofel21@gmail.com") {
          const newUser = {
            id: session.user.id,
            email: session.user.email,
            name: "Gustavo",
            role: "Admin",
          };
          const { data: createdUser } = await supabase!.from("users").insert([newUser]).select().single();
          if (createdUser) setCurrentUser(createdUser);
        } else {
          toast.error("Usuário não encontrado na base de dados do sistema.");
          await supabase!.auth.signOut();
        }
        fetchData();
      } else {
        setIsLoaded(true);
        const publicRoutes = ['/login', '/forgot-password', '/reset-password', '/invite'];
        if (!publicRoutes.includes(pathname)) {
          router.push('/login');
        }
      }

      const { data: authListener } = supabase.auth.onAuthStateChange(async (event, session) => {
        if (event === 'SIGNED_IN' && session?.user) {
          const { data: existingUser } = await supabase!.from("users").select("*").eq("email", session.user.email).single();
          if (existingUser) {
            setCurrentUser(existingUser);
          } else if (session.user.email === "gustavostofel21@gmail.com") {
            const newUser = {
              id: session.user.id,
              email: session.user.email,
              name: "Gustavo",
              role: "Admin",
            };
            const { data: createdUser } = await supabase!.from("users").insert([newUser]).select().single();
            if (createdUser) setCurrentUser(createdUser);
          } else {
            toast.error("Usuário não encontrado na base de dados do sistema.");
            await supabase!.auth.signOut();
          }
          fetchData();
          if (pathname === '/login') {
            router.push('/');
          }
        } else if (event === 'SIGNED_OUT') {
          setCurrentUser(null);
          setTasks([]);
          router.push('/login');
        }
      });

      return () => {
        authListener.subscription.unsubscribe();
      };
    };
    initAuth();
  }, [pathname, router]);

  const refreshTasks = async () => {
    await fetchData();
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

    await refreshTasks();
  };

  const updateTask = async (id: string, updates: Partial<Task>, modifierId: string) => {
    if (!supabase) return;
    
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

    const { error } = await supabase.from('tasks').update(dbUpdates).eq('id', id);
    
    if (error) {
      toast.error('Erro ao atualizar: ' + error.message);
      return;
    }

    const currentTask = tasks.find(t => t.id === id);
    if (!currentTask) return;

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

    await refreshTasks();
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
      description: 'Comentário adicionado.'
    }]);

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

  return (
    <StoreContext.Provider value={{ 
      users, currentUser, tasks, departments, categories, priorities, statuses, roles, 
      isLoaded, addTask, updateTask, addComment, moveTaskStatus, refreshTasks, signOut,
      addOption, removeOption
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
