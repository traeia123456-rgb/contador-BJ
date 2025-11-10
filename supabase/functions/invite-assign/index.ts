// Deno Edge Function: Invitar usuario y preasignar rol/membresías
// Requiere secretos: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { serve } from "https://deno.land/std@0.178.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type WorkspaceAssign = { workspace_id: string; role?: 'admin' | 'member' };
type Payload = { email: string; role?: 'user' | 'admin'; workspaces?: WorkspaceAssign[] };

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Use POST' }), { status: 405 });
  }
  const url = (globalThis as any).Deno?.env?.get('SUPABASE_URL');
  const key = (globalThis as any).Deno?.env?.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) {
    return new Response(JSON.stringify({ error: 'Missing SUPABASE secrets' }), { status: 500 });
  }
  const supabase = createClient(url, key);

  try {
    const payload: Payload = await req.json();
    const email = payload?.email?.trim();
    if (!email) throw new Error('email requerido');

    const role = payload.role === 'admin' ? 'admin' : 'user';
    const workspaces = Array.isArray(payload.workspaces) ? payload.workspaces : [];

    // Registrar asignaciones pendientes
    const { error: upError } = await supabase
      .from('invite_assignments')
      .upsert({ email, role, workspaces });
    if (upError) throw upError;

    // Enviar invitación
    const { error: invError } = await (supabase as any).auth.admin.inviteUserByEmail(email);
    if (invError) throw invError;

    return new Response(JSON.stringify({ success: true, email, role, workspacesCount: workspaces.length }), { status: 200 });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as any)?.message || 'Error desconocido' }), { status: 400 });
  }
});