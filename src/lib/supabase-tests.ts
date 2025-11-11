import { supabase } from './supabase';

interface TestResult {
  success: boolean;
  message: string;
  details?: Record<string, any>;
}

export async function testConnection(): Promise<TestResult> {
  try {
    const { data, error } = await supabase.from('profiles').select('count').single();
    if (error) throw error;
    return { success: true, message: 'Conexión exitosa con Supabase' };
  } catch (error: any) {
    console.error('Error de conexión:', error);
    return { 
      success: false, 
      message: `Error de conexión: ${error?.message || 'Error desconocido'}`
    };
  }
}

export async function testUserRegistration(): Promise<TestResult> {
  const testEmail = `test${Date.now()}@example.com`;
  const testPassword = 'test123456';
  
  try {
    // 1. Registrar usuario
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email: testEmail,
      password: testPassword,
    });

    if (authError) throw authError;
    if (!authData?.user?.id) throw new Error('No se pudo crear el usuario');

    // 2. Esperar 2 segundos para que el trigger cree el perfil
    await new Promise(resolve => setTimeout(resolve, 2000));

    // 3. Verificar perfil creado
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', authData.user.id)
      .single();

    if (profileError) throw profileError;

    // 4. Verificar workspace personal creado
    const { data: workspace, error: workspaceError } = await supabase
      .from('workspaces')
      .select('*')
      .eq('owner_id', authData.user.id)
      .single();

    if (workspaceError) throw workspaceError;
    if (!workspace?.id) throw new Error('No se pudo crear el workspace');

    // 5. Verificar membresía en workspace
    const { data: membership, error: membershipError } = await supabase
      .from('workspace_members')
      .select('*')
      .eq('workspace_id', workspace.id)
      .eq('user_id', authData.user.id)
      .single();

    if (membershipError) throw membershipError;

    // Limpiar datos de prueba
    await supabase.auth.signOut();

    return {
      success: true,
      message: 'Registro de usuario exitoso con creación de perfil y workspace',
      details: {
        user: authData.user,
        profile,
        workspace,
        membership
      }
    };

  } catch (error: any) {
    console.error('Error en prueba de registro:', error);
    return { 
      success: false, 
      message: `Error en prueba de registro: ${error?.message || 'Error desconocido'}`
    };
  }
}

export async function testSecurityPolicies(): Promise<TestResult> {
  try {
    // 1. Intentar acceder a perfiles sin autenticación
    const { data: profiles, error: profilesError } = await supabase
      .from('profiles')
      .select('*')
      .limit(1);

    if (!profilesError) {
      throw new Error('Se pudo acceder a perfiles sin autenticación');
    }

    // 2. Intentar acceder a workspaces sin autenticación
    const { data: workspaces, error: workspacesError } = await supabase
      .from('workspaces')
      .select('*')
      .limit(1);

    if (!workspacesError) {
      throw new Error('Se pudo acceder a workspaces sin autenticación');
    }

    return {
      success: true,
      message: 'Las políticas de seguridad están funcionando correctamente'
    };

  } catch (error: any) {
    console.error('Error en prueba de seguridad:', error);
    return { 
      success: false, 
      message: `Error en prueba de seguridad: ${error?.message || 'Error desconocido'}`
    };
  }
}

export async function runAllTests() {
  const results = {
    connection: await testConnection(),
    registration: await testUserRegistration(),
    security: await testSecurityPolicies()
  };

  return results;
}