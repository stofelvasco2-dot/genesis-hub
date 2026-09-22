-- ============================================================================
-- MIGRAÇÃO v5: qualquer pessoa envolvida também pode incluir gente via @menção
-- ============================================================================
-- A regra de quem pode ADICIONAR uma pessoa envolvida (task_collaborators)
-- hoje só libera admin/gestor/responsável/solicitante. Isso é certo pra
-- quem usa o botão "Adicionar" na tela — mas agora, ao @mencionar alguém
-- num comentário, o sistema tenta incluir essa pessoa automaticamente (pra
-- notificação dela funcionar). Se quem comentou for só uma "pessoa
-- envolvida comum" (não responsável/solicitante/admin/gestor), essa
-- inclusão automática era recusada pelo banco, silenciosamente.
--
-- Essa migração libera: qualquer pessoa que já seja envolvida na demanda
-- também pode incluir mais gente (útil pro fluxo de @menção). Usa a mesma
-- função segura is_task_collaborator() do v3 — sem risco de recursão.
--
-- PRÉ-REQUISITO: v3 já aplicado (função is_task_collaborator existente).
--
-- SEGURO: não apaga nem altera nenhuma linha de dado, só amplia quem pode
-- INSERIR uma nova pessoa envolvida.
-- ============================================================================

alter policy "Task collaborators: adicionar quem pode editar a task"
  on public.task_collaborators
  with check (
    is_admin_or_gestor()
    or exists (
      select 1 from public.tasks t
      where t.id = task_collaborators.task_id
        and (t.assignee_id = auth.uid() or t.requester_id = auth.uid())
    )
    or public.is_task_collaborator(task_id)
  );
