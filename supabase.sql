-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Tables for Dropdowns (Menus Suspensos)
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

-- 2. Insert default values for dropdowns (ON CONFLICT DO NOTHING to avoid duplicate errors)
INSERT INTO roles (name) VALUES ('Admin'), ('Gestor'), ('Colaborador') ON CONFLICT DO NOTHING;
INSERT INTO departments (name) VALUES ('Comercial Externo'), ('Comercial Interno'), ('Eventos'), ('Cadastro'), ('Relacionamento'), ('Rastreador'), ('Diretoria'), ('TI'), ('Financeiro'), ('RH') ON CONFLICT DO NOTHING;
INSERT INTO categories (name) VALUES ('Arte'), ('Vídeo'), ('Landing Page'), ('Social Media'), ('Campanha'), ('Motion'), ('Site'), ('Automação'), ('Tráfego Pago'), ('Google Meu Negócio'), ('Institucional'), ('Outros') ON CONFLICT DO NOTHING;
INSERT INTO priorities (name) VALUES ('Baixa'), ('Normal'), ('Alta'), ('Urgente') ON CONFLICT DO NOTHING;
INSERT INTO statuses (name) VALUES ('Triagem'), ('Em Produção'), ('Revisão Interna'), ('Ajustes Solicitados'), ('Aguardando Aprovação'), ('Aprovado') ON CONFLICT DO NOTHING;

-- 3. Users table (Legacy)
CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name text NOT NULL,
    role text NOT NULL,
    tipo_usuario text,
    avatar text,
    department text REFERENCES departments(name),
    email text UNIQUE NOT NULL
);

