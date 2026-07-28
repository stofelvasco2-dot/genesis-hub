"use client";

import { AppLayout } from "@/components/layout/app-layout";
import { useStore } from "@/lib/store";
import { DragDropContext, DropResult } from "@hello-pangea/dnd";
import { KanbanColumn } from "./column";
import { Status, Task } from "@/lib/types";
import { useState } from "react";
import { LayoutGrid, List, Trello } from "lucide-react";
import { Button } from "@/components/ui/button";
import { format, parseISO, isPast, isToday } from "date-fns";
import { ptBR } from "date-fns/locale";
import { TaskDetailModal } from "@/components/tasks/task-detail-modal";



export function KanbanBoard() {
  const { tasks, currentUser, moveTaskStatus, users, statuses } = useStore();
  const [view, setView] = useState<"kanban" | "list" | "cards">("kanban");

  const onDragEnd = (result: DropResult) => {
    const { destination, source, draggableId } = result;
    if (!destination) return;
    if (destination.droppableId === source.droppableId && destination.index === source.index) return;
    if (currentUser) {
      moveTaskStatus(draggableId, destination.droppableId as Status, currentUser.id);
    }
  };

  const displayTasks = tasks.filter(t => t.assigneeId === currentUser?.id || t.requesterId === currentUser?.id || currentUser?.role !== "Colaborador");

  return (
    <AppLayout>
      <div className="flex flex-col h-full space-y-6 p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
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
            <div className="flex flex-1 gap-6 overflow-x-auto pb-4">
              {statuses.map(status => {
                const colTasks = displayTasks.filter(t => t.status === status);
                return <KanbanColumn key={status} column={{ id: status, title: status }} tasks={colTasks} />;
              })}
            </div>
          </DragDropContext>
        )}

        {view === "list" && (
          <div className="bg-white rounded-xl border border-slate-200 overflow-hidden overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead className="bg-slate-50 text-slate-500 text-xs uppercase font-bold border-b border-slate-200">
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
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 pb-4">
            {displayTasks.map(task => {
              const assignee = users.find(u => u.id === task.assigneeId);
              return (
                <TaskGridCard key={task.id} task={task} assignee={assignee} />
              );
            })}
          </div>
        )}
      </div>
    </AppLayout>
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