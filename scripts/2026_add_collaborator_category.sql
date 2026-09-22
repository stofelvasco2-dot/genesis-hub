-- ============================================================================
-- MIGRAÇÃO: categoria por pessoa envolvida (task_collaborators.category)
-- ============================================================================
-- Antes, cada "pessoa envolvida" numa demanda mostrava o cargo fixo dela
-- (cadastrado em Configurações). Agora cada pessoa carrega a categoria da
-- PARTE dela NESSA demanda específica (Vídeo, Social Media, Tráfego...),
-- reaproveitando a mesma lista de Categorias que a demanda já usa — porque
-- quem faz "vídeo" numa campanha não é sempre a mesma pessoa cujo cargo
-- cadastrado é "Videomaker".
--
-- SEGURA para rodar em produção: só ADICIONA uma coluna nova (nullable, sem
-- valor obrigatório) — não apaga nem altera nenhum dado existente. Pessoas
-- já adicionadas antes dessa migração ficam com category = null (o app
-- trata isso mostrando "Sem categoria definida").
--
-- Como usar: cole no SQL Editor do Supabase (no projeto certo do Genesis
-- Hub!) e rode.
-- ============================================================================

alter table public.task_collaborators
  add column if not exists category text references public.categories(name);

comment on column public.task_collaborators.category is
  'Categoria da parte que essa pessoa faz NESSA demanda (ex.: Vídeo, Social Media) — reaproveita a mesma lista de public.categories usada em tasks.category, mas é independente do cargo cadastrado da pessoa.';
