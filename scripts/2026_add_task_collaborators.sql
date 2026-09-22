-- ============================================================================
-- MIGRAÇÃO: pessoas envolvidas em uma demanda (task_collaborators)
-- ============================================================================
-- Permite que uma mesma demanda tenha, além do "Responsável" principal
-- (coluna tasks.assignee_id, que continua existindo e funcionando igual),
-- outras pessoas envolvidas (ex.: Designer + Videomaker + Social Media na
-- mesma peça), cada uma marcando quando a parte dela está pronta.
--
-- SEGURA para rodar em produção: só CRIA uma tabela nova. Não altera nem
-- apaga nenhuma tabela ou dado existente.
--
-- Como usar: cole no SQL Editor do Supabase e rode.
-- ============================================================================

create table if not exists public.task_collaborators (
  id uuid primary key default uuid_generate_v4(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  user_id uuid not null references public.users(id),
  done boolean not null default false,
  done_at timestamptz,
  created_at timestamptz not null default now(),
  unique (task_id, user_id)
);

comment on table public.task_collaborators is
  'Pessoas adicionais envolvidas numa demanda além do responsável principal (tasks.assignee_id). Cada uma marca "done" quando a parte dela está pronta.';

alter table public.task_collaborators enable row level security;

-- Visível pra quem já pode ver a task (mesma regra de comments/timeline_events),
-- e sempre visível pro próprio colaborador (mesmo que não seja responsável
-- nem solicitante da task).
create policy "Task collaborators: visível se a task é visível"
  on public.task_collaborators for select
  using (
    is_admin_or_gestor()
    or user_id = auth.uid()
    or exists (
      select 1 from public.tasks t
      where t.id = task_collaborators.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
  );

-- Só quem já pode gerenciar a task (admin/gestor, responsável ou solicitante)
-- pode adicionar ou remover pessoas dela.
create policy "Task collaborators: adicionar quem pode editar a task"
  on public.task_collaborators for insert
  with check (
    is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = task_collaborators.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
  );

create policy "Task collaborators: remover quem pode editar a task"
  on public.task_collaborators for delete
  using (
    is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = task_collaborators.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
  );

-- Marcar "minha parte pronta": só a própria pessoa (ou admin/gestor, pra
-- corrigir em nome de alguém se precisar).
create policy "Task collaborators: cada um marca sua própria parte"
  on public.task_collaborators for update
  using (user_id = auth.uid() or is_admin_or_gestor())
  with check (user_id = auth.uid() or is_admin_or_gestor());

-- Habilita tempo real pra essa tabela nova, igual já funciona pra
-- tasks/comments/timeline_events/notifications — sem isso, quem adiciona
-- ou marca "pronto" não aparece pros outros sem dar F5.
alter publication supabase_realtime add table public.task_collaborators;
