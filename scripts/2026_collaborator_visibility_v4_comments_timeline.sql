-- ============================================================================
-- MIGRAÇÃO v4: pessoa envolvida passa a ver comentários e histórico também
-- ============================================================================
-- Mesmo problema de antes, mas em comments/timeline_events: quem é só
-- "pessoa envolvida" (task_collaborators) numa demanda não conseguia ver os
-- comentários nem o histórico dela — só admin/gestor/responsável/solicitante
-- conseguiam. A pessoa recebia a notificação (isso já funcionava), mas ao
-- abrir a demanda o campo de comentários aparecia vazio pra ela.
--
-- Dessa vez usamos a função is_task_collaborator() (criada no v3), que já é
-- SEGURA contra o problema de recursão que travou o sistema nas tentativas
-- anteriores — ela não cria um ciclo novo porque não passa de novo pela
-- regra de segurança de task_collaborators.
--
-- PRÉ-REQUISITO: rodar 2026_collaborator_visibility_v3_sem_recursao.sql
-- antes deste (precisa da função is_task_collaborator já existir).
--
-- SEGURO: não apaga nem altera nenhuma linha de dado, só amplia quem pode
-- LER comentários e histórico.
-- ============================================================================

alter policy "Comments: visivel se a task e visivel"
  on public.comments
  using (
    is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = comments.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
    or public.is_task_collaborator(comments.task_id)
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
    or public.is_task_collaborator(timeline_events.task_id)
  );
