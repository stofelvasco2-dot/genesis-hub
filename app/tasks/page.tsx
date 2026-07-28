"use client";

import { AppLayout } from "@/components/layout/app-layout";
import { useStore } from "@/lib/store";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { format, parseISO } from "date-fns";
import { ptBR } from "date-fns/locale";

export default function TasksPage() {
  const { tasks, users, currentUser } = useStore();

  const isGestorOrAdmin = currentUser?.role === "Admin" || currentUser?.role === "Gestor";
  
  const displayTasks = isGestorOrAdmin 
    ? tasks 
    : tasks.filter(t => t.assigneeId === currentUser?.id || t.requesterId === currentUser?.id);

  return (
    <AppLayout>
      <div className="space-y-6 p-6">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Todas as Tarefas</h2>
          <p className="text-muted-foreground mt-2">Lista completa de solicitações.</p>
        </div>

        <div className="border rounded-md bg-card">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Título</TableHead>
                <TableHead>Categoria</TableHead>
                <TableHead>Prioridade</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Solicitante</TableHead>
                <TableHead>Responsável</TableHead>
                <TableHead>Prazo</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {displayTasks.map(task => {
                const requester = users.find(u => u.id === task.requesterId)?.name;
                const assignee = users.find(u => u.id === task.assigneeId)?.name || "Não atribuído";
                
                return (
                  <TableRow key={task.id} className="cursor-pointer hover:bg-muted/50">
                    <TableCell className="font-medium">{task.title}</TableCell>
                    <TableCell>{task.category}</TableCell>
                    <TableCell>{task.priority}</TableCell>
                    <TableCell>
                      <Badge variant="outline">{task.status}</Badge>
                    </TableCell>
                    <TableCell>{requester}</TableCell>
                    <TableCell>{assignee}</TableCell>
                    <TableCell>{format(parseISO(task.dueDate), "dd/MM/yyyy", { locale: ptBR })}</TableCell>
                  </TableRow>
                );
              })}
              {displayTasks.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center h-24 text-muted-foreground">
                    Nenhuma tarefa encontrada.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </div>
    </AppLayout>
  );
}
