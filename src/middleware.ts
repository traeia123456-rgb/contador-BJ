import type { MiddlewareHandler } from 'astro';

export const onRequest: MiddlewareHandler = async (context, next) => {
  const p = context.url.pathname.toLowerCase();
  // Defensive block: prevent accidental exposure of internal SQL/script paths
  if (
    p.endsWith('.sql') ||
    p.startsWith('/scripts/') ||
    p.startsWith('/src/db/') ||
    p.includes('/db/migrations/')
  ) {
    return new Response('Not Found', { status: 404 });
  }
  return next();
};