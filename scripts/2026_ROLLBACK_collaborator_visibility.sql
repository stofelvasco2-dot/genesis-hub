-- ============================================================================
-- REVERSÃO DE EMERGÊNCIA: volta as políticas de leitura ao estado exato de
-- antes do scripts/2026_collaborator_visibility.sql
-- ============================================================================
-- Use isso se, depois de rodar 2026_collaborator_visibility.sql, o sistema
-- parou de mostrar demandas (inclusive pro admin). Restaura a regra de
-- leitura EXATA que já funcionava antes, sem o pedaço novo de
-- task_collaborators.
--
-- 100% SEGURO: ALTER POLICY nunca apaga nem altera dado nenhum — só troca a
-- expressão booleana usada pra decidir quem pode LER uma linha. Nenhuma
-- linha de tasks/comments/timeline_events é tocada por este script.
-- ============================================================================

alter policy "Tasks: admin/gestor veem tudo, colaborador ve as suas"
  on public.tasks
  using (
    is_admin_or_gestor()
    or assignee_id = auth.uid()
    or requester_id = auth.uid()
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
  );
