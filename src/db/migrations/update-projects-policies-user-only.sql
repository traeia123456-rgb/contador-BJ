-- Migration: actualizar políticas de public.projects
-- Objetivo: permitir INSERT a usuarios con rol 'user' (si son miembros del workspace)
-- y limitar UPDATE/DELETE únicamente a admin.

-- Asegurar que RLS está habilitado
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

-- SELECT: miembros del workspace o admin
DROP POLICY IF EXISTS "projects_select_members_or_admin" ON public.projects;
CREATE POLICY "projects_select_members_or_admin" ON public.projects
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = projects.workspace_id
        AND wm.user_id = auth.uid()
    )
    OR public.is_admin()
  );

-- INSERT: SOLO usuarios con rol 'user' y que sean miembros del workspace
DROP POLICY IF EXISTS "projects_insert_members_or_admin" ON public.projects;
DROP POLICY IF EXISTS "projects_insert_user_members" ON public.projects;
CREATE POLICY "projects_insert_user_members" ON public.projects
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'user'
    )
    AND EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = projects.workspace_id
        AND wm.user_id = auth.uid()
    )
  );

-- UPDATE: solo admin
DROP POLICY IF EXISTS "projects_update_members_or_admin" ON public.projects;
DROP POLICY IF EXISTS "projects_update_admin_only" ON public.projects;
CREATE POLICY "projects_update_admin_only" ON public.projects
  FOR UPDATE USING (
    public.is_admin()
  ) WITH CHECK (
    public.is_admin()
  );

-- DELETE: solo admin
DROP POLICY IF EXISTS "projects_delete_members_or_admin" ON public.projects;
DROP POLICY IF EXISTS "projects_delete_admin_only" ON public.projects;
CREATE POLICY "projects_delete_admin_only" ON public.projects
  FOR DELETE USING (
    public.is_admin()
  );