-- ============================================================================
-- ⚠️ NÃO USAR — DEPRECIADO. Rodar isso causou pane geral (ninguém via
-- nenhuma demanda, nem admin) em produção em 22/09/2026. Foi revertido com
-- 2026_ROLLBACK_collaborator_visibility.sql (sem perda de dados). A parte
-- de "tasks" foi reaplicada, isolada, em 2026_collaborator_visibility_v2_tasks_only.sql
-- — use esse. As partes de comments/timeline_events ficaram de fora até
-- a causa raiz ser identificada com mais cuidado.
-- ============================================================================

-- ============================================================================
-- MIGRAÇÃO: quem é "pessoa envolvida" numa demanda passa a poder VER ela
-- ============================================================================
-- Hoje as políticas de segurança (RLS) de tasks/comments/timeline_events só
-- liberam leitura pra admin/gestor, o responsável (assignee) ou quem pediu
-- (requester). Quem foi adicionado como "pessoa envolvida" (task_collaborators)
-- não aparecia nem no Kanban, nem na lista de tarefas — mesmo já tendo sido
-- notificado. Essa migração amplia as 3 políticas de LEITURA (SELECT) pra
-- incluir também quem está em task_collaborators daquela demanda.
--
-- SEGURA para rodar em produção: usa ALTER POLICY, que só troca a REGRA de
-- quem pode ler — não apaga, não recria e não altera nenhuma linha de dado
-- existente. Ninguém que já podia ver algo deixa de poder; só amplia quem
-- mais passa a ver.
--
-- Como usar: cole no SQL Editor do Supabase (projeto certo do Genesis Hub)
-- e rode.
-- ============================================================================

alter policy "Tasks: admin/gestor veem tudo, colaborador ve as suas"
  on public.tasks
  using (
    is_admin_or_gestor()
    or assignee_id = auth.uid()
    or requester_id = auth.uid()
    or exists (
      select 1 from public.task_collaborators tc
      where tc.task_id = tasks.id and tc.user_id = auth.uid()
    )
  );

alter policy "Comments: visivel se a task e visivel"
  on public.comments
  using (
    is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = comments.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
    or exists (
      select 1 from public.task_collaborators tc
      where tc.task_id = comments.task_id and tc.user_id = auth.uid()
    )
  );

alter policy "Timeline: visivel se a task e visivel"
  on public.timeline_events
  using (
    is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = timeline_events.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
    or exists (
      select 1 from public.task_collaborators tc
      where tc.task_id = timeline_events.task_id and tc.user_id = auth.uid()
    )
  );
