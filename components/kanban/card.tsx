"use client";

import { Draggable } from "@hello-pangea/dnd";
import { Task } from "@/lib/types";
import { format, parseISO, isPast, isToday } from "date-fns";
import { ptBR } from "date-fns/locale";
import { CalendarIcon } from "lucide-react";
import { useStore } from "@/lib/store";
import { useState } from "react";
import { TaskDetailModal } from "@/components/tasks/task-detail-modal";

interface KanbanCardProps {
  task: Task;
  index: number;
}

export function KanbanCard({ task, index }: KanbanCardProps) {
  const { users } = useStore();
  const assignee = users.find((u) => u.id === task.assigneeId);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const dueDate = parseISO(task.dueDate);
  const isOverdue = isPast(dueDate) && !isToday(dueDate);

  return (
    <>
      <Draggable draggableId={task.id} index={index}>
        {(provided, snapshot) => (
          <div
            ref={provided.innerRef}
            {...provided.draggableProps}
            {...provided.dragHandleProps}
            style={provided.draggableProps.style}
            onClick={() => setIsModalOpen(true)}
            className={`group select-none relative ${snapshot.isDragging ? 'z-50' : ''}`}
          >
            <div className={`bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm cursor-grab active:cursor-grabbing hover:shadow-md transition-all duration-200 ${task.status === "Em Produção" ? "ring-2 ring-blue-500/10" : ""} ${task.status === "Aprovado" ? "opacity-75" : ""}`}>
              
              <div className="flex justify-between items-start mb-3 gap-2">
                <div className="flex flex-wrap gap-1.5">
                  <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-800 truncate max-w-[100px]">
                    {task.category}
                  </span>
                  <span className={`px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${task.priority === 'Alta' ? 'bg-orange-100 dark:bg-orange-500/15 text-orange-700 dark:text-orange-400' : task.priority === 'Urgente' ? 'bg-red-100 dark:bg-red-500/15 text-red-700 dark:text-red-400' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'}`}>
                    {task.priority}
                  </span>
                </div>
                <span className="text-[10px] font-mono text-slate-400 dark:text-slate-500 font-semibold">#{task.id.slice(0,4)}</span>
              </div>
              
              <h4 className="text-sm font-bold text-slate-900 dark:text-white leading-tight mb-2 group-hover:text-blue-600 transition-colors line-clamp-2">{task.title}</h4>
              
              <p className="text-xs text-slate-500 dark:text-slate-400 line-clamp-2 mb-4 leading-relaxed">{task.description}</p>
              
              <div className="flex items-center justify-between mt-auto pt-3 border-t border-slate-100 dark:border-slate-800">
                
                <div className="flex items-center gap-2">
                  {assignee ? (
                    <div className="flex items-center gap-1.5" title={assignee.name}>
                      <div className="w-5 h-5 rounded-full bg-blue-100 dark:bg-blue-500/15 text-blue-700 dark:text-blue-400 font-bold text-[9px] flex items-center justify-center">
                        {assignee.name.split(' ').map(n=>n[0]).join('').substring(0,2).toUpperCase()}
                      </div>
                    </div>
                  ) : (
                    <div className="w-5 h-5 rounded-full bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-800 border-dashed flex items-center justify-center" title="Sem responsável">
                      <span className="text-[10px] text-slate-400 dark:text-slate-500">?</span>
                    </div>
                  )}
                  
                  <div className="flex items-center gap-2 text-slate-400 dark:text-slate-500 ml-1">
                  </div>
                </div>

                <div className={`flex items-center gap-1 text-[10px] font-bold px-1.5 py-0.5 rounded ${isOverdue ? 'bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-400' : isToday(dueDate) ? 'bg-amber-50 dark:bg-amber-500/10 text-amber-600 dark:text-amber-400' : 'text-slate-500 dark:text-slate-400'}`}>
                  <CalendarIcon className="w-3 h-3" />
                  {format(dueDate, "dd/MM")}
                </div>
              </div>

            </div>
          </div>
        )}
      </Draggable>
      <TaskDetailModal task={task} open={isModalOpen} onOpenChange={setIsModalOpen} />
    </>
  );
}

function getDateColor(dueDateStr: string | undefined, status: string) {
  if (!dueDateStr || status === 'Aprovado') return 'text-slate-500 dark:text-slate-400';
  const date = parseISO(dueDateStr);
  
  if (isToday(date)) return 'text-amber-600 dark:text-amber-400 font-bold';
  if (isPast(date)) return 'text-red-600 dark:text-red-400 font-bold';
  return 'text-emerald-600 dark:text-emerald-400 font-bold';
}
