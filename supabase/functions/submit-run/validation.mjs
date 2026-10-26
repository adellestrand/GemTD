export class SubmissionError extends Error {
  constructor(message, status = 400) { super(message); this.status = status; }
}

export function nickname(value) {
  if (typeof value !== 'string') throw new SubmissionError('Choose a display name.');
  const name = value.trim().replace(/\s+/gu, ' ');
  if (!/^[\p{L}\p{N} ._-]{2,24}$/u.test(name))
    throw new SubmissionError('Use 2–24 letters, numbers, spaces, . _ or -.');
  return name;
}

export function matchingRelease(releases, hash, version, contentVersion) {
  return releases.find(x => x.rules_hash === hash && x.accepting === true &&
    x.game_version === version && x.content_version === contentVersion);
}

export function validateSubmission(body, releases) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new SubmissionError('Invalid submission.');
  const r = body.report;
  if (!r || typeof r !== 'object' || Array.isArray(r)) throw new SubmissionError('Missing run report.');
  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(r.run_id || ''))
    throw new SubmissionError('Invalid run identity.');
  const release = matchingRelease(releases, r.catalog_sha256, r.game_version, r.catalog_version);
  if (!release)
    throw new SubmissionError('This rules version is not accepting scores.', 409);
  if (r.balance_profile !== 'full-solo-dev' || r.wave_count !== 100 || r.debug_build !== false)
    throw new SubmissionError('Only release campaign runs can submit.');
  if (!['won', 'lost'].includes(r.outcome)) throw new SubmissionError('Finish the run before submitting.');
  if (r.resumed_from_checkpoint !== false || r.actions_truncated !== false || r.starting_checkpoint?.wave !== 1)
    throw new SubmissionError('Start a fresh run to enter this leaderboard.');
  if (!Number.isInteger(r.wave) || r.wave < 1 || r.wave > 100 || !Number.isInteger(r.lives) || r.lives < 0 || r.lives > 1000000)
    throw new SubmissionError('Invalid wave or lives.');
  if (typeof r.seed !== 'string' || !/^-?\d{1,19}$/.test(r.seed) || BigInt(r.seed) < -(2n**63n) || BigInt(r.seed) >= 2n**63n)
    throw new SubmissionError('Invalid seed.');
  if (!Array.isArray(r.actions) || r.actions.length > 2000 || !Array.isArray(r.waves) || r.waves.length !== r.wave)
    throw new SubmissionError('Incomplete run history.');
  if (r.outcome === 'won' && r.wave !== 100) throw new SubmissionError('Invalid victory.');
  let seconds = 0;
  for (let i = 0; i < r.waves.length; i++) {
    const wave = r.waves[i];
    const expected = i === r.waves.length-1 && r.outcome === 'lost' ? 'defeat' : 'cleared';
    if (!wave || wave.wave !== i+1 || wave.status !== expected || !Number.isFinite(wave.seconds) || wave.seconds < 0 || wave.seconds > 3600000)
      throw new SubmissionError('Inconsistent wave history.');
    seconds += wave.seconds;
  }
  return { run_id: r.run_id, nickname: nickname(body.nickname), rules_hash: r.catalog_sha256,
    completed_waves: r.outcome === 'won' ? 100 : r.wave-1, lives: r.lives,
    simulation_seconds: Math.round(seconds*1000)/1000, seed: r.seed, report: r };
}

export async function readLimitedJSON(request, limit = 1048576) {
  if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json'))
    throw new SubmissionError('Expected JSON.', 415);
  if (!request.body) throw new SubmissionError('Missing request.');
  const reader = request.body.getReader();
  const chunks = []; let bytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    bytes += value.byteLength;
    if (bytes > limit) { await reader.cancel(); throw new SubmissionError('Run report too large.', 413); }
    chunks.push(value);
  }
  const buffer = new Uint8Array(bytes); let offset = 0;
  for (const chunk of chunks) { buffer.set(chunk, offset); offset += chunk.length; }
  try { return JSON.parse(new TextDecoder().decode(buffer)); }
  catch { throw new SubmissionError('Invalid JSON.'); }
}
