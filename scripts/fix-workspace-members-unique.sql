-- Asegura que Upsert use conflicto en (workspace_id, user_id)
-- Ejecutar una vez en la base de datos

-- 1) Crear constraint única si no existe
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'workspace_members_workspace_user_key'
  ) THEN
    BEGIN
      ALTER TABLE public.workspace_members
      ADD CONSTRAINT workspace_members_workspace_user_key
      UNIQUE (workspace_id, user_id);
    EXCEPTION WHEN duplicate_table THEN
      -- Ya existe
      NULL;
    END;
  END IF;
END$$;

-- 2) Opcional: si ya existieran duplicados, mantener el más reciente y eliminar otros
-- Nota: adapte esta limpieza a su modelo; aquí se asume columna "id" incremental.
-- DELETE FROM public.workspace_members wm
-- USING (
--   SELECT workspace_id, user_id, MIN(id) AS keep_id
--   FROM public.workspace_members
--   GROUP BY workspace_id, user_id
-- ) k
-- WHERE wm.workspace_id = k.workspace_id
--   AND wm.user_id = k.user_id
--   AND wm.id <> k.keep_id;