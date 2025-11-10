import { ValidationRules } from './validation';

// Rate limiting para prevenir ataques de fuerza bruta
export class RateLimiter {
  private attempts: Map<string, { count: number; resetTime: number }> = new Map();
  private readonly maxAttempts: number;
  private readonly windowMs: number;

  constructor(maxAttempts = 5, windowMs = 15 * 60 * 1000) { // 5 intentos en 15 minutos
    this.maxAttempts = maxAttempts;
    this.windowMs = windowMs;
  }

  isAllowed(key: string): boolean {
    const now = Date.now();
    const attempt = this.attempts.get(key);

    if (!attempt) {
      this.attempts.set(key, { count: 1, resetTime: now + this.windowMs });
      return true;
    }

    if (now > attempt.resetTime) {
      // Ventana expiró, reiniciar contador
      this.attempts.set(key, { count: 1, resetTime: now + this.windowMs });
      return true;
    }

    if (attempt.count >= this.maxAttempts) {
      return false;
    }

    attempt.count++;
    return true;
  }

  getRemainingAttempts(key: string): number {
    const attempt = this.attempts.get(key);
    if (!attempt) return this.maxAttempts;
    return Math.max(0, this.maxAttempts - attempt.count);
  }

  getResetTime(key: string): number {
    const attempt = this.attempts.get(key);
    return attempt ? attempt.resetTime : 0;
  }
}

// Sanitización de datos para prevenir XSS
export const sanitizeData = (data: any): any => {
  if (typeof data === 'string') {
    return data
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#x27;')
      .replace(/\//g, '&#x2F;');
  }
  
  if (typeof data === 'object' && data !== null) {
    if (Array.isArray(data)) {
      return data.map(sanitizeData);
    }
    
    const sanitized: any = {};
    for (const key in data) {
      if (data.hasOwnProperty(key)) {
        sanitized[key] = sanitizeData(data[key]);
      }
    }
    return sanitized;
  }
  
  return data;
};

// Validación de datos de entrada para Supabase
export const validateSupabaseData = (table: string, data: any): { valid: boolean; errors: string[] } => {
  const errors: string[] = [];
  
  switch (table) {
    case 'profiles':
      if (data.username && !ValidationRules.text(data.username, 3, 50)) {
        errors.push('Username debe tener entre 3 y 50 caracteres');
      }
      if (data.email && !ValidationRules.email(data.email)) {
        errors.push('Email inválido');
      }
      break;
      
    case 'workspaces':
      if (data.name && !ValidationRules.text(data.name, 1, 100)) {
        errors.push('Nombre del workspace debe tener entre 1 y 100 caracteres');
      }
      if (data.description && !ValidationRules.text(data.description, 0, 500)) {
        errors.push('Descripción debe tener máximo 500 caracteres');
      }
      break;
      
    case 'projects':
      if (data.name && !ValidationRules.text(data.name, 1, 200)) {
        errors.push('Nombre del proyecto debe tener entre 1 y 200 caracteres');
      }
      if (data.description && !ValidationRules.text(data.description, 0, 1000)) {
        errors.push('Descripción debe tener máximo 1000 caracteres');
      }
      if (data.status && !['active', 'completed', 'archived'].includes(data.status)) {
        errors.push('Estado inválido');
      }
      break;
      
    case 'clients':
      if (data.name && !ValidationRules.text(data.name, 1, 200)) {
        errors.push('Nombre del cliente debe tener entre 1 y 200 caracteres');
      }
      if (data.email && !ValidationRules.email(data.email)) {
        errors.push('Email del cliente inválido');
      }
      if (data.phone && !ValidationRules.text(data.phone, 0, 20)) {
        errors.push('Teléfono debe tener máximo 20 caracteres');
      }
      break;
      
    case 'time_entries':
      if (data.description && !ValidationRules.text(data.description, 0, 500)) {
        errors.push('Descripción debe tener máximo 500 caracteres');
      }
      if (data.start_time && isNaN(Date.parse(data.start_time))) {
        errors.push('Fecha de inicio inválida');
      }
      if (data.end_time && isNaN(Date.parse(data.end_time))) {
        errors.push('Fecha de fin inválida');
      }
      break;
      
    case 'bj_snapshots':
      if (data.data && typeof data.data !== 'object') {
        errors.push('Datos del snapshot deben ser un objeto JSON válido');
      }
      break;
      
    default:
      errors.push('Tabla no válida para validación');
  }
  
  return { valid: errors.length === 0, errors };
};

// Generador de tokens seguros
export const generateSecureToken = (length = 32): string => {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  let token = '';
  const randomBytes = new Uint8Array(length);
  crypto.getRandomValues(randomBytes);
  
  for (let i = 0; i < length; i++) {
    token += chars[randomBytes[i] % chars.length];
  }
  
  return token;
};