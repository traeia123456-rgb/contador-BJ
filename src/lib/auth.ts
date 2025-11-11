import { supabase } from './supabase'
import type { User } from '@supabase/supabase-js'

export type AuthError = {
  message: string
  code?: string
}

export type AuthResult<T> = {
  data: T | null
  error: AuthError | null
}

export async function signUp(email: string, password: string, metadata?: { 
  first_name?: string
  last_name?: string
  username?: string
}): Promise<AuthResult<User>> {
  try {
    // Validar email
    if (!email || !email.includes('@')) {
      return {
        data: null,
        error: {
          message: 'Por favor ingresa un email válido',
          code: 'invalid_email'
        }
      }
    }

    // Validar contraseña
    if (!password || password.length < 6) {
      return {
        data: null,
        error: {
          message: 'La contraseña debe tener al menos 6 caracteres',
          code: 'invalid_password'
        }
      }
    }

    // Generar un username por defecto si no se proporciona
    if (!metadata?.username) {
      const baseUsername = email.split('@')[0].replace(/[^a-zA-Z0-9_]/g, '')
      metadata = {
        ...metadata,
        username: baseUsername.length >= 3 ? baseUsername : `user_${Date.now().toString(36)}`
      }
    }

    // Intentar crear el usuario
    const site = (import.meta as any).env?.PUBLIC_SITE_URL || (typeof window !== 'undefined' ? window.location.origin : '');
    const redirectTo = String(site || '').replace(/\/$/, '') + '/login';
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: metadata,
        emailRedirectTo: redirectTo
      }
    })

    if (error) {
      // Traducir mensajes de error comunes
      const errorMessage = error.message === 'User already registered'
        ? 'Este email ya está registrado'
        : error.message === 'Password should be at least 6 characters'
        ? 'La contraseña debe tener al menos 6 caracteres'
        : error.message || 'Error al registrar usuario'

      throw new Error(errorMessage)
    }

    // Esperar un momento para asegurarnos de que el trigger ha creado el perfil
    await new Promise(resolve => setTimeout(resolve, 1000))

    return { 
      data: data.user,
      error: null
    }
  } catch (err: any) {
    return {
      data: null,
      error: {
        message: err.message || 'Error al registrar usuario',
        code: err.code
      }
    }
  }
}

export async function signIn(email: string, password: string): Promise<AuthResult<User>> {
  try {
    if (!email || !password) {
      return {
        data: null,
        error: {
          message: 'Por favor ingresa email y contraseña',
          code: 'missing_credentials'
        }
      }
    }

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    if (error) {
      // Traducir mensajes de error comunes
      const errorMessage = error.message === 'Invalid login credentials'
        ? 'Email o contraseña incorrectos'
        : error.message === 'Email not confirmed'
        ? 'Por favor confirma tu email antes de iniciar sesión'
        : error.message || 'Error al iniciar sesión'

      throw new Error(errorMessage)
    }

    return {
      data: data.user,
      error: null
    }
  } catch (err: any) {
    return {
      data: null,
      error: {
        message: err.message || 'Error al iniciar sesión',
        code: err.code
      }
    }
  }
}

export async function signOut(): Promise<AuthResult<null>> {
  try {
    const { error } = await supabase.auth.signOut()
    if (error) throw error

    return {
      data: null,
      error: null
    }
  } catch (err: any) {
    return {
      data: null,
      error: {
        message: err.message || 'Error al cerrar sesión',
        code: err.code
      }
    }
  }
}

export async function getUser(): Promise<AuthResult<User>> {
  try {
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error) throw error

    return {
      data: user,
      error: null
    }
  } catch (err: any) {
    return {
      data: null,
      error: {
        message: err.message || 'Error al obtener usuario',
        code: err.code
      }
    }
  }
}

export async function getSession(): Promise<AuthResult<User>> {
  try {
    const { data: { session }, error } = await supabase.auth.getSession()
    if (error) throw error

    return {
      data: session?.user || null,
      error: null
    }
  } catch (err: any) {
    return {
      data: null,
      error: {
        message: err.message || 'Error al obtener sesión',
        code: err.code
      }
    }
  }
}

// Función auxiliar para verificar si un usuario es administrador de un workspace
export async function isWorkspaceAdmin(workspaceId: string): Promise<AuthResult<boolean>> {
  try {
    const { data: user } = await getUser()
    if (!user) throw new Error('Usuario no autenticado')

    const { data, error } = await supabase
      .from('workspace_members')
      .select('role')
      .eq('workspace_id', workspaceId)
      .eq('user_id', user.id)
      .single()

    if (error) throw error

    return {
      data: data?.role === 'admin',
      error: null
    }
  } catch (err: any) {
    return {
      data: false,
      error: {
        message: err.message || 'Error al verificar permisos',
        code: err.code
      }
    }
  }
}