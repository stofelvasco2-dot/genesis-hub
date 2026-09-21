-- ============================================================================
-- INTROSPECÇÃO DO SCHEMA REAL DO SUPABASE (genesis-hub)
-- ============================================================================
-- Objetivo: extrair TUDO que existe de fato no banco (tabelas, colunas,
-- chaves, índices, RLS habilitado, políticas) para comparar com os arquivos
-- supabase.sql / SUPABASE_SETUP.md do repositório, que estão desatualizados.
--
-- Como usar:
-- 1. Abra o Supabase Studio do projeto -> SQL Editor -> New query
-- 2. Cole este arquivo inteiro e clique em "Run"
-- 3. Ele roda em blocos separados (cada "SELECT" abaixo é uma consulta
--    independente) -- rode um bloco de cada vez OU rode tudo junto: no
--    Supabase SQL Editor, ao rodar múltiplos SELECTs, ele mostra apenas o
--    resultado do último. Para ver todos os resultados, rode cada bloco
--    separadamente (selecione o texto do bloco e aperte Ctrl+Enter / Run).
-- 4. Copie os resultados de cada bloco e me envie (ou exporte como CSV
--    clicando em "Download CSV" no canto do resultado).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOCO 1: Lista de tabelas do schema public (visão geral)
-- ----------------------------------------------------------------------------
select
  table_name,
  (select count(*) from information_schema.columns c
     where c.table_schema = 'public' and c.table_name = t.table_name) as qtd_colunas
from information_schema.tables t
where table_schema = 'public'
  and table_type = 'BASE TABLE'
order by table_name;


-- ----------------------------------------------------------------------------
-- BLOCO 2: Todas as colunas de todas as tabelas, com tipo, obrigatoriedade e default
-- ----------------------------------------------------------------------------
select
  c.table_name,
  c.ordinal_position as pos,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.is_nullable,
  c.column_default,
  c.character_maximum_length
from information_schema.columns c
where c.table_schema = 'public'
order by c.table_name, c.ordinal_position;


-- ----------------------------------------------------------------------------
-- BLOCO 3: Chaves primárias (PK)
-- ----------------------------------------------------------------------------
select
  tc.table_name,
  kcu.column_name,
  tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.table_schema = kcu.table_schema
where tc.constraint_type = 'PRIMARY KEY'
  and tc.table_schema = 'public'
order by tc.table_name;


-- ----------------------------------------------------------------------------
-- BLOCO 4: Chaves estrangeiras (FK) -- mostra os relacionamentos reais entre tabelas
-- ----------------------------------------------------------------------------
select
  tc.table_name as tabela_origem,
  kcu.column_name as coluna_origem,
  ccu.table_name as tabela_referenciada,
  ccu.column_name as coluna_referenciada,
  rc.update_rule,
  rc.delete_rule
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.table_schema = kcu.table_schema
join information_schema.constraint_column_usage ccu
  on tc.constraint_name = ccu.constraint_name
join information_schema.referential_constraints rc
  on tc.constraint_name = rc.constraint_name
where tc.constraint_type = 'FOREIGN KEY'
  and tc.table_schema = 'public'
order by tc.table_name;


-- ----------------------------------------------------------------------------
-- BLOCO 5: Constraints UNIQUE e CHECK
-- ----------------------------------------------------------------------------
select
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  string_agg(kcu.column_name, ', ') as colunas
from information_schema.table_constraints tc
left join information_schema.key_column_usage kcu
  on tc.constraint_name = kcu.constraint_name
 and tc.table_schema = kcu.table_schema
where tc.table_schema = 'public'
  and tc.constraint_type in ('UNIQUE', 'CHECK')
group by tc.table_name, tc.constraint_name, tc.constraint_type
order by tc.table_name;


-- ----------------------------------------------------------------------------
-- BLOCO 6: Índices
-- ----------------------------------------------------------------------------
select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
order by tablename, indexname;


-- ----------------------------------------------------------------------------
-- BLOCO 7: Row Level Security -- quais tabelas têm RLS HABILITADO
-- (essencial pro problema de segurança que identificamos)
-- ----------------------------------------------------------------------------
select
  c.relname as tabela,
  c.relrowsecurity as rls_habilitado,
  c.relforcerowsecurity as rls_forcado_para_owner
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname;


-- ----------------------------------------------------------------------------
-- BLOCO 8: Políticas RLS -- o mais importante para o diagnóstico de segurança
-- Mostra, para cada tabela, cada política: comando (SELECT/INSERT/UPDATE/DELETE),
-- quem ela vale (roles), e as expressões USING / WITH CHECK reais.
-- ----------------------------------------------------------------------------
select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd as comando,
  qual as using_expression,
  with_check as with_check_expression
from pg_policies
where schemaname = 'public'
order by tablename, policyname;


-- ----------------------------------------------------------------------------
-- BLOCO 9: Funções e triggers customizados (ex.: gatilhos que criam notificações,
-- atualizam timeline, sincronizam auth.users -> public.users, etc.)
-- ----------------------------------------------------------------------------
select
  n.nspname as schema,
  p.proname as funcao,
  pg_get_functiondef(p.oid) as definicao
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.proname;

select
  event_object_table as tabela,
  trigger_name,
  action_timing,
  event_manipulation as evento,
  action_statement
from information_schema.triggers
where trigger_schema = 'public'
order by event_object_table, trigger_name;


-- ----------------------------------------------------------------------------
-- BLOCO 10 (opcional, avançado): gera um "CREATE TABLE" aproximado de cada
-- tabela, útil para colar como novo supabase.sql depois de revisado.
-- Requer a extensão pg_catalog padrão -- roda sem instalar nada extra.
-- ----------------------------------------------------------------------------
select
  'CREATE TABLE public.' || table_name || ' (' || chr(10) ||
  string_agg(
    '  ' || column_name || ' ' ||
    data_type ||
    case when character_maximum_length is not null
         then '(' || character_maximum_length || ')' else '' end ||
    case when is_nullable = 'NO' then ' NOT NULL' else '' end ||
    case when column_default is not null then ' DEFAULT ' || column_default else '' end,
    ',' || chr(10)
    order by ordinal_position
  ) || chr(10) || ');' as ddl_aproximado
from information_schema.columns
where table_schema = 'public'
group by table_name
order by table_name;
