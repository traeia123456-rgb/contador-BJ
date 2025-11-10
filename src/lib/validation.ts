// Validación de entrada para formularios y datos
export const ValidationRules = {
  // Validación de email
  email: (email: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email) && email.length <= 255;
  },

  // Validación de contraseña
  password: (password: string): { valid: boolean; errors: string[] } => {
    const errors: string[] = [];
    
    if (password.length < 8) errors.push('La contraseña debe tener al menos 8 caracteres');
    if (!/[A-Z]/.test(password)) errors.push('Debe contener al menos una mayúscula');
    if (!/[a-z]/.test(password)) errors.push('Debe contener al menos una minúscula');
    if (!/[0-9]/.test(password)) errors.push('Debe contener al menos un número');
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) errors.push('Debe contener al menos un carácter especial');
    
    return { valid: errors.length === 0, errors };
  },

  // Validación de nombres y textos
  text: (text: string, minLength = 1, maxLength = 255): boolean => {
    if (!text || typeof text !== 'string') return false;
    const trimmed = text.trim();
    return trimmed.length >= minLength && trimmed.length <= maxLength;
  },

  // Sanitización de entrada
  sanitize: (input: string): string => {
    if (typeof input !== 'string') return '';
    return input
      .trim()
      .replace(/[<>]/g, '') // Eliminar tags HTML
      .replace(/['"]/g, '') // Eliminar comillas
      .replace(/javascript:/gi, '') // Eliminar javascript:
      .substring(0, 1000); // Limitar longitud
  },

  // Validación de UUID
  uuid: (uuid: string): boolean => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(uuid);
  },

  // Validación de números
  number: (num: any, min?: number, max?: number): boolean => {
    if (typeof num === 'string') {
      num = parseFloat(num);
    }
    if (typeof num !== 'number' || isNaN(num)) return false;
    if (min !== undefined && num < min) return false;
    if (max !== undefined && num > max) return false;
    return true;
  }
};

// Función auxiliar para validar formularios
export const validateForm = (formData: FormData, rules: Record<string, any>): { valid: boolean; errors: Record<string, string> } => {
  const errors: Record<string, string> = {};
  
  Object.keys(rules).forEach(field => {
    const value = formData.get(field);
    const fieldRules = rules[field];
    
    if (fieldRules.required && !value) {
      errors[field] = 'Este campo es requerido';
      return;
    }
    
    if (value && fieldRules.type === 'email' && !ValidationRules.email(value.toString())) {
      errors[field] = 'Email inválido';
    }
    
    if (value && fieldRules.type === 'password') {
      const validation = ValidationRules.password(value.toString());
      if (!validation.valid) {
        errors[field] = validation.errors[0];
      }
    }
    
    if (value && fieldRules.type === 'text') {
      const sanitized = ValidationRules.sanitize(value.toString());
      if (!ValidationRules.text(sanitized, fieldRules.minLength, fieldRules.maxLength)) {
        errors[field] = `Debe tener entre ${fieldRules.minLength || 1} y ${fieldRules.maxLength || 255} caracteres`;
      }
    }
    
    if (value && fieldRules.type === 'uuid' && !ValidationRules.uuid(value.toString())) {
      errors[field] = 'ID inválido';
    }
    
    if (value && fieldRules.type === 'number') {
      if (!ValidationRules.number(value, fieldRules.min, fieldRules.max)) {
        errors[field] = `Debe ser un número entre ${fieldRules.min || '-infinito'} y ${fieldRules.max || 'infinito'}`;
      }
    }
  });
  
  return { valid: Object.keys(errors).length === 0, errors };
};