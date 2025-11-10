-- Añade la columna faltante en workspaces para evitar errores 42703
-- Ejecuta en el SQL Editor de Supabase

ALTER TABLE public.workspaces
  ADD COLUMN IF NOT EXISTS is_principal boolean NOT NULL DEFAULT false;

-- Opcional: si quieres marcar un workspace como principal para pruebas
UPDATE public.workspaces SET is_principal = true WHERE id = '<workspace_id>';