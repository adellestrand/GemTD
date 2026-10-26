import { SubmissionError, readLimitedJSON, validateSubmission, matchingRelease } from './validation.mjs';

export function createHandler({ url, serviceKey, allowedOrigins, fetchImpl = fetch }) {
  return async request => {
    const origin = request.headers.get('origin');
    const cors = { 'Vary': 'Origin', 'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
    if (origin && !allowedOrigins.includes(origin)) return new Response('{"error":"Origin not allowed."}', { status: 403, headers: cors });
    if (origin) cors['Access-Control-Allow-Origin'] = origin;
    cors['Access-Control-Allow-Headers'] = 'authorization, apikey, content-type, x-client-info';
    cors['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS';
    const reply = (status, body) => new Response(JSON.stringify(body), { status, headers: cors });
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    const query = new URL(request.url).searchParams;
    const releaseCheck = request.method === 'GET' && query.get('action') === 'release-check';
    if (request.method !== 'POST' && !releaseCheck) return reply(405, { error: 'Use POST.' });
    try {
      if (!url || !serviceKey) throw new SubmissionError('Leaderboard temporarily unavailable.', 503);
      if (releaseCheck) {
        // Public read-only deployment check. Never returns reports or player data,
        // signs up users, or grants unauthenticated access to submission.
        const hash = query.get('rules_hash');
        const version = query.get('game_version');
        const contentVersion = query.get('content_version');
        if (!/^[a-f0-9]{64}$/.test(hash || '') || !version || version.length > 80 || !/^\d{1,8}$/.test(contentVersion || ''))
          throw new SubmissionError('Invalid release identity.');
        const headers = { apikey: serviceKey, Authorization: 'Bearer '+serviceKey };
        const versions = await fetchImpl(url+'/rest/v1/leaderboard_releases?select=rules_hash,game_version,content_version,accepting&rules_hash=eq.'+hash, { headers });
        if (!versions.ok) throw new Error('Release lookup failed');
        const accepting = Boolean(matchingRelease(await versions.json(), hash, version, Number(contentVersion)));
        return reply(accepting ? 200 : 409, { accepting });
      }
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
