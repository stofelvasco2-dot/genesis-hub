-- ============================================================================
-- MIGRAÇÃO: notificações push (tabela push_subscriptions)
-- ============================================================================
-- Guarda a "inscrição" de push de cada navegador/celular que um usuário
-- autorizou a receber notificação (um usuário pode ter várias — celular,
-- notebook, etc). É usada só pelo servidor (via chave de serviço) pra saber
-- pra quem mandar o push quando alguém é notificado.
--
-- SEGURA para rodar em produção: só CRIA uma tabela nova. Não altera nem
-- apaga nenhuma tabela ou dado existente. Não referencia tasks nem
-- task_collaborators, então não tem nenhum risco de recursão de RLS como
-- os problemas anteriores.
-- ============================================================================

create table if not exists public.push_subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

comment on table public.push_subscriptions is
  'Inscrições de push notification (Web Push) de cada usuário, uma por navegador/dispositivo autorizado.';

alter table public.push_subscriptions enable row level security;

-- Cada pessoa só vê/gerencia as próprias inscrições (criar ao ativar,
-- apagar ao desativar). Admin/gestor incluído só por consistência com o
-- resto do sistema — na prática quem manda o push é o servidor, que usa a
-- chave de serviço e ignora RLS de qualquer forma.
create policy "Push subscriptions: cada um gerencia as próprias"
  on public.push_subscriptions
  for all
  using (user_id = auth.uid() or is_admin_or_gestor())
  with check (user_id = auth.uid() or is_admin_or_gestor());
