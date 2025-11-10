-- Migration to add role column to existing profiles
-- This should be run after the schema update

-- Update existing profiles to have 'user' role if they don't have one
UPDATE public.profiles 
SET role = 'user' 
WHERE role IS NULL;

-- Make sure the first user (owner) gets admin role
-- You may need to adjust this based on your specific requirements
UPDATE public.profiles 
SET role = 'admin' 
WHERE id = (
  SELECT owner_id 
  FROM public.workspaces 
  ORDER BY created_at 
  LIMIT 1
);