import { SubmissionError, readLimitedJSON, validateSubmission } from './validation.mjs';

export function createHandler({ url, serviceKey, allowedOrigins, fetchImpl = fetch }) {
  return async request => {
    const origin = request.headers.get('origin');
    const cors = { 'Vary': 'Origin', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
    if (origin && !allowedOrigins.includes(origin)) return new Response('{"error":"Origin not allowed."}', { status: 403, headers: cors });
    if (origin) cors['Access-Control-Allow-Origin'] = origin;
    cors['Access-Control-Allow-Headers'] = 'authorization, apikey, content-type, x-client-info';
    cors['Access-Control-Allow-Methods'] = 'POST, OPTIONS';
    const reply = (status, body) => new Response(JSON.stringify(body), { status, headers: cors });
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (request.method !== 'POST') return reply(405, { error: 'Use POST.' });
    try {
      if (!url || !serviceKey) throw new SubmissionError('Leaderboard temporarily unavailable.', 503);
      const token = request.headers.get('authorization');
      if (!token?.startsWith('Bearer ') || token.length > 8192) throw new SubmissionError('Sign in again.', 401);
      // Authenticate against Supabase Auth, never trust a user id from the body.
      const auth = await fetchImpl(url+'/auth/v1/user', { headers: { apikey: serviceKey, Authorization: token } });
      if (!auth.ok) throw new SubmissionError('Sign in again.', 401);
      const user = await auth.json();
      if (!user.id) throw new SubmissionError('Sign in again.', 401);
      const body = await readLimitedJSON(request);
      const headers = { apikey: serviceKey, Authorization: 'Bearer '+serviceKey, 'Content-Type': 'application/json' };
      const versions = await fetchImpl(url+'/rest/v1/leaderboard_releases?select=rules_hash,game_version,content_version,accepting', { headers });
      if (!versions.ok) throw new Error('Release lookup failed');
      const score = validateSubmission(body, await versions.json());
      const saved = await fetchImpl(url+'/rest/v1/rpc/submit_leaderboard_run', {
        method: 'POST', headers, body: JSON.stringify({ p_user: user.id, p_run: score.run_id,
          p_nickname: score.nickname, p_rules_hash: score.rules_hash, p_waves: score.completed_waves,
          p_lives: score.lives, p_seconds: score.simulation_seconds, p_seed: score.seed, p_report: score.report })
      });
      if (!saved.ok) {
        const error = await saved.json();
        if (String(error.message).includes('submission_rate_limit')) throw new SubmissionError('Too many submissions. Try again later.', 429);
        throw new Error('Score write failed');
      }
      return reply(200, { submitted: true, run_id: score.run_id, verification: 'unverified' });
    } catch (error) {
      if (error instanceof SubmissionError) return reply(error.status, { error: error.message });
      return reply(503, { error: 'Leaderboard temporarily unavailable. Your game is unaffected.' });
    }
  };
}
