import { createHandler } from './handler.mjs';

const allowedOrigins = (Deno.env.get('LEADERBOARD_ORIGINS') || 'https://adellestrand.github.io')
  .split(',').map(x => x.trim()).filter(Boolean);
Deno.serve(createHandler({ url: Deno.env.get('SUPABASE_URL'),
  serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), allowedOrigins }));
