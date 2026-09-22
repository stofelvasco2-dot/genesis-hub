-- ============================================================================
-- MIGRAÇÃO v2 (isolada): só a tabela tasks, pra evitar repetir o apagão
-- ============================================================================
-- A v1 (2026_collaborator_visibility.sql) alterava 3 políticas de uma vez
-- (tasks, comments, timeline_events) e algo deu errado — o app parou de
-- mostrar demandas pra todo mundo, inclusive admin. Foi revertido com
-- 2026_ROLLBACK_collaborator_visibility.sql (nenhum dado foi perdido; só a
-- regra de leitura, que é 100% reversível).
--
-- Essa versão v2 mexe SÓ na política de tasks — o mínimo necessário pra uma
-- "pessoa envolvida" (task_collaborators) conseguir ver a demanda no
-- Kanban/Dashboard, que é o que você realmente precisa agora. Comentários e
-- histórico ficam de fora por enquanto, pra isolar a causa do problema
-- anterior antes de mexer nelas de novo.
--
-- SEGURO: ALTER POLICY não toca em nenhuma linha de dado, só na regra de
-- quem pode ler.
--
-- Como usar: rode SÓ este script (não precisa rodar o v1 de novo). Depois
-- de rodar, teste com a conta admin E com a conta de teste marcada como
-- pessoa envolvida antes de considerar concluído.
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
