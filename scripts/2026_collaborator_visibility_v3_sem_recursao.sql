-- ============================================================================
-- MIGRAÇÃO v3: pessoa envolvida consegue ver a demanda, SEM recursão de RLS
-- ============================================================================
-- ⚠️ SÓ RODE ISSO DEPOIS de confirmar que 2026_ROLLBACK_collaborator_visibility.sql
-- já foi executado e o dashboard do admin voltou ao normal.
--
-- O QUE DEU ERRADO NAS TENTATIVAS ANTERIORES (v1 e v2):
-- A tabela task_collaborators já tinha uma regra de segurança que checa
-- "a task dessa linha é visível?" (consultando tasks). As versões v1/v2
-- tentaram fazer o inverso: a tabela tasks checar "existe uma linha minha em
-- task_collaborators?" (consultando task_collaborators). As duas tabelas
-- checando uma à outra ao mesmo tempo cria um loop infinito — o Postgres
-- detecta isso e recusa a consulta inteira, pra TODO MUNDO (até admin),
-- porque o erro estoura antes mesmo de decidir se você é admin ou não.
--
-- A CORREÇÃO: criar uma função "is_task_collaborator" marcada como
-- SECURITY DEFINER. Isso faz ela rodar com um "crachá" que ignora a regra
-- de segurança de task_collaborators só NESSA checagem pontual — exatamente
-- o mesmo truque que a função is_admin_or_gestor() já usa hoje pra evitar
-- esse mesmo problema com a tabela de usuários. Isso quebra o ciclo: tasks
-- pergunta pra função (que não aciona a RLS de task_collaborators de volta),
-- em vez de perguntar direto pra tabela.
--
-- SEGURO: não apaga nem altera nenhuma linha de dado, só cria 1 função nova
-- e ajusta a regra de leitura de "tasks".
-- ============================================================================

create or replace function public.is_task_collaborator(p_task_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.task_collaborators tc
    where tc.task_id = p_task_id and tc.user_id = auth.uid()
  );
$$;

alter policy "Tasks: admin/gestor veem tudo, colaborador ve as suas"
  on public.tasks
  using (
    is_admin_or_gestor()
    or assignee_id = auth.uid()
    or requester_id = auth.uid()
    or public.is_task_collaborator(tasks.id)
  );
