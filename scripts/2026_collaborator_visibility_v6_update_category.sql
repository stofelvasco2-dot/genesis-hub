-- ============================================================================
-- MIGRAÇÃO v6: responsável/solicitante/admin/gestor podem definir categoria
-- ============================================================================
-- A regra de UPDATE em task_collaborators hoje só libera a própria pessoa
-- (marcar "minha parte pronta") ou admin/gestor. Isso trava o popup novo de
-- "definir categoria de quem foi mencionado", que precisa deixar o
-- responsável/solicitante da demanda também definir a categoria de quem
-- ele acabou de mencionar (não só admin/gestor, não só a própria pessoa
-- mencionada).
--
-- Essa migração amplia SÓ isso: quem já podia adicionar/remover pessoa
-- envolvida (admin, gestor, responsável, solicitante) passa a também poder
-- atualizar qualquer linha de task_collaborators daquela demanda (categoria
-- ou o "pronto"). Usa EXISTS direto em tasks — mesmo padrão que já existia
-- e funcionava antes de qualquer um dos problemas de recursão (a direção
-- perigosa era o contrário: tasks consultando task_collaborators sem a
-- função seção).
--
-- SEGURO: não apaga nem altera nenhuma linha de dado, só amplia quem pode
-- ATUALIZAR uma linha de task_collaborators.
-- ============================================================================

alter policy "Task collaborators: cada um marca sua própria parte"
  on public.task_collaborators
  using (
    user_id = auth.uid()
    or is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = task_collaborators.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
  )
  with check (
    user_id = auth.uid()
    or is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = task_collaborators.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
  );
