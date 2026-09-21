-- ============================================================================
-- MIGRAÇÃO: coluna "active" em public.users (inativar colaborador)
-- ============================================================================
-- SEGURA para rodar em produção com dados reais:
--  - Só ADICIONA uma coluna nova (ADD COLUMN IF NOT EXISTS) — não apaga, não
--    altera nem move nenhum dado existente.
--  - DEFAULT true garante que todo colaborador já cadastrado continua ativo
--    automaticamente, sem precisar de nenhum UPDATE manual.
--  - Não mexe em nenhuma policy de RLS — o comportamento de permissão
--    continua exatamente o mesmo de antes até decidirmos revisar isso
--    separadamente (assunto já identificado, mas fora do escopo desta
--    migração).
--
-- Como usar: cole no SQL Editor do Supabase e rode.
-- ============================================================================

alter table public.users
  add column if not exists active boolean not null default true;

comment on column public.users.active is
  'Colaborador ativo no sistema. false = inativado/excluído pelo admin (não pode logar, não conta em dashboards/atribuições), mas as tarefas em que ele aparece como responsável/solicitante continuam intactas.';
