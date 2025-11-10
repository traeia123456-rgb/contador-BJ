-- Políticas RLS para permisos de administrador
-- Ejecuta este archivo en el SQL editor de Supabase.

-- Helper: condición booleana para saber si el usuario es admin
-- Para evitar recursión en políticas sobre profiles, usamos una función SECURITY DEFINER
-- que evalúa el rol de forma segura.

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

-- Profiles: permitir a admin leer, insertar, actualizar y borrar
DROP POLICY IF EXISTS "admin_select_profiles" ON profiles;
CREATE POLICY "admin_select_profiles" ON profiles
  FOR SELECT USING (
    public.is_admin()
  );

-- Permitir a cada usuario leer su propio perfil, para detección de rol en el frontend
DROP POLICY IF EXISTS "own_select_profiles" ON profiles;
CREATE POLICY "own_select_profiles" ON profiles
  FOR SELECT USING (
    id = auth.uid()
  );

DROP POLICY IF EXISTS "admin_insert_profiles" ON profiles;
CREATE POLICY "admin_insert_profiles" ON profiles
  FOR INSERT WITH CHECK (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_update_profiles" ON profiles;
CREATE POLICY "admin_update_profiles" ON profiles
  FOR UPDATE USING (
    public.is_admin()
  ) WITH CHECK (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_delete_profiles" ON profiles;
CREATE POLICY "admin_delete_profiles" ON profiles
  FOR DELETE USING (
    public.is_admin()
  );

-- Workspaces
DROP POLICY IF EXISTS "admin_select_workspaces" ON workspaces;
CREATE POLICY "admin_select_workspaces" ON workspaces
  FOR SELECT USING (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_insert_workspaces" ON workspaces;
CREATE POLICY "admin_insert_workspaces" ON workspaces
  FOR INSERT WITH CHECK (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_update_workspaces" ON workspaces;
CREATE POLICY "admin_update_workspaces" ON workspaces
  FOR UPDATE USING (
    public.is_admin()
  ) WITH CHECK (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_delete_workspaces" ON workspaces;
CREATE POLICY "admin_delete_workspaces" ON workspaces
  FOR DELETE USING (
    public.is_admin()
  );

-- Workspace members
DROP POLICY IF EXISTS "admin_select_workspace_members" ON workspace_members;
CREATE POLICY "admin_select_workspace_members" ON workspace_members
  FOR SELECT USING (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_insert_workspace_members" ON workspace_members;
CREATE POLICY "admin_insert_workspace_members" ON workspace_members
  FOR INSERT WITH CHECK (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_update_workspace_members" ON workspace_members;
CREATE POLICY "admin_update_workspace_members" ON workspace_members
  FOR UPDATE USING (
    public.is_admin()
  ) WITH CHECK (
    public.is_admin()
  );

DROP POLICY IF EXISTS "admin_delete_workspace_members" ON workspace_members;
CREATE POLICY "admin_delete_workspace_members" ON workspace_members
  FOR DELETE USING (
    public.is_admin()
  );

-- Si existen tablas de negocio adicionales (clients, projects, time_entries)
-- aplica el mismo patrón:
-- CREATE POLICY IF NOT EXISTS "admin_select_clients" ON clients FOR SELECT USING (...);
-- etc.