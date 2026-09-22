"use client";

import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Task, Category, Priority, Department, Status, User } from "@/lib/types";
import { X, CalendarIcon, Save, Edit2, ExternalLink, MessageSquare, Activity, Users, Plus, Check } from "lucide-react";
import { useState, useEffect, useRef } from "react";
import { useStore } from "@/lib/store";
import { format, parseISO, differenceInDays } from "date-fns";
import { ptBR } from "date-fns/locale";
import { cn } from "@/lib/utils";
import { toast } from "sonner";

interface TaskDetailModalProps {
  task: Task;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}









export function TaskDetailModal({ task, open, onOpenChange }: TaskDetailModalProps) {
  const {
    updateTask, currentUser, users, addComment, statuses, categories, priorities, departments,
    addTaskCollaborator, removeTaskCollaborator, setCollaboratorDone, setCollaboratorCategoryByUser,
  } = useStore();

  const [isEditing, setIsEditing] = useState(false);
  const [editedTask, setEditedTask] = useState<Partial<Task>>({});
  const [commentText, setCommentText] = useState("");
  const [newCollaboratorId, setNewCollaboratorId] = useState("");
  const [newCollaboratorCategory, setNewCollaboratorCategory] = useState("");
  const [mentionQuery, setMentionQuery] = useState<string | null>(null);
  const [mentionedUserIds, setMentionedUserIds] = useState<string[]>([]);
  const [pendingMentions, setPendingMentions] = useState<User[]>([]);
  const [pendingCategories, setPendingCategories] = useState<Record<string, string>>({});
  const [savingPendingCategories, setSavingPendingCategories] = useState(false);
  const commentTextareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (open) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setIsEditing(false);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setEditedTask({
        title: task.title,
        description: task.description,
        category: task.category,
        priority: task.priority,
        dueDate: task.dueDate,
        referenceLinks: task.referenceLinks,
        notes: task.notes,
        requesterName: task.requesterName,
        department: task.department,
        externalConsultant: task.externalConsultant,
        internalConsultant: task.internalConsultant,
        status: task.status,
        assigneeId: task.assigneeId
      });
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setCommentText("");
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setNewCollaboratorId("");
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setNewCollaboratorCategory("");
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setMentionedUserIds([]);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setMentionQuery(null);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setPendingMentions([]);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setPendingCategories({});
    }
  }, [open, task]);

  const handleSave = () => {
    if (!currentUser) return;
    updateTask(task.id, editedTask, currentUser.id);
    toast.success("Solicitação atualizada com sucesso!");
    setIsEditing(false);
  };

  // Quem pode adicionar/remover pessoas envolvidas na demanda — mesma regra
  // de quem já pode editar a task (admin/gestor, responsável ou solicitante).
  const canManageCollaborators = currentUser?.role === "Admin" || currentUser?.role === "Gestor"
    || currentUser?.id === task.assigneeId || currentUser?.id === task.requesterId;

  const handleAddCollaborator = async () => {
    if (!newCollaboratorId || !newCollaboratorCategory || !currentUser) return;
    await addTaskCollaborator(task.id, newCollaboratorId, newCollaboratorCategory, currentUser.id);
    setNewCollaboratorId("");
    setNewCollaboratorCategory("");
  };

  const handleAddComment = async () => {
    if (!commentText.trim() || !currentUser) return;

    // Quem foi mencionado mas ainda não tinha nenhum vínculo com a demanda
    // (não é responsável, solicitante nem já estava em Pessoas Envolvidas)
    // acabou de ser incluído automaticamente, sem categoria — junta pra
    // perguntar a categoria logo depois de enviar, em vez de deixar
    // "Sem categoria" parado até alguém lembrar de corrigir.
    const newlyMentioned = mentionedUserIds
      .filter(id => id !== currentUser.id)
      .filter(id => id !== task.assigneeId && id !== task.requesterId && !task.collaborators.some(c => c.userId === id))
      .map(id => users.find(u => u.id === id))
      .filter((u): u is User => !!u);

    await addComment(task.id, currentUser.id, commentText.trim(), mentionedUserIds);
    setCommentText("");
    setMentionedUserIds([]);
    setMentionQuery(null);
    toast.success("Comentário adicionado!");

    if (newlyMentioned.length > 0) {
      setPendingMentions(newlyMentioned);
      setPendingCategories({});
    }
  };

  const handleSavePendingCategories = async () => {
    if (!currentUser) return;
    setSavingPendingCategories(true);
    for (const person of pendingMentions) {
      const category = pendingCategories[person.id];
      if (category) await setCollaboratorCategoryByUser(task.id, person.id, category);
    }
    setSavingPendingCategories(false);
    setPendingMentions([]);
    setPendingCategories({});
  };

  // Pessoas que dá pra @mencionar num comentário: qualquer colaborador ativo
  // do sistema (não só quem já está ligado a essa demanda específica) —
  // permite chamar alguém pra dar uma olhada mesmo sem adicioná-lo formalmente.
  const mentionCandidates = users
    .filter(u => u.active !== false && u.id !== currentUser?.id)
    .sort((a, b) => a.name.localeCompare(b.name));
  const mentionResults = mentionQuery !== null
    ? mentionCandidates.filter(u => u.name.toLowerCase().includes(mentionQuery.toLowerCase())).slice(0, 6)
    : [];

  const handleCommentChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const val = e.target.value;
    setCommentText(val);
    const cursor = e.target.selectionStart ?? val.length;
    const uptoCursor = val.slice(0, cursor);
    const match = uptoCursor.match(/(?:^|\s)@([^\s@]*)$/);
    setMentionQuery(match ? match[1] : null);
  };

  const handleSelectMention = (person: User) => {
    const cursor = commentTextareaRef.current?.selectionStart ?? commentText.length;
    const uptoCursor = commentText.slice(0, cursor);
    const afterCursor = commentText.slice(cursor);
    const match = uptoCursor.match(/(?:^|\s)@([^\s@]*)$/);
    if (!match) return;
    const prefix = uptoCursor.slice(0, uptoCursor.length - match[0].length);
    const leadingSpace = match[0].startsWith(' ') ? ' ' : '';
    setCommentText(`${prefix}${leadingSpace}@${person.name} ${afterCursor}`);
    setMentionedUserIds(prev => (prev.includes(person.id) ? prev : [...prev, person.id]));
    setMentionQuery(null);
  };

  const currentTask = isEditing ? { ...task, ...editedTask } : task;
  const dueDate = currentTask.dueDate ? parseISO(currentTask.dueDate) : undefined;
  
  const linksString = (currentTask.referenceLinks || []).join('\n');

  const handleLinksChange = (val: string) => {
    const arr = val.split(/[\n, ]+/).map(l => l.trim()).filter(l => l.length > 0);
    setEditedTask({...editedTask, referenceLinks: arr});
  };

  const createdDate = parseISO(task.createdAt);
  const totalDays = dueDate ? (differenceInDays(dueDate, createdDate) || 1) : 1;
  const daysPassed = differenceInDays(new Date(), createdDate);
  const progressPercent = Math.min(Math.max((daysPassed / totalDays) * 100, 0), 100);
  const daysLeft = dueDate ? differenceInDays(dueDate, new Date()) : 0;
  
  const currentAssignee = users.find(u => u.id === currentTask.assigneeId);

  return (
    <>
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-[1200px] w-[95vw] max-h-[95vh] sm:h-[90vh] flex flex-col p-0 overflow-y-auto sm:overflow-hidden bg-slate-50 dark:bg-slate-950 border-none shadow-2xl font-sans sm:rounded-2xl [&>button]:hidden">
        
        {/* Header - Glassmorphism (Azul translúcido, desfocado) */}
        <div className="flex-none px-5 py-4 sm:px-8 sm:py-5 bg-blue-600/10 backdrop-blur-xl border-b border-blue-600/10 flex flex-col sm:flex-row sm:items-center justify-between gap-4 z-50">
          <div className="flex flex-col gap-2 flex-1 min-w-0">
            <div className="flex items-center gap-3">
              <span className="text-xs font-mono font-bold bg-blue-500/20 text-blue-700 dark:text-blue-400 px-2 py-1 rounded shadow-sm border border-blue-500/10">#{task.id.slice(0,6).toUpperCase()}</span>
              {isEditing ? (
                <Select value={currentTask.status} onValueChange={(val) => setEditedTask({...editedTask, status: val as Status})}>
                  <SelectTrigger className="h-7 text-xs font-bold bg-white dark:bg-slate-900/50 backdrop-blur-sm border-blue-500/20 text-blue-800 w-auto">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {statuses.map(s => <SelectItem key={s} value={s} className="text-xs">{s}</SelectItem>)}
                  </SelectContent>
                </Select>
              ) : (
                <span className="px-2.5 py-1 rounded text-[10px] font-bold uppercase tracking-wider bg-blue-500/20 text-blue-700 dark:text-blue-400 shadow-sm border border-blue-500/10">{currentTask.status}</span>
              )}
            </div>
            
            {isEditing ? (
              <Input 
                value={currentTask.title} 
                onChange={e => setEditedTask({...editedTask, title: e.target.value})}
                className="h-10 text-xl font-bold w-full max-w-2xl bg-white dark:bg-slate-900/60 backdrop-blur-md border-blue-500/20 focus-visible:ring-blue-500"
              />
            ) : (
              <DialogTitle className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white truncate pr-4 drop-shadow-sm">{currentTask.title}</DialogTitle>
            )}

            <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-slate-700 dark:text-slate-200 font-medium mt-1">
              <span className="flex items-center gap-1.5 bg-white dark:bg-slate-900/40 px-2 py-1 rounded-md border border-white/20 shadow-sm">
                <span className="text-slate-500 dark:text-slate-400">Solicitante:</span> 
                <span className="font-bold text-slate-900 dark:text-white">{currentTask.requesterName}</span>
              </span>
              <span className="flex items-center gap-1.5 bg-white dark:bg-slate-900/40 px-2 py-1 rounded-md border border-white/20 shadow-sm">
                <span className="text-slate-500 dark:text-slate-400">Última atualização:</span> 
                <span className="font-bold text-slate-900 dark:text-white">{format(parseISO(task.updatedAt || task.createdAt), "dd/MM/yyyy HH:mm", { locale: ptBR })}</span>
              </span>
            </div>
          </div>
          
          <div className="flex items-center gap-3 shrink-0 self-start sm:self-center">
            {!isEditing ? (
              <Button onClick={() => setIsEditing(true)} className="bg-white dark:bg-slate-900/60 hover:bg-white/90 text-blue-800 border border-blue-500/20 backdrop-blur-md shadow-sm h-10 gap-2 font-bold px-5 transition-all">
                <Edit2 className="w-4 h-4" /> Editar
              </Button>
            ) : (
              <Button onClick={handleSave} className="bg-blue-600 hover:bg-blue-700 text-white shadow-md h-10 gap-2 font-bold px-5 transition-all">
                <Save className="w-4 h-4" /> Salvar
              </Button>
            )}
            <Button type="button" variant="ghost" size="icon" onClick={() => onOpenChange(false)} className="h-10 w-10 rounded-full bg-white dark:bg-slate-900/40 hover:bg-white/80 text-slate-700 dark:text-slate-200 backdrop-blur-md border border-white/40 shadow-sm transition-all">
              <X className="w-4 h-4" />
            </Button>
          </div>
        </div>
        
        {/* Main Content Area - Fixing scroll by using flex-1 properly */}
        <div className="flex-1 w-full bg-slate-50 dark:bg-slate-950/50 sm:overflow-y-auto">
          
          {/* Executive Header - Underneath main title */}
          <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800/60 shadow-sm sticky top-0 z-40">
            <div className="flex overflow-x-auto p-4 sm:px-8">
              <div className="flex flex-nowrap items-center gap-6 w-full text-sm min-w-max">
                
                {/* Responsável */}
                <div className="flex flex-col gap-1.5 min-w-[150px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Responsável</span>
                  {isEditing ? (
                    <Select value={currentTask.assigneeId || "unassigned"} onValueChange={(val) => setEditedTask({...editedTask, assigneeId: (val === "unassigned" ? undefined : val) as string | undefined})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50 dark:bg-slate-950"><SelectValue>{currentTask.assigneeId ? users.find(u => u.id === currentTask.assigneeId)?.name : "Sem responsável"}</SelectValue></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="unassigned" className="text-xs">Sem responsável</SelectItem>
                        {users
                          .filter(u => u.active !== false || u.id === currentTask.assigneeId)
                          .map(u => (
                            <SelectItem key={u.id} value={u.id} className="text-xs">{u.name}{u.active === false ? " (inativo)" : ""}</SelectItem>
                          ))}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="font-bold text-slate-800 dark:text-slate-100 h-8 flex items-center gap-2">
                      {currentAssignee ? (
                        <>
                          <div className="w-6 h-6 rounded-full bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400 flex items-center justify-center text-[10px] uppercase border border-blue-200">
                            {currentAssignee.name.split(' ').map(n=>n[0]).join('').substring(0,2)}
                          </div>
                          <span className="truncate text-sm">{currentAssignee.name}</span>
                        </>
                      ) : (
                        <span className="text-slate-400 dark:text-slate-500 italic text-sm">Nenhum</span>
                      )}
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* Categoria */}
                <div className="flex flex-col gap-1.5 min-w-[130px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Categoria</span>
                  {isEditing ? (
                    <Select value={currentTask.category} onValueChange={(val) => setEditedTask({...editedTask, category: val as Category})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50 dark:bg-slate-950"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {categories.map(c => <SelectItem key={c} value={c} className="text-xs">{c}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="font-bold text-slate-800 dark:text-slate-100 h-8 flex items-center text-sm">{currentTask.category}</div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* Prioridade */}
                <div className="flex flex-col gap-1.5 min-w-[110px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Prioridade</span>
                  {isEditing ? (
                    <Select value={currentTask.priority} onValueChange={(val) => setEditedTask({...editedTask, priority: val as Priority})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50 dark:bg-slate-950"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {priorities.map(p => <SelectItem key={p} value={p} className="text-xs">{p}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="h-8 flex items-center">
                      <span className={cn(
                        "px-2.5 py-1 rounded text-xs font-bold uppercase tracking-wider shadow-sm",
                        currentTask.priority === 'Alta' ? 'bg-orange-100 dark:bg-orange-500/15 text-orange-700 dark:text-orange-400 border border-orange-200' : 
                        currentTask.priority === 'Urgente' ? 'bg-red-100 dark:bg-red-500/15 text-red-700 dark:text-red-400 border border-red-200' : 'bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-800'
                      )}>
                        {currentTask.priority}
                      </span>
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* Prazo */}
                <div className="flex flex-col gap-1.5 min-w-[140px]">
                  <span className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Prazo Solicitado</span>
                  {isEditing ? (
                    <Popover>
                      <PopoverTrigger className={cn("flex h-8 w-full items-center justify-start rounded-md border border-input bg-slate-50 dark:bg-slate-950 px-2 py-1 text-xs font-semibold shadow-sm", !dueDate && "text-muted-foreground")}>
                        <CalendarIcon className="mr-2 h-3.5 w-3.5" />
                        {dueDate ? format(dueDate, "dd/MM/yyyy") : <span>Data</span>}
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0">
                        <Calendar mode="single" selected={dueDate} onSelect={(date) => setEditedTask({...editedTask, dueDate: date?.toISOString()})} />
                      </PopoverContent>
                    </Popover>
                  ) : (
                    <div className="h-8 flex items-center font-bold text-slate-800 dark:text-slate-100 gap-2 text-sm">
                      <CalendarIcon className="w-4 h-4 text-slate-400 dark:text-slate-500" />
                      {dueDate ? format(dueDate, "dd/MM/yyyy") : "Não definido"}
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div>

                {/* SLA / Dias Restantes */}
                <div className="flex flex-col gap-1.5 min-w-[150px] max-w-[200px] flex-1">
                  <div className="flex justify-between items-center text-[10px] font-bold uppercase tracking-wider">
                    <span className="text-slate-400 dark:text-slate-500">Dias Restantes</span>
                    <span className={daysLeft < 0 ? 'text-red-600 dark:text-red-400' : 'text-slate-700 dark:text-slate-200'}>{daysLeft < 0 ? 'Atrasado' : `${daysLeft} dias`}</span>
                  </div>
                  <div className="h-8 flex flex-col justify-center w-full gap-1.5">
                    <div className="h-2 w-full bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden border border-slate-200 dark:border-slate-800/50 shadow-inner">
                      <div 
                        className={cn(
                          "h-full rounded-full transition-all duration-500",
                          daysLeft < 0 ? 'bg-red-500' : progressPercent > 80 ? 'bg-amber-500' : 'bg-emerald-500'
                        )} 
                        style={{ width: `${progressPercent}%` }}
                      />
                    </div>
                  </div>
                </div>
                <div className="w-px h-10 bg-slate-200 dark:bg-slate-700/80"></div></div>
            </div>
          </div>

          {/* Main Body Content */}
          <div className="p-4 sm:p-6 lg:p-8 max-w-6xl mx-auto space-y-8 pb-16">
            
            {/* Briefing Section */}
            <div className="space-y-6">
              
              <div className="space-y-3">
                <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Descrição Completa</Label>
                {isEditing ? (
                  <Textarea 
                    value={currentTask.description} 
                    onChange={e => setEditedTask({...editedTask, description: e.target.value})}
                    className="min-h-[150px] resize-none bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 shadow-sm text-sm"
                  />
                ) : (
                  <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-5 sm:p-6 text-sm text-slate-800 dark:text-slate-100 whitespace-pre-wrap leading-relaxed">
                    {currentTask.description}
                  </div>
                )}
              </div>

              {/* Pessoas Envolvidas: além do responsável principal, quem mais
                  participa dessa demanda (Designer + Videomaker etc.), cada
                  um marcando quando a própria parte está pronta. */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-2">
                    <Users className="w-4 h-4" /> Pessoas Envolvidas
                  </Label>
                  {task.collaborators.length > 0 && (
                    <span className="text-[11px] font-bold text-slate-500 dark:text-slate-400">
                      {task.collaborators.filter(c => c.done).length}/{task.collaborators.length} partes prontas
                    </span>
                  )}
                </div>
                <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-4 sm:p-5 space-y-3">
                  {task.collaborators.length === 0 && (
                    <p className="text-sm text-slate-400 dark:text-slate-500 italic">
                      Só o responsável principal está nessa demanda. Adicione mais gente se ela precisar de outras funções (ex.: Designer + Videomaker).
                    </p>
                  )}
                  {task.collaborators.map(collab => {
                    const person = users.find(u => u.id === collab.userId);
                    const canToggle = collab.userId === currentUser?.id || canManageCollaborators;
                    return (
                      <div key={collab.id} className="flex items-center gap-3">
                        <button
                          type="button"
                          disabled={!canToggle}
                          onClick={() => currentUser && setCollaboratorDone(collab.id, task.id, !collab.done, currentUser.id)}
                          title={canToggle ? (collab.done ? "Marcar como pendente" : "Marcar minha parte como pronta") : "Só essa pessoa (ou admin/gestor) pode marcar"}
                          className={cn(
                            "w-5 h-5 rounded-md border-2 flex items-center justify-center shrink-0 transition-colors",
                            collab.done ? "bg-emerald-500 border-emerald-500" : "border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-950",
                            canToggle ? "cursor-pointer hover:border-emerald-400" : "cursor-not-allowed opacity-50"
                          )}
                        >
                          {collab.done && <Check className="w-3.5 h-3.5 text-white" />}
                        </button>
                        <div className="w-7 h-7 rounded-full bg-indigo-100 dark:bg-indigo-500/15 text-indigo-700 dark:text-indigo-400 flex items-center justify-center text-[10px] font-bold uppercase shrink-0">
                          {person?.name ? person.name.split(' ').map(n => n[0]).join('').substring(0, 2) : "?"}
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className={cn("text-sm font-semibold truncate", collab.done ? "text-slate-400 dark:text-slate-500 line-through" : "text-slate-800 dark:text-slate-100")}>
                            {person?.name || "Usuário removido"}
                          </p>
                        </div>
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0 bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400">
                          {collab.category || "Sem categoria"}
                        </span>
                        <span className={cn(
                          "text-[10px] font-bold px-2 py-0.5 rounded-full shrink-0",
                          collab.done ? "bg-emerald-100 dark:bg-emerald-500/15 text-emerald-700 dark:text-emerald-400" : "bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400"
                        )}>
                          {collab.done ? "Pronto" : "Pendente"}
                        </span>
                        {canManageCollaborators && (
                          <button
                            type="button"
                            onClick={() => removeTaskCollaborator(collab.id, task.id)}
                            className="text-slate-300 dark:text-slate-600 hover:text-red-500 shrink-0"
                            title="Remover da demanda"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    );
                  })}

                  {canManageCollaborators && (
                    <div className="flex flex-wrap items-center gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
                      <Select value={newCollaboratorId} onValueChange={(val) => setNewCollaboratorId(val || "")}>
                        <SelectTrigger className="h-9 text-xs flex-1 min-w-[160px]">
                          <SelectValue placeholder="Pessoa...">
                            {newCollaboratorId ? users.find(u => u.id === newCollaboratorId)?.name : undefined}
                          </SelectValue>
                        </SelectTrigger>
                        <SelectContent>
                          {users
                            .filter(u => u.active !== false && !task.collaborators.some(c => c.userId === u.id))
                            .map(u => (
                              <SelectItem key={u.id} value={u.id} className="text-xs">
                                {u.name}{u.tipo_usuario ? ` · ${u.tipo_usuario}` : ""}
                              </SelectItem>
                            ))}
                        </SelectContent>
                      </Select>
                      <Select value={newCollaboratorCategory} onValueChange={(val) => setNewCollaboratorCategory(val || "")}>
                        <SelectTrigger className="h-9 text-xs w-[170px] shrink-0"><SelectValue placeholder="Categoria da parte..." /></SelectTrigger>
                        <SelectContent>
                          {categories.map(c => <SelectItem key={c} value={c} className="text-xs">{c}</SelectItem>)}
                        </SelectContent>
                      </Select>
                      <Button size="sm" onClick={handleAddCollaborator} disabled={!newCollaboratorId || !newCollaboratorCategory} className="bg-indigo-600 hover:bg-indigo-700 h-9 shrink-0">
                        <Plus className="w-3.5 h-3.5 mr-1" /> Adicionar
                      </Button>
                    </div>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Links de Referência</Label>
                  {isEditing ? (
                    <Textarea 
                      value={linksString} 
                      onChange={e => handleLinksChange(e.target.value)}
                      placeholder="Cole os links de referência (Figma, Drive, etc) separados por vírgula ou linha"
                      className="min-h-[100px] resize-none bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 shadow-sm text-sm"
                    />
                  ) : (
                    <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-4 sm:p-5 text-sm text-slate-800 dark:text-slate-100 flex flex-col gap-3 min-h-[100px]">
                      {currentTask.referenceLinks && currentTask.referenceLinks.length > 0 ? (
                        currentTask.referenceLinks.map((link, i) => {
                          const isUrl = link.startsWith('http://') || link.startsWith('https://');
                          const href = isUrl ? link : `https://${link}`;
                          return (
                            <a key={i} href={href} target="_blank" rel="noopener noreferrer" className="text-blue-600 dark:text-blue-400 hover:text-blue-700 hover:underline inline-flex items-center gap-2 font-medium bg-blue-50 dark:bg-blue-500/10/50 hover:bg-blue-50 px-3 py-2 rounded-lg w-fit break-all transition-colors border border-blue-100">
                              <ExternalLink className="w-4 h-4 shrink-0" />
                              {link}
                            </a>
                          );
                        })
                      ) : (
                        <span className="text-slate-400 dark:text-slate-500 italic">Nenhum link fornecido.</span>
                      )}
                    </div>
                  )}
                </div>

                <div className="space-y-3">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Observações Extras</Label>
                  {isEditing ? (
                    <Textarea 
                      value={currentTask.notes || ""} 
                      onChange={e => setEditedTask({...editedTask, notes: e.target.value})}
                      className="min-h-[100px] resize-none bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 shadow-sm text-sm"
                      placeholder="Informações adicionais importantes..."
                    />
                  ) : (
                    <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-4 sm:p-5 text-sm text-slate-800 dark:text-slate-100 whitespace-pre-wrap min-h-[100px]">
                      {currentTask.notes || <span className="text-slate-400 dark:text-slate-500 italic">Nenhuma observação extra.</span>}
                    </div>
                  )}
                </div>
              </div>

            </div>

            {/* Interaction Section (Comments & Timeline) */}
            {!isEditing && (
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 pt-6 border-t border-slate-200 dark:border-slate-800">
                
                {/* Comments (2/3 width) */}
                <div className="lg:col-span-2 space-y-4">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-2">
                    <MessageSquare className="w-4 h-4" /> Comentários
                  </Label>
                  <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden flex flex-col">
                    <div className="p-4 sm:p-6 space-y-6 max-h-[600px] overflow-y-auto">
                      {task.comments.length === 0 ? (
                        <div className="text-center text-slate-400 dark:text-slate-500 text-sm italic py-8 bg-slate-50 dark:bg-slate-950 rounded-xl border border-dashed border-slate-200 dark:border-slate-800">Nenhum comentário ainda.</div>
                      ) : (
                        task.comments.map(comment => {
                          const user = users.find(u => u.id === comment.userId);
                          const isMe = user?.id === currentUser?.id;
                          return (
                            <div key={comment.id} className={`flex gap-3 ${isMe ? 'flex-row-reverse' : ''}`}>
                              <div className="w-9 h-9 rounded-full bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-800 flex items-center justify-center shrink-0 shadow-sm">
                                <span className="text-xs font-bold text-slate-600 dark:text-slate-300">
                                  {user?.name ? user.name.split(' ').map(n=>n[0]).join('').substring(0,2).toUpperCase() : "?"}
                                </span>
                              </div>
                              <div className={`flex flex-col max-w-[85%] ${isMe ? 'items-end' : 'items-start'}`}>
                                <div className="flex items-center gap-2 mb-1.5 px-1">
                                  <span className="text-xs font-bold text-slate-700 dark:text-slate-200">{user?.name}</span>
                                  <span className="text-[10px] text-slate-400 dark:text-slate-500 font-medium">{format(parseISO(comment.createdAt), "dd/MM/yyyy HH:mm")}</span>
                                </div>
                                <div className={`px-4 py-2.5 rounded-2xl text-sm shadow-sm ${isMe ? 'bg-blue-600 text-white rounded-tr-sm' : 'bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 rounded-tl-sm'}`}>
                                  {comment.text}
                                </div>
                              </div>
                            </div>
                          )
                        })
                      )}
                    </div>
                    <div className="p-3 sm:p-4 bg-slate-50 dark:bg-slate-950 border-t border-slate-100 dark:border-slate-800">
                      <div className="relative">
                        {mentionQuery !== null && mentionResults.length > 0 && (
                          <div className="absolute left-0 right-14 bottom-full mb-1 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-lg shadow-lg overflow-hidden z-10">
                            {mentionResults.map(person => (
                              <button
                                key={person.id}
                                type="button"
                                onMouseDown={(e) => { e.preventDefault(); handleSelectMention(person); }}
                                className="w-full flex items-center gap-2 px-3 py-2 text-left text-xs hover:bg-slate-50 dark:hover:bg-slate-800"
                              >
                                <div className="w-5 h-5 rounded-full bg-indigo-100 dark:bg-indigo-500/15 text-indigo-700 dark:text-indigo-400 flex items-center justify-center text-[9px] font-bold uppercase shrink-0">
                                  {person.name.split(' ').map(n => n[0]).join('').substring(0, 2)}
                                </div>
                                <span className="font-semibold text-slate-700 dark:text-slate-200">{person.name}</span>
                              </button>
                            ))}
                          </div>
                        )}
                        <Textarea
                          ref={commentTextareaRef}
                          placeholder="Escreva um comentário... (Use @ para mencionar)"
                          className="min-h-[70px] resize-none rounded-xl bg-white dark:bg-slate-900 pr-14 text-sm border-slate-200 dark:border-slate-800 shadow-sm focus-visible:ring-blue-500"
                          value={commentText}
                          onChange={handleCommentChange}
                          onKeyDown={e => {
                            if (e.key === 'Escape' && mentionQuery !== null) {
                              setMentionQuery(null);
                              return;
                            }
                            if(e.key === 'Enter' && !e.shiftKey) {
                              e.preventDefault();
                              handleAddComment();
                            }
                          }}
                        />
                        <Button
                          size="icon"
                          className="absolute right-2 bottom-2 w-10 h-10 rounded-lg bg-blue-600 hover:bg-blue-700 text-white shadow-md transition-all"
                          onClick={handleAddComment}
                          disabled={!commentText.trim()}
                        >
                          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path></svg>
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Timeline (1/3 width) */}
                <div className="space-y-4">
                  <Label className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-2">
                    <Activity className="w-4 h-4" /> Histórico Resumido
                  </Label>
                  <div className="bg-white dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm p-5 h-full min-h-[300px]">
                    <div className="space-y-5 relative before:absolute before:inset-0 before:ml-[11px] before:w-0.5 before:bg-slate-100 dark:before:bg-slate-800">
                      {task.timeline.slice(-8).reverse().map((event, i) => {
                        const user = users.find(u => u.id === event.userId);
                        return (
                          <div key={i} className="relative flex gap-3">
                            <div className="w-6 h-6 rounded-full bg-slate-50 dark:bg-slate-950 border-2 border-slate-200 dark:border-slate-800 flex items-center justify-center shrink-0 z-10">
                              <div className="w-1.5 h-1.5 rounded-full bg-slate-300 dark:bg-slate-600"></div>
                            </div>
                            <div className="pt-0.5">
                              <p className="text-[13px] text-slate-700 dark:text-slate-200 leading-tight">
                                <span className="font-semibold">{user?.name || "Sistema"}</span> {event.description}
                              </p>
                              <span className="text-[10px] text-slate-400 dark:text-slate-500 block mt-1 font-medium">{format(parseISO(event.createdAt), "dd/MM/yyyy HH:mm")}</span>
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  </div>
                </div>

              </div>
            )}
            
          </div>
        </div>
        
      </DialogContent>
    </Dialog>

    {/* Popup: aparece depois de enviar um comentário que @mencionou alguém
        sem vínculo prévio com a demanda — pede a categoria da parte dela,
        já que ela acabou de ser incluída automaticamente sem categoria. */}
    <Dialog open={pendingMentions.length > 0} onOpenChange={(o) => { if (!o) { setPendingMentions([]); setPendingCategories({}); } }}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>Qual a parte de quem foi mencionado?</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-slate-500 dark:text-slate-400 -mt-2">
          {pendingMentions.length === 1
            ? `${pendingMentions[0].name} foi incluído(a) automaticamente nessa demanda, já que você mencionou ela. Qual a categoria da parte dela?`
            : "Essas pessoas foram incluídas automaticamente nessa demanda, já que você mencionou elas. Qual a categoria da parte de cada uma?"}
        </p>
        <div className="space-y-3 pt-2">
          {pendingMentions.map(person => (
            <div key={person.id} className="flex items-center gap-2">
              <span className="text-sm font-semibold flex-1 truncate">{person.name}</span>
              <Select
                value={pendingCategories[person.id] || ""}
                onValueChange={(val) => setPendingCategories(prev => ({ ...prev, [person.id]: val || "" }))}
              >
                <SelectTrigger className="h-9 text-xs w-[170px] shrink-0"><SelectValue placeholder="Categoria..." /></SelectTrigger>
                <SelectContent>
                  {categories.map(c => <SelectItem key={c} value={c} className="text-xs">{c}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
          ))}
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <Button variant="outline" onClick={() => { setPendingMentions([]); setPendingCategories({}); }}>
            Definir depois
          </Button>
          <Button onClick={handleSavePendingCategories} disabled={savingPendingCategories} className="bg-indigo-600 hover:bg-indigo-700">
            {savingPendingCategories ? "Salvando..." : "Salvar"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
    </>
  );
}
