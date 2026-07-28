
"use client";

import { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useStore } from "@/lib/store";
import { Category, Priority, Department } from "@/lib/types";
import { toast } from "sonner";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { CalendarIcon, X } from "lucide-react";
import { format } from "date-fns";
import { ptBR } from "date-fns/locale";
import { cn } from "@/lib/utils";

interface TaskFormModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}







export function TaskFormModal({ open, onOpenChange }: TaskFormModalProps) {
  const { addTask, currentUser, categories, priorities, departments, statuses } = useStore();
  
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState<Category | "">("");
  const [priority, setPriority] = useState<Priority | "">("");
  const [dueDate, setDueDate] = useState<Date | undefined>(undefined);
  const [referenceLinks, setReferenceLinks] = useState("");
  const [notes, setNotes] = useState("");
  const [requesterName, setRequesterName] = useState(currentUser?.name || "");
  const [department, setDepartment] = useState<Department | "">((currentUser?.department as Department) || "");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser) return;
    
    if (!title || !description || !category || !priority || !dueDate || !requesterName || !department) {
      toast.error("Preencha todos os campos obrigatórios");
      return;
    }

    addTask({
      title,
      description,
      category: category as Category,
      priority: priority as Priority,
      status: statuses[0] || "Triagem",
      requesterId: currentUser.id,
      requesterName,
      department: department as Department,
      dueDate: dueDate.toISOString(),
      referenceLinks: referenceLinks.split(/[\n, ]+/).map(l => l.trim()).filter(l => l.length > 0),
      notes: notes.trim() || undefined,
    });

    toast.success("Demanda criada com sucesso!");
    onOpenChange(false);
    
    // Reset form
    setTitle("");
    setDescription("");
    setCategory("");
    setPriority("");
    setDueDate(undefined);
    setReferenceLinks("");
    setNotes("");
    setRequesterName(currentUser?.name || "");
    setDepartment((currentUser?.department as Department) || "");
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[700px] w-[95vw] max-h-[90vh] flex flex-col p-0 overflow-hidden bg-white border-none rounded-2xl shadow-2xl [&>button]:hidden">
        <DialogHeader className="px-6 py-4 border-b border-slate-100 flex flex-row items-center justify-between sticky top-0 bg-white z-10">
          <DialogTitle className="text-xl font-bold">Nova Solicitação</DialogTitle>
          <Button type="button" variant="ghost" size="icon" onClick={() => onOpenChange(false)} className="h-8 w-8 rounded-full">
            <X className="w-4 h-4" />
          </Button>
        </DialogHeader>
        
        <div className="flex-1 overflow-y-auto px-6 py-4">
          <form id="task-form" onSubmit={handleSubmit} className="space-y-6 pb-8">
            <div className="space-y-4">

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pb-4 border-b border-slate-100">
                <div className="space-y-2">
                  <Label htmlFor="requesterName" className="text-xs font-semibold text-slate-600">Nome do Solicitante *</Label>
                  <Input 
                    id="requesterName"
                    value={requesterName} 
                    onChange={e => setRequesterName(e.target.value)}
                    className="h-10"
                  />
                </div>
                <div className="space-y-2">
                  <Label className="text-xs font-semibold text-slate-600">Setor Solicitante *</Label>
                  <Select value={department} onValueChange={(val) => val && setDepartment(val as Department)}>
                    <SelectTrigger className="h-10"><SelectValue placeholder="Selecione o setor" /></SelectTrigger>
                    <SelectContent>
                      {departments.map(d => <SelectItem key={d} value={d}>{d}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="title" className="text-xs font-semibold text-slate-600">Título da Solicitação *</Label>
                <Input 
                  id="title"
                  value={title} 
                  onChange={e => setTitle(e.target.value)}
                  placeholder="Ex: Criar arte para redes sociais"
                  className="h-10"
                />
              </div>
              
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label className="text-xs font-semibold text-slate-600">Categoria *</Label>
                  <Select value={category} onValueChange={(val) => val && setCategory(val as Category)}>
                    <SelectTrigger className="h-10"><SelectValue placeholder="Selecione" /></SelectTrigger>
                    <SelectContent>
                      {categories.map(c => <SelectItem key={c} value={c}>{c}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                
                <div className="space-y-2">
                  <Label className="text-xs font-semibold text-slate-600">Prioridade *</Label>
                  <Select value={priority} onValueChange={(val) => val && setPriority(val as Priority)}>
                    <SelectTrigger className="h-10"><SelectValue placeholder="Selecione" /></SelectTrigger>
                    <SelectContent>
                      {priorities.map(p => <SelectItem key={p} value={p}>{p}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="space-y-2 flex flex-col">
                <Label className="text-xs font-semibold text-slate-600">Prazo Solicitado *</Label>
                <Popover>
                  <PopoverTrigger
                    className={cn(
                      "flex h-10 w-full items-center justify-start rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm ring-offset-background hover:bg-slate-50",
                      !dueDate && "text-muted-foreground"
                    )}
                  >
                    <CalendarIcon className="mr-2 h-4 w-4" />
                    {dueDate ? format(dueDate, "dd/MM/yyyy", { locale: ptBR }) : <span>Selecionar data</span>}
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0">
                    <Calendar 
                      mode="single" 
                      selected={dueDate} 
                      onSelect={setDueDate} 
                    />
                  </PopoverContent>
                </Popover>
              </div>

              <div className="space-y-2">
                <Label htmlFor="description" className="text-xs font-semibold text-slate-600">Descrição Completa *</Label>
                <Textarea 
                  id="description"
                  value={description} 
                  onChange={e => setDescription(e.target.value)}
                  placeholder="Detalhes da demanda..."
                  className="min-h-[100px]"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="referenceLinks" className="text-xs font-semibold text-slate-600">Links de Referência</Label>
                <Textarea 
                  id="referenceLinks"
                  value={referenceLinks} 
                  onChange={e => setReferenceLinks(e.target.value)}
                  placeholder="Links do Google Drive, Figma, Canva, Notion, etc."
                  className="min-h-[80px]"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="notes" className="text-xs font-semibold text-slate-600">Observações Extras</Label>
                <Textarea 
                  id="notes"
                  value={notes} 
                  onChange={e => setNotes(e.target.value)}
                  placeholder="Informações adicionais importantes..."
                  className="min-h-[80px]"
                />
              </div>

            </div>
          </form>
        </div>
        
        <div className="p-4 border-t border-slate-100 flex justify-end gap-3 bg-slate-50">
          <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
            Cancelar
          </Button>
          <Button type="submit" form="task-form" className="bg-blue-600 hover:bg-blue-700 text-white">
            Criar Solicitação
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
