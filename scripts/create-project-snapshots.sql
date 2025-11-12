-- Tabla de snapshots de proyectos
create table if not exists public.project_snapshots (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text not null, -- nombre del snapshot (incluye fecha/hora)
  created_at timestamp with time zone default now(),
  created_by uuid references auth.users(id)
);

-- Políticas RLS (solo usuarios autenticados)
alter table public.project_snapshots enable row level security;
create policy "Usuarios autenticados pueden ver snapshots" on public.project_snapshots for select using (auth.uid() is not null);
create policy "Usuarios autenticados pueden crear snapshots" on public.project_snapshots for insert with check (auth.uid() is not null);

-- Índice para búsqueda rápida por proyecto
create index idx_project_snapshots_project_id on public.project_snapshots(project_id);