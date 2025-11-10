-- Tabla para asignaciones de invitación y trigger para aplicarlas
create table if not exists public.invite_assignments (
  email text primary key,
  role text not null default 'user' check (role in ('user','admin')),
  workspaces jsonb not null default '[]'::jsonb,
  processed boolean not null default false,
  created_at timestamptz not null default now()
);

-- Función de trigger: aplica asignaciones cuando se crea un auth.user
create or replace function public.apply_invite_assignments()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  a record;
  w record;
begin
  select * into a from public.invite_assignments
   where lower(email) = lower(new.email) and processed = false
   limit 1;

  if a is null then
    return new;
  end if;

  -- Establecer rol del perfil si existe registro
  update public.profiles p set role = a.role where p.id = new.id;

  -- Crear membresías según array de workspaces
  for w in
    select (elem->>'workspace_id')::uuid as workspace_id,
           coalesce(elem->>'role','member') as role
    from jsonb_array_elements(a.workspaces) elem
  loop
    insert into public.workspace_members(workspace_id, user_id, role)
    values (w.workspace_id, new.id, w.role)
    on conflict (workspace_id, user_id)
      do update set role = excluded.role;
  end loop;

  update public.invite_assignments set processed = true where email = a.email;
  return new;
end;
$$;

-- Trigger adicional sobre auth.users
drop trigger if exists on_auth_user_invite_apply on auth.users;
create trigger on_auth_user_invite_apply
  after insert on auth.users
  for each row
  execute procedure public.apply_invite_assignments();