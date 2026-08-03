import { Suspense } from 'react';
import { KanbanBoard } from '@/components/kanban/board';

export default function KanbanPage() {
  return (
    <Suspense fallback={<div className="flex h-full items-center justify-center"><div className="w-8 h-8 rounded-full border-4 border-slate-200 border-t-blue-600 animate-spin" /></div>}>
      <KanbanBoard />
    </Suspense>
  );
}
