# Configuração do Supabase (Genesis Hub)

Para ativar todo o banco de dados real e os logins com o Supabase, siga os passos abaixo:

## 1. Conectar as chaves no projeto
No seu arquivo `.env.local` (ou painel de variáveis de ambiente se estiver hospedado na Vercel/Render/AI Studio), adicione:
\`\`\`
NEXT_PUBLIC_SUPABASE_URL=https://SUA_URL_AQUI.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=SUA_CHAVE_ANONIMA_AQUI
SUPABASE_SERVICE_ROLE_KEY=SUA_CHAVE_SERVICE_ROLE_AQUI
\`\`\`
A \`SUPABASE_SERVICE_ROLE_KEY\` é obrigatória para que o Admin (você) consiga enviar o convite de acesso para os colaboradores sem precisar que eles façam um cadastro público.

## 2. Configurar Autenticação e E-mail no Supabase
1. Vá no menu **Authentication** > **Providers** e certifique-se de que o **Email** está ativado e a opção **Confirm email** está ativada (se desejar) e **desative** o "Sign up" aberto (se a plataforma permitir, para garantir que só criados por convite entrem).
2. Vá em **Authentication** > **Email Templates**. 
3. Edite o template **Invite User** para direcionar para o link do seu sistema:
   `{{ .SiteURL }}/reset-password?token={{ .TokenHash }}&type=invite`
4. Vá em **Authentication** > **URL Configuration** e defina a **Site URL** para o link do seu site (ou localhost:3000 em ambiente de desenvolvimento).

## 3. Rodar o SQL no SQL Editor
Copie e cole o código abaixo no menu **SQL Editor** do Supabase e clique em "Run" para criar toda a estrutura do banco de dados, com RLS, tabelas dinâmicas e o trigger que cria o usuário automático quando você convidar pela aba Admin do sistema:

\`\`\`sql
-- Habilitar a extensão UUID (geralmente já ativa)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Tabelas de Domínios (Menus Suspensos)
CREATE TABLE IF NOT EXISTS roles (
    name text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS departments (
    name text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS categories (
    name text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS priorities (
    name text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS statuses (
    name text PRIMARY KEY
);

-- Inserir dados padrão (apenas se estiverem vazios)
INSERT INTO roles (name) VALUES ('Admin'), ('Gestor'), ('Colaborador') ON CONFLICT DO NOTHING;
INSERT INTO departments (name) VALUES ('Comercial Externo'), ('Comercial Interno'), ('Eventos'), ('Cadastro'), ('Relacionamento'), ('Rastreador'), ('Diretoria'), ('TI'), ('Financeiro'), ('RH') ON CONFLICT DO NOTHING;
INSERT INTO categories (name) VALUES ('Arte'), ('Vídeo'), ('Landing Page'), ('Social Media'), ('Campanha'), ('Motion'), ('Site'), ('Automação'), ('Tráfego Pago'), ('Google Meu Negócio'), ('Institucional'), ('Outros') ON CONFLICT DO NOTHING;
INSERT INTO priorities (name) VALUES ('Baixa'), ('Normal'), ('Alta'), ('Urgente') ON CONFLICT DO NOTHING;
INSERT INTO statuses (name) VALUES ('Triagem'), ('Em Produção'), ('Revisão Interna'), ('Ajustes Solicitados'), ('Aguardando Aprovação'), ('Aprovado') ON CONFLICT DO NOTHING;

-- 2. Tabela de Usuários (Publica, sincronizada com o Auth)
CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name text NOT NULL,
    email text UNIQUE NOT NULL,
    role text REFERENCES roles(name) NOT NULL DEFAULT 'Colaborador',
    department text REFERENCES departments(name),
    avatar text,
    created_at timestamptz DEFAULT now()
);

-- Habilitar RLS e criar Políticas para usuários
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Leitura pública de usuários logados" ON users FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin pode tudo em users" ON users FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin')
);
CREATE POLICY "Users update own profile" ON users FOR UPDATE USING (auth.uid() = id);

-- Trigger para sincronizar Auth User novo (criado via convite Admin) com Public User
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, name, email)
  VALUES (
    new.id, 
    COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)), 
    new.email
  )
  ON CONFLICT (id) DO UPDATE SET email = new.email;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ativar o Trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 3. Tabela de Tarefas
CREATE TABLE IF NOT EXISTS tasks (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    title text NOT NULL,
    description text NOT NULL,
    category text REFERENCES categories(name) NOT NULL,
    priority text REFERENCES priorities(name) NOT NULL,
    status text REFERENCES statuses(name) NOT NULL,
    requester_id uuid REFERENCES users(id) NOT NULL,
    requester_name text NOT NULL,
    department text REFERENCES departments(name) NOT NULL,
    assignee_id uuid REFERENCES users(id),
    due_date timestamptz,
    reference_links text[],
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    started_at timestamptz,
    distributed_at timestamptz,
    completed_at timestamptz
);

-- 4. Tabela de Comentários
CREATE TABLE IF NOT EXISTS comments (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id uuid REFERENCES tasks(id) ON DELETE CASCADE,
    user_id uuid REFERENCES users(id),
    text text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- 5. Tabela de Timeline
CREATE TABLE IF NOT EXISTS timeline_events (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id uuid REFERENCES tasks(id) ON DELETE CASCADE,
    type text NOT NULL,
    user_id uuid REFERENCES users(id),
    description text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Habilitando RLS para o restante e permitindo leitura geral para logados e update/insert para logados
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE priorities ENABLE ROW LEVEL SECURITY;
ALTER TABLE statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;

-- Políticas de Domínio (Permitir Todos Lerem; Admin pode inserir/deletar/atualizar)
CREATE POLICY "Leitura logado roles" ON roles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin CRUD roles" ON roles FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Leitura logado departments" ON departments FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin CRUD departments" ON departments FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Leitura logado categories" ON categories FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin CRUD categories" ON categories FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Leitura logado priorities" ON priorities FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin CRUD priorities" ON priorities FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

CREATE POLICY "Leitura logado statuses" ON statuses FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin CRUD statuses" ON statuses FOR ALL USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'Admin'));

-- Políticas de Tarefas, Timeline e Comments
CREATE POLICY "All logados read/write tasks" ON tasks FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "All logados read/write comments" ON comments FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "All logados read/write timeline" ON timeline_events FOR ALL USING (auth.uid() IS NOT NULL);

-- Garantindo a atualização automática da data da tarefa (updated_at)
CREATE OR REPLACE FUNCTION update_modified_column() 
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_task_modtime ON tasks;
CREATE TRIGGER update_task_modtime 
BEFORE UPDATE ON tasks 
FOR EACH ROW 
EXECUTE PROCEDURE update_modified_column();

\`\`\`
