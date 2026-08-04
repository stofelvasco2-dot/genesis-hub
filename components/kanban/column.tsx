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
