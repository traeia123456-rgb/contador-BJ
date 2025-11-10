-- Script para agregar roles de usuario y configurar admin

-- Paso 1: Agregar columna de rol a la tabla profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator'));

-- Paso 2: Actualizar el usuario traeia123456@gmail.com a rol admin
UPDATE profiles 
SET role = 'admin' 
WHERE id = (
  SELECT id 
  FROM auth.users 
  WHERE email = 'traeia123456@gmail.com'
);

-- Paso 3: Verificar que el usuario fue actualizado correctamente
SELECT 
  p.id,
  p.email,
  p.role,
  p.created_at
FROM profiles p
WHERE p.email = 'traeia123456@gmail.com';

-- Paso 4: Crear política de seguridad para que solo los admins puedan ver todos los usuarios
CREATE POLICY "Admins can view all users" ON profiles
  FOR SELECT
  USING (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );

-- Paso 5: Crear política para que los usuarios solo puedan ver su propio perfil
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Paso 6: Actualizar política existente para workspace_members
DROP POLICY IF EXISTS "workspace_members_select_policy" ON workspace_members;

CREATE POLICY "workspace_members_select_policy" ON workspace_members
  FOR SELECT
  USING (
    workspace_id IN (
      SELECT workspace_id 
      FROM workspace_members 
      WHERE user_id = auth.uid()
    ) 
    OR 
    auth.uid() IN (
      SELECT id FROM profiles WHERE role = 'admin'
    )
  );