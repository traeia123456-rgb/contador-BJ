-- Políticas RLS para la tabla public.projects
-- Ejecuta este archivo en el SQL Editor de Supabase.

-- Requisitos: Debe existir la función public.is_admin() definida en admin-policies.sql

-- SELECT: permitir leer proyectos si el usuario es miembro del workspace del proyecto o es admin
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

-- INSERT: permitir crear proyectos si el usuario es miembro del workspace o es admin
DROP POLICY IF EXISTS "projects_insert_members_or_admin" ON public.projects;
CREATE POLICY "projects_insert_members_or_admin" ON public.projects
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = projects.workspace_id
        AND wm.user_id = auth.uid()
    )
    OR public.is_admin()
  );

-- UPDATE: permitir actualizar proyectos si el usuario es miembro del workspace o es admin
DROP POLICY IF EXISTS "projects_update_members_or_admin" ON public.projects;
CREATE POLICY "projects_update_members_or_admin" ON public.projects
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = projects.workspace_id
        AND wm.user_id = auth.uid()
    )
    OR public.is_admin()
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = projects.workspace_id
        AND wm.user_id = auth.uid()
    )
    OR public.is_admin()
  );

-- DELETE: permitir borrar proyectos si el usuario es miembro del workspace o es admin
DROP POLICY IF EXISTS "projects_delete_members_or_admin" ON public.projects;
CREATE POLICY "projects_delete_members_or_admin" ON public.projects
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.workspace_members wm
      WHERE wm.workspace_id = projects.workspace_id
        AND wm.user_id = auth.uid()
    )
    OR public.is_admin()
  );

-- Verificación: listar políticas actuales de la tabla projects
-- SELECT policyname, cmd, roles, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'projects';