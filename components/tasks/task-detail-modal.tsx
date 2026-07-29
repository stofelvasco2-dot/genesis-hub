"use client";

import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Task, Category, Priority, Department, Status } from "@/lib/types";
import { X, CalendarIcon, Save, Edit2, ExternalLink, MessageSquare, Activity } from "lucide-react";
import { useState, useEffect } from "react";
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
  const { updateTask, currentUser, users, addComment, statuses, categories, priorities, departments } = useStore();
  
  const [isEditing, setIsEditing] = useState(false);
  const [editedTask, setEditedTask] = useState<Partial<Task>>({});
  const [commentText, setCommentText] = useState("");

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
    }
  }, [open, task]);

  const handleSave = () => {
    if (!currentUser) return;
    updateTask(task.id, editedTask, currentUser.id);
    toast.success("Solicitação atualizada com sucesso!");
    setIsEditing(false);
  };

  const handleAddComment = () => {
    if (!commentText.trim() || !currentUser) return;
    addComment(task.id, currentUser.id, commentText.trim());
    setCommentText("");
    toast.success("Comentário adicionado!");
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
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-[1200px] w-[95vw] max-h-[95vh] sm:h-[90vh] flex flex-col p-0 overflow-y-auto sm:overflow-hidden bg-slate-50 border-none shadow-2xl font-sans sm:rounded-2xl [&>button]:hidden">
        
        {/* Header - Glassmorphism (Azul translúcido, desfocado) */}
        <div className="flex-none px-5 py-4 sm:px-8 sm:py-5 bg-blue-600/10 backdrop-blur-xl border-b border-blue-600/10 flex flex-col sm:flex-row sm:items-center justify-between gap-4 z-50">
          <div className="flex flex-col gap-2 flex-1 min-w-0">
            <div className="flex items-center gap-3">
              <span className="text-xs font-mono font-bold bg-blue-500/20 text-blue-700 px-2 py-1 rounded shadow-sm border border-blue-500/10">#{task.id.slice(0,6).toUpperCase()}</span>
              {isEditing ? (
                <Select value={currentTask.status} onValueChange={(val) => setEditedTask({...editedTask, status: val as Status})}>
                  <SelectTrigger className="h-7 text-xs font-bold bg-white/50 backdrop-blur-sm border-blue-500/20 text-blue-800 w-auto">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {statuses.map(s => <SelectItem key={s} value={s} className="text-xs">{s}</SelectItem>)}
                  </SelectContent>
                </Select>
              ) : (
                <span className="px-2.5 py-1 rounded text-[10px] font-bold uppercase tracking-wider bg-blue-500/20 text-blue-700 shadow-sm border border-blue-500/10">{currentTask.status}</span>
              )}
            </div>
            
            {isEditing ? (
              <Input 
                value={currentTask.title} 
                onChange={e => setEditedTask({...editedTask, title: e.target.value})}
                className="h-10 text-xl font-bold w-full max-w-2xl bg-white/60 backdrop-blur-md border-blue-500/20 focus-visible:ring-blue-500"
              />
            ) : (
              <DialogTitle className="text-xl sm:text-2xl font-bold text-slate-900 truncate pr-4 drop-shadow-sm">{currentTask.title}</DialogTitle>
            )}

            <div className="flex flex-wrap items-center gap-x-4 gap-y-2 text-xs text-slate-700 font-medium mt-1">
              <span className="flex items-center gap-1.5 bg-white/40 px-2 py-1 rounded-md border border-white/20 shadow-sm">
                <span className="text-slate-500">Solicitante:</span> 
                <span className="font-bold text-slate-900">{currentTask.requesterName}</span>
              </span>
              <span className="flex items-center gap-1.5 bg-white/40 px-2 py-1 rounded-md border border-white/20 shadow-sm">
                <span className="text-slate-500">Última atualização:</span> 
                <span className="font-bold text-slate-900">{format(parseISO(task.updatedAt || task.createdAt), "dd/MM/yyyy HH:mm", { locale: ptBR })}</span>
              </span>
            </div>
          </div>
          
          <div className="flex items-center gap-3 shrink-0 self-start sm:self-center">
            {!isEditing ? (
              <Button onClick={() => setIsEditing(true)} className="bg-white/60 hover:bg-white/90 text-blue-800 border border-blue-500/20 backdrop-blur-md shadow-sm h-10 gap-2 font-bold px-5 transition-all">
                <Edit2 className="w-4 h-4" /> Editar
              </Button>
            ) : (
              <Button onClick={handleSave} className="bg-blue-600 hover:bg-blue-700 text-white shadow-md h-10 gap-2 font-bold px-5 transition-all">
                <Save className="w-4 h-4" /> Salvar
              </Button>
            )}
            <Button type="button" variant="ghost" size="icon" onClick={() => onOpenChange(false)} className="h-10 w-10 rounded-full bg-white/40 hover:bg-white/80 text-slate-700 backdrop-blur-md border border-white/40 shadow-sm transition-all">
              <X className="w-4 h-4" />
            </Button>
          </div>
        </div>
        
        {/* Main Content Area - Fixing scroll by using flex-1 properly */}
        <div className="flex-1 w-full bg-slate-50/50 sm:overflow-y-auto">
          
          {/* Executive Header - Underneath main title */}
          <div className="bg-white border-b border-slate-200/60 shadow-sm sticky top-0 z-40">
            <div className="flex overflow-x-auto p-4 sm:px-8">
              <div className="flex flex-nowrap items-center gap-6 w-full text-sm min-w-max">
                
                {/* Responsável */}
                <div className="flex flex-col gap-1.5 min-w-[150px]">
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Responsável</span>
                  {isEditing ? (
                    <Select value={currentTask.assigneeId || "unassigned"} onValueChange={(val) => setEditedTask({...editedTask, assigneeId: (val === "unassigned" ? undefined : val) as string | undefined})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50"><SelectValue>{currentTask.assigneeId ? users.find(u => u.id === currentTask.assigneeId)?.name : "Sem responsável"}</SelectValue></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="unassigned" className="text-xs">Sem responsável</SelectItem>
                        {users.map(u => (
                          <SelectItem key={u.id} value={u.id} className="text-xs">{u.name}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="font-bold text-slate-800 h-8 flex items-center gap-2">
                      {currentAssignee ? (
                        <>
                          <div className="w-6 h-6 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center text-[10px] uppercase border border-blue-200">
                            {currentAssignee.name.split(' ').map(n=>n[0]).join('').substring(0,2)}
                          </div>
                          <span className="truncate text-sm">{currentAssignee.name}</span>
                        </>
                      ) : (
                        <span className="text-slate-400 italic text-sm">Nenhum</span>
                      )}
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200/80"></div>

                {/* Categoria */}
                <div className="flex flex-col gap-1.5 min-w-[130px]">
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Categoria</span>
                  {isEditing ? (
                    <Select value={currentTask.category} onValueChange={(val) => setEditedTask({...editedTask, category: val as Category})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {categories.map(c => <SelectItem key={c} value={c} className="text-xs">{c}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="font-bold text-slate-800 h-8 flex items-center text-sm">{currentTask.category}</div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200/80"></div>

                {/* Prioridade */}
                <div className="flex flex-col gap-1.5 min-w-[110px]">
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Prioridade</span>
                  {isEditing ? (
                    <Select value={currentTask.priority} onValueChange={(val) => setEditedTask({...editedTask, priority: val as Priority})}>
                      <SelectTrigger className="h-8 text-xs font-semibold bg-slate-50"><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {priorities.map(p => <SelectItem key={p} value={p} className="text-xs">{p}</SelectItem>)}
                      </SelectContent>
                    </Select>
                  ) : (
                    <div className="h-8 flex items-center">
                      <span className={cn(
                        "px-2.5 py-1 rounded text-xs font-bold uppercase tracking-wider shadow-sm",
                        currentTask.priority === 'Alta' ? 'bg-orange-100 text-orange-700 border border-orange-200' : 
                        currentTask.priority === 'Urgente' ? 'bg-red-100 text-red-700 border border-red-200' : 'bg-slate-100 text-slate-700 border border-slate-200'
                      )}>
                        {currentTask.priority}
                      </span>
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200/80"></div>

                {/* Prazo */}
                <div className="flex flex-col gap-1.5 min-w-[140px]">
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Prazo Solicitado</span>
                  {isEditing ? (
                    <Popover>
                      <PopoverTrigger className={cn("flex h-8 w-full items-center justify-start rounded-md border border-input bg-slate-50 px-2 py-1 text-xs font-semibold shadow-sm", !dueDate && "text-muted-foreground")}>
                        <CalendarIcon className="mr-2 h-3.5 w-3.5" />
                        {dueDate ? format(dueDate, "dd/MM/yyyy") : <span>Data</span>}
                      </PopoverTrigger>
                      <PopoverContent className="w-auto p-0">
                        <Calendar mode="single" selected={dueDate} onSelect={(date) => setEditedTask({...editedTask, dueDate: date?.toISOString()})} />
                      </PopoverContent>
                    </Popover>
                  ) : (
                    <div className="h-8 flex items-center font-bold text-slate-800 gap-2 text-sm">
                      <CalendarIcon className="w-4 h-4 text-slate-400" />
                      {dueDate ? format(dueDate, "dd/MM/yyyy") : "Não definido"}
                    </div>
                  )}
                </div>
                <div className="w-px h-10 bg-slate-200/80"></div>

                {/* SLA / Dias Restantes */}
                <div className="flex flex-col gap-1.5 min-w-[150px] max-w-[200px] flex-1">
                  <div className="flex justify-between items-center text-[10px] font-bold uppercase tracking-wider">
                    <span className="text-slate-400">Dias Restantes</span>
                    <span className={daysLeft < 0 ? 'text-red-600' : 'text-slate-700'}>{daysLeft < 0 ? 'Atrasado' : `${daysLeft} dias`}</span>
                  </div>
                  <div className="h-8 flex flex-col justify-center w-full gap-1.5">
                    <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden border border-slate-200/50 shadow-inner">
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
                <div className="w-px h-10 bg-slate-200/80"></div></div>
            </div>
          </div>

          {/* Main Body Content */}
          <div className="p-4 sm:p-6 lg:p-8 max-w-6xl mx-auto space-y-8 pb-16">
            
            {/* Briefing Section */}
            <div className="space-y-6">
              
              <div className="space-y-3">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">Descrição Completa</Label>
                {isEditing ? (
                  <Textarea 
                    value={currentTask.description} 
                    onChange={e => setEditedTask({...editedTask, description: e.target.value})}
                    className="min-h-[150px] resize-none bg-white border-slate-200 shadow-sm text-sm"
                  />
                ) : (
                  <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-5 sm:p-6 text-sm text-slate-800 whitespace-pre-wrap leading-relaxed">
                    {currentTask.description}
                  </div>
                )}
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">Links de Referência</Label>
                  {isEditing ? (
                    <Textarea 
                      value={linksString} 
                      onChange={e => handleLinksChange(e.target.value)}
                      placeholder="Cole os links de referência (Figma, Drive, etc) separados por vírgula ou linha"
                      className="min-h-[100px] resize-none bg-white border-slate-200 shadow-sm text-sm"
                    />
                  ) : (
                    <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-5 text-sm text-slate-800 flex flex-col gap-3 min-h-[100px]">
                      {currentTask.referenceLinks && currentTask.referenceLinks.length > 0 ? (
                        currentTask.referenceLinks.map((link, i) => {
                          const isUrl = link.startsWith('http://') || link.startsWith('https://');
                          const href = isUrl ? link : `https://${link}`;
                          return (
                            <a key={i} href={href} target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:text-blue-700 hover:underline inline-flex items-center gap-2 font-medium bg-blue-50/50 hover:bg-blue-50 px-3 py-2 rounded-lg w-fit break-all transition-colors border border-blue-100">
                              <ExternalLink className="w-4 h-4 shrink-0" />
                              {link}
                            </a>
                          );
                        })
                      ) : (
                        <span className="text-slate-400 italic">Nenhum link fornecido.</span>
                      )}
                    </div>
                  )}
                </div>

                <div className="space-y-3">
                  <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">Observações Extras</Label>
                  {isEditing ? (
                    <Textarea 
                      value={currentTask.notes || ""} 
                      onChange={e => setEditedTask({...editedTask, notes: e.target.value})}
                      className="min-h-[100px] resize-none bg-white border-slate-200 shadow-sm text-sm"
                      placeholder="Informações adicionais importantes..."
                    />
                  ) : (
                    <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-5 text-sm text-slate-800 whitespace-pre-wrap min-h-[100px]">
                      {currentTask.notes || <span className="text-slate-400 italic">Nenhuma observação extra.</span>}
                    </div>
                  )}
                </div>
              </div>

            </div>

            {/* Interaction Section (Comments & Timeline) */}
            {!isEditing && (
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 pt-6 border-t border-slate-200">
                
                {/* Comments (2/3 width) */}
                <div className="lg:col-span-2 space-y-4">
                  <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-2">
                    <MessageSquare className="w-4 h-4" /> Comentários
                  </Label>
                  <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
                    <div className="p-4 sm:p-6 space-y-6 max-h-[600px] overflow-y-auto">
                      {task.comments.length === 0 ? (
                        <div className="text-center text-slate-400 text-sm italic py-8 bg-slate-50 rounded-xl border border-dashed border-slate-200">Nenhum comentário ainda.</div>
                      ) : (
                        task.comments.map(comment => {
                          const user = users.find(u => u.id === comment.userId);
                          const isMe = user?.id === currentUser?.id;
                          return (
                            <div key={comment.id} className={`flex gap-3 ${isMe ? 'flex-row-reverse' : ''}`}>
                              <div className="w-9 h-9 rounded-full bg-slate-100 border border-slate-200 flex items-center justify-center shrink-0 shadow-sm">
                                <span className="text-xs font-bold text-slate-600">
                                  {user?.name ? user.name.split(' ').map(n=>n[0]).join('').substring(0,2).toUpperCase() : "?"}
                                </span>
                              </div>
                              <div className={`flex flex-col max-w-[85%] ${isMe ? 'items-end' : 'items-start'}`}>
                                <div className="flex items-center gap-2 mb-1.5 px-1">
                                  <span className="text-xs font-bold text-slate-700">{user?.name}</span>
                                  <span className="text-[10px] text-slate-400 font-medium">{format(parseISO(comment.createdAt), "dd/MM/yyyy HH:mm")}</span>
                                </div>
                                <div className={`px-4 py-2.5 rounded-2xl text-sm shadow-sm ${isMe ? 'bg-blue-600 text-white rounded-tr-sm' : 'bg-white border border-slate-200 text-slate-800 rounded-tl-sm'}`}>
                                  {comment.text}
                                </div>
                              </div>
                            </div>
                          )
                        })
                      )}
                    </div>
                    <div className="p-3 sm:p-4 bg-slate-50 border-t border-slate-100">
                      <div className="relative">
                        <Textarea 
                          placeholder="Escreva um comentário... (Use @ para mencionar)"
                          className="min-h-[70px] resize-none rounded-xl bg-white pr-14 text-sm border-slate-200 shadow-sm focus-visible:ring-blue-500"
                          value={commentText}
                          onChange={e => setCommentText(e.target.value)}
                          onKeyDown={e => {
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
                  <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-2">
                    <Activity className="w-4 h-4" /> Histórico Resumido
                  </Label>
                  <div className="bg-white rounded-xl border border-slate-200 shadow-sm p-5 h-full min-h-[300px]">
                    <div className="space-y-5 relative before:absolute before:inset-0 before:ml-[11px] before:w-0.5 before:bg-slate-100">
                      {task.timeline.slice(-8).reverse().map((event, i) => {
                        const user = users.find(u => u.id === event.userId);
                        return (
                          <div key={i} className="relative flex gap-3">
                            <div className="w-6 h-6 rounded-full bg-slate-50 border-2 border-slate-200 flex items-center justify-center shrink-0 z-10">
                              <div className="w-1.5 h-1.5 rounded-full bg-slate-300"></div>
                            </div>
                            <div className="pt-0.5">
                              <p className="text-[13px] text-slate-700 leading-tight">
                                <span className="font-semibold">{user?.name || "Sistema"}</span> {event.description}
                              </p>
                              <span className="text-[10px] text-slate-400 block mt-1 font-medium">{format(parseISO(event.createdAt), "dd/MM/yyyy HH:mm")}</span>
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
  );
}