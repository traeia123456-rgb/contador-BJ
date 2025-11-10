-- Habilitar extensiones necesarias
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Tabla de perfiles de usuario
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    username text unique,
    email text unique,
    first_name text,
    last_name text,
    avatar_url text,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    constraint username_length check (char_length(username) >= 3)
);

-- Tabla de espacios de trabajo
create table public.workspaces (
    id uuid default uuid_generate_v4() primary key,
    name text not null,
    description text,
    owner_id uuid references auth.users(id) on delete cascade not null,
    is_personal boolean default false,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Tabla de miembros del espacio de trabajo
create table public.workspace_members (
    workspace_id uuid references public.workspaces(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    role text not null check (role in ('owner', 'admin', 'member')),
    created_at timestamptz default now(),
    primary key (workspace_id, user_id)
);

-- Tabla de clientes
create table public.clients (
    id uuid default uuid_generate_v4() primary key,
    workspace_id uuid references public.workspaces(id) on delete cascade,
    name text not null,
    email text,
    phone text,
    address text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Tabla de proyectos
create table public.projects (
    id uuid default uuid_generate_v4() primary key,
    workspace_id uuid references public.workspaces(id) on delete cascade,
    client_id uuid references public.clients(id) on delete set null,
    name text not null,
    description text,
    status text check (status in ('active', 'completed', 'archived')) default 'active',
    start_date date,
    end_date date,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Tabla de registros de tiempo
create table public.time_entries (
    id uuid default uuid_generate_v4() primary key,
    project_id uuid references public.projects(id) on delete cascade,
    user_id uuid references auth.users(id) on delete cascade,
    description text,
    start_time timestamptz not null,
    end_time timestamptz,
    duration interval generated always as (end_time - start_time) stored,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Habilitar Row Level Security (RLS)
alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.clients enable row level security;
alter table public.projects enable row level security;
alter table public.time_entries enable row level security;

-- Políticas de seguridad para perfiles
create policy "Usuarios pueden ver sus propios perfiles"
    on public.profiles for select
    using (auth.uid() = id);

create policy "Usuarios pueden actualizar sus propios perfiles"
    on public.profiles for update
    using (auth.uid() = id);

-- Políticas para espacios de trabajo
create policy "Miembros pueden ver sus espacios de trabajo"
    on public.workspaces for select
    using (
        exists (
            select 1 from public.workspace_members
            where workspace_id = id
            and user_id = auth.uid()
        )
    );

create policy "Propietarios pueden gestionar espacios de trabajo"
    on public.workspaces for all
    using (owner_id = auth.uid());

-- Políticas para miembros de espacios de trabajo
create policy "Miembros pueden ver otros miembros"
    on public.workspace_members for select
    using (
        exists (
            select 1 from public.workspace_members
            where workspace_id = workspace_members.workspace_id
            and user_id = auth.uid()
        )
    );

-- Políticas para clientes
create policy "Miembros pueden ver clientes del workspace"
    on public.clients for select
    using (
        exists (
            select 1 from public.workspace_members
            where workspace_id = clients.workspace_id
            and user_id = auth.uid()
        )
    );

-- Helper: condición booleana para saber si el usuario es admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  );
$$;

-- Políticas para proyectos
drop policy if exists "Miembros pueden ver proyectos del workspace" on public.projects;
create policy "Miembros y admins pueden ver proyectos del workspace"
    on public.projects for select
    using (
        public.is_admin() or
        exists (
            select 1 from public.workspace_members
            where workspace_id = projects.workspace_id
            and user_id = auth.uid()
        )
    );

-- Permitir crear proyectos dentro del workspace si el usuario es miembro o admin
drop policy if exists "Miembros pueden crear proyectos del workspace" on public.projects;
create policy "Miembros y admins pueden crear proyectos del workspace"
    on public.projects for insert
    with check (
        public.is_admin() or
        exists (
            select 1 from public.workspace_members
            where workspace_id = projects.workspace_id
            and user_id = auth.uid()
        )
    );

-- Permitir actualizar proyectos del workspace si el usuario es miembro o admin
drop policy if exists "Miembros pueden actualizar proyectos del workspace" on public.projects;
create policy "Miembros y admins pueden actualizar proyectos del workspace"
    on public.projects for update
    using (
        public.is_admin() or
        exists (
            select 1 from public.workspace_members
            where workspace_id = projects.workspace_id
            and user_id = auth.uid()
        )
    )
    with check (
        public.is_admin() or
        exists (
            select 1 from public.workspace_members
            where workspace_id = projects.workspace_id
            and user_id = auth.uid()
        )
    );

-- Permitir borrar proyectos del workspace si el usuario es miembro o admin
drop policy if exists "Miembros pueden borrar proyectos del workspace" on public.projects;
create policy "Miembros y admins pueden borrar proyectos del workspace"
    on public.projects for delete
    using (
        public.is_admin() or
        exists (
            select 1 from public.workspace_members
            where workspace_id = projects.workspace_id
            and user_id = auth.uid()
        )
    );

-- Políticas para registros de tiempo
create policy "Usuarios pueden gestionar sus propios registros"
    on public.time_entries for all
    using (user_id = auth.uid());

-- Función para manejar nuevos usuarios
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
    username_base text;
    username_attempt text;
    counter int := 0;
    new_workspace_id uuid;
begin
    -- Generar username base desde email
    username_base := split_part(new.email, '@', 1);
    username_base := regexp_replace(username_base, '[^a-zA-Z0-9_]', '', 'g');
    
    -- Asegurar longitud mínima
    if length(username_base) < 3 then
        username_base := 'user_' || substr(new.id::text, 1, 8);
    end if;
    
    -- Intentar diferentes variaciones hasta encontrar un username disponible
    username_attempt := username_base;
    loop
        begin
            insert into public.profiles (
                id,
                email,
                username,
                first_name,
                last_name
            ) values (
                new.id,
                new.email,
                username_attempt,
                new.raw_user_meta_data->>'first_name',
                new.raw_user_meta_data->>'last_name'
            );
            
            -- Crear workspace personal
            insert into public.workspaces (
                name,
                owner_id,
                is_personal
            ) values (
                'Workspace Personal',
                new.id,
                true
            ) returning id into new_workspace_id;
            
            -- Añadir usuario como propietario del workspace
            insert into public.workspace_members (
                workspace_id,
                user_id,
                role
            ) values (
                new_workspace_id,
                new.id,
                'owner'
            );
            
            return new;
        exception 
            when unique_violation then
                counter := counter + 1;
                username_attempt := username_base || counter::text;
                if counter >= 5 then
                    username_attempt := 'user_' || substr(md5(new.id::text), 1, 8);
                end if;
                continue;
        end;
    end loop;
end;
$$;

-- Trigger para nuevos usuarios
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- Función para actualizar timestamps
create or replace function public.update_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- Triggers para actualizar timestamps
create trigger update_profiles_updated_at
    before update on public.profiles
    for each row execute procedure public.update_updated_at();

create trigger update_workspaces_updated_at
    before update on public.workspaces
    for each row execute procedure public.update_updated_at();

create trigger update_clients_updated_at
    before update on public.clients
    for each row execute procedure public.update_updated_at();

-- =========================
-- Tabla para guardar snapshots del contador BJ
-- =========================
create table if not exists public.bj_snapshots (
    id uuid default uuid_generate_v4() primary key,
    user_id uuid references auth.users(id) on delete set null,
    workspace_id uuid references public.workspaces(id) on delete set null,
    project_id uuid references public.projects(id) on delete set null,
    data jsonb not null,
    created_at timestamptz default now()
);

alter table public.bj_snapshots enable row level security;

create policy if not exists "Usuarios insertan sus snapshots (miembro del workspace)"
    on public.bj_snapshots for insert
    with check (
      user_id = auth.uid() and (
        workspace_id is null or exists (
          select 1 from public.workspace_members wm
          where wm.workspace_id = bj_snapshots.workspace_id
          and wm.user_id = auth.uid()
        )
      )
    );

create policy if not exists "Miembros del workspace ven snapshots"
    on public.bj_snapshots for select
    using (
      user_id = auth.uid() or exists (
        select 1 from public.workspace_members wm
        where wm.workspace_id = bj_snapshots.workspace_id
        and wm.user_id = auth.uid()
      )
    );

create policy if not exists "Usuarios actualizan sus snapshots"
    on public.bj_snapshots for update
    using (user_id = auth.uid());

create policy if not exists "Usuarios eliminan sus snapshots"
    on public.bj_snapshots for delete
    using (user_id = auth.uid());

-- Índices útiles para filtros
create index if not exists idx_bj_snapshots_created_at on public.bj_snapshots(created_at);
create index if not exists idx_bj_snapshots_workspace on public.bj_snapshots(workspace_id);
create index if not exists idx_bj_snapshots_project on public.bj_snapshots(project_id);

create trigger update_projects_updated_at
    before update on public.projects
    for each row execute procedure public.update_updated_at();

create trigger update_time_entries_updated_at
    before update on public.time_entries
    for each row execute procedure public.update_updated_at();