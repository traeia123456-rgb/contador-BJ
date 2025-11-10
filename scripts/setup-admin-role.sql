-- PASO 1: Agregar columna de rol a la tabla profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user';

-- PASO 2: Configurar al usuario como administrador
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'traeia123456@gmail.com';

-- PASO 3: Verificar el cambio
SELECT email, role FROM profiles WHERE email = 'traeia123456@gmail.com';