-- 3.1. Perfis table (New)
CREATE TABLE IF NOT EXISTS perfis (
    id uuid PRIMARY KEY REFERENCES auth.users(id),
    nome text NOT NULL,
    email text UNIQUE NOT NULL,
    cargo text NOT NULL,
    tipo_usuario text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 4. Tasks table
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

-- 5. Comments table
CREATE TABLE IF NOT EXISTS comments (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id uuid REFERENCES tasks(id) ON DELETE CASCADE,
    user_id uuid REFERENCES users(id),
    text text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- 6. Timeline Events table
CREATE TABLE IF NOT EXISTS timeline_events (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id uuid REFERENCES tasks(id) ON DELETE CASCADE,
    type text NOT NULL,
    user_id uuid REFERENCES users(id),
    description text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Drop policies safely by wrapping in DO block if they exist
DO $$ BEGIN
    -- Just enable RLS
    ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
    ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
    ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
    ALTER TABLE priorities ENABLE ROW LEVEL SECURITY;
    ALTER TABLE statuses ENABLE ROW LEVEL SECURITY;
    ALTER TABLE users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE perfis ENABLE ROW LEVEL SECURITY;
    ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
    ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
    ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;
EXCEPTION
    WHEN others THEN NULL;
END $$;

-- Instead of complex drop logic for policies, we use safe drop and create
DROP POLICY IF EXISTS "Allow public read access for roles" ON roles;
DROP POLICY IF EXISTS "Allow public insert for roles" ON roles;
DROP POLICY IF EXISTS "Allow public delete for roles" ON roles;
DROP POLICY IF EXISTS "Allow public read access for departments" ON departments;
DROP POLICY IF EXISTS "Allow public insert for departments" ON departments;
DROP POLICY IF EXISTS "Allow public delete for departments" ON departments;
DROP POLICY IF EXISTS "Allow public read access for categories" ON categories;
DROP POLICY IF EXISTS "Allow public insert for categories" ON categories;
DROP POLICY IF EXISTS "Allow public delete for categories" ON categories;
DROP POLICY IF EXISTS "Allow public read access for priorities" ON priorities;
DROP POLICY IF EXISTS "Allow public insert for priorities" ON priorities;
DROP POLICY IF EXISTS "Allow public delete for priorities" ON priorities;
DROP POLICY IF EXISTS "Allow public read access for statuses" ON statuses;
DROP POLICY IF EXISTS "Allow public insert for statuses" ON statuses;
DROP POLICY IF EXISTS "Allow public delete for statuses" ON statuses;
DROP POLICY IF EXISTS "Users can view all users" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Users can insert" ON users;
DROP POLICY IF EXISTS "Users can view all perfis" ON perfis;
DROP POLICY IF EXISTS "Users can update their own perfil" ON perfis;
DROP POLICY IF EXISTS "Users can insert perfil" ON perfis;
DROP POLICY IF EXISTS "Users can view all tasks" ON tasks;
DROP POLICY IF EXISTS "Users can create tasks" ON tasks;
DROP POLICY IF EXISTS "Users can update tasks" ON tasks;
DROP POLICY IF EXISTS "Users can delete tasks" ON tasks;
DROP POLICY IF EXISTS "Users can view comments" ON comments;
DROP POLICY IF EXISTS "Users can create comments" ON comments;
DROP POLICY IF EXISTS "Users can delete comments" ON comments;
DROP POLICY IF EXISTS "Users can view timeline" ON timeline_events;
DROP POLICY IF EXISTS "Users can create timeline events" ON timeline_events;
DROP POLICY IF EXISTS "Users can delete timeline events" ON timeline_events;

-- Dropdowns should be readable by everyone, but we also want admins to add/delete
CREATE POLICY "Allow public read access for roles" ON roles FOR SELECT USING (true);
CREATE POLICY "Allow public insert for roles" ON roles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete for roles" ON roles FOR DELETE USING (true);

CREATE POLICY "Allow public read access for departments" ON departments FOR SELECT USING (true);
CREATE POLICY "Allow public insert for departments" ON departments FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete for departments" ON departments FOR DELETE USING (true);

CREATE POLICY "Allow public read access for categories" ON categories FOR SELECT USING (true);
CREATE POLICY "Allow public insert for categories" ON categories FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete for categories" ON categories FOR DELETE USING (true);

CREATE POLICY "Allow public read access for priorities" ON priorities FOR SELECT USING (true);
CREATE POLICY "Allow public insert for priorities" ON priorities FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete for priorities" ON priorities FOR DELETE USING (true);

CREATE POLICY "Allow public read access for statuses" ON statuses FOR SELECT USING (true);
CREATE POLICY "Allow public insert for statuses" ON statuses FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public delete for statuses" ON statuses FOR DELETE USING (true);

-- Users Policy
CREATE POLICY "Users can view all users" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile" ON users FOR UPDATE USING (true);
CREATE POLICY "Users can insert" ON users FOR INSERT WITH CHECK (true);

-- Perfis Policy
CREATE POLICY "Users can view all perfis" ON perfis FOR SELECT USING (true);
CREATE POLICY "Users can update their own perfil" ON perfis FOR UPDATE USING (true);
CREATE POLICY "Users can insert perfil" ON perfis FOR INSERT WITH CHECK (true);

-- Tasks Policy
CREATE POLICY "Users can view all tasks" ON tasks FOR SELECT USING (true);
CREATE POLICY "Users can create tasks" ON tasks FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update tasks" ON tasks FOR UPDATE USING (true);
CREATE POLICY "Users can delete tasks" ON tasks FOR DELETE USING (true);

-- Comments Policy
CREATE POLICY "Users can view comments" ON comments FOR SELECT USING (true);
CREATE POLICY "Users can create comments" ON comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can delete comments" ON comments FOR DELETE USING (true);

-- Timeline Policy
CREATE POLICY "Users can view timeline" ON timeline_events FOR SELECT USING (true);
CREATE POLICY "Users can create timeline events" ON timeline_events FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can delete timeline events" ON timeline_events FOR DELETE USING (true);

-- Create a trigger to automatically update the updated_at column on tasks
CREATE OR REPLACE FUNCTION update_modified_column() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_task_modtime ON tasks;
CREATE TRIGGER update_task_modtime BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE PROCEDURE update_modified_column();
