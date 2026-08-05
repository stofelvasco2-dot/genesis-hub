"use client";

import { PlusCircle, Menu, PanelLeft } from "lucide-react";
import { TaskFormModal } from "@/components/tasks/task-form-modal";
import { NotificationBell } from "@/components/layout/notification-bell";
import { useState } from "react";
import { Button } from "@/components/ui/button";

export function Header({ toggleSidebar, isSidebarOpen, isMobile }: { toggleSidebar?: () => void, isSidebarOpen?: boolean, isMobile?: boolean }) {
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <header className="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-4 sm:px-8 sticky top-0 z-10 shrink-0">
      <div className="flex items-center gap-4 flex-1 overflow-hidden">
        {toggleSidebar && (
          <Button variant="ghost" size="icon" onClick={toggleSidebar} className="text-slate-500 hover:text-slate-700 shrink-0">
            <Menu className="w-5 h-5" />
          </Button>
        )}
        <h1 className="text-lg sm:text-xl font-bold text-slate-800 tracking-tight truncate">Gestão de Demandas</h1>
      </div>
      
      <div className="flex items-center gap-2 sm:gap-4 ml-4 shrink-0">
        <NotificationBell />
        <Button 
          onClick={() => setIsModalOpen(true)} 
          className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-3 sm:px-4 py-2 rounded-md text-sm font-semibold transition-colors shadow-sm"
        >
          <PlusCircle className="w-4 h-4" />
          <span className="hidden sm:inline">Nova Demanda</span>
          <span className="sm:hidden">Nova</span>
        </Button>
      </div>
      
      <TaskFormModal open={isModalOpen} onOpenChange={setIsModalOpen} />
    </header>
  );
}