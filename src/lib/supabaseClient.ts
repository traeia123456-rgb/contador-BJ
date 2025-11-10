import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL;
const supabaseKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Las variables de entorno de Supabase no están configuradas');
}

export const getSupabase = (persistSession: boolean = true): SupabaseClient => {
  return createClient(supabaseUrl, supabaseKey, {
    auth: {
      persistSession,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  });
};