-- Crea la tabla public.bj_snapshots y sus políticas de RLS
-- Ejecuta este script en el SQL Editor de tu proyecto Supabase

-- Extensión necesaria para gen_random_uuid()
create extension if not exists pgcrypto;

-- Tabla de snapshots
create table if not exists public.bj_snapshots (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete set null,
  workspace_id uuid references public.workspaces(id) on delete set null,
  project_id uuid references public.projects(id) on delete set null,
  data jsonb not null,
  created_at timestamptz default now()
);

-- Habilitar RLS
alter table public.bj_snapshots enable row level security;

-- Políticas: insertar solo el propio snapshot y, si hay workspace, ser miembro
drop policy if exists "Usuarios insertan sus snapshots (miembro del workspace)" on public.bj_snapshots;
create policy "Usuarios insertan sus snapshots (miembro del workspace)"
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

-- Políticas: seleccionar snapshots propios o de workspaces donde eres miembro
drop policy if exists "Miembros del workspace ven snapshots" on public.bj_snapshots;
create policy "Miembros del workspace ven snapshots"
  on public.bj_snapshots for select
  using (
    user_id = auth.uid() or exists (
      select 1 from public.workspace_members wm
      where wm.workspace_id = bj_snapshots.workspace_id
        and wm.user_id = auth.uid()
    )
  );

-- Políticas: actualizar y borrar solo los propios
drop policy if exists "Usuarios actualizan sus snapshots" on public.bj_snapshots;
create policy "Usuarios actualizan sus snapshots"
  on public.bj_snapshots for update
  using (user_id = auth.uid());

drop policy if exists "Usuarios eliminan sus snapshots" on public.bj_snapshots;
create policy "Usuarios eliminan sus snapshots"
  on public.bj_snapshots for delete
  using (user_id = auth.uid());

-- Índices útiles para filtros
create index if not exists idx_bj_snapshots_created_at on public.bj_snapshots(created_at);
create index if not exists idx_bj_snapshots_workspace on public.bj_snapshots(workspace_id);
create index if not exists idx_bj_snapshots_project on public.bj_snapshots(project_id);

-- Verificación rápida
-- select schemaname, tablename from pg_tables where schemaname='public' and tablename='bj_snapshots';