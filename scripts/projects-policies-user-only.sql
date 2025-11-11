-- Políticas RLS para projects: permitir INSERT solo a rol 'user' (miembro del workspace)
-- y restringir UPDATE/DELETE a admin.
-- Ejecuta este archivo en el SQL Editor de Supabase en tu proyecto.

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

-- Verificación: listar políticas actuales de la tabla projects
-- SELECT policyname, cmd, qual, with_check
-- FROM pg_policies WHERE schemaname = 'public' AND tablename = 'projects';