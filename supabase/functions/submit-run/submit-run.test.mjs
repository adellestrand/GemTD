import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nickname, validateSubmission, readLimitedJSON } from './validation.mjs';
import { createHandler } from './handler.mjs';

const hash = '50ead0c1187245bc9c9da4224a0b47296d3f0445eaca5391cdcf6c698a5812bb';
const releases = [{ rules_hash:hash, game_version:'1.4.1-dev', content_version:10, accepting:true }];
const fixture = () => ({ nickname:' Test Åke ', report:{
  run_id:'12345678-abcd-abcd-abcd-123456789012', catalog_sha256:hash,
  game_version:'1.4.1-dev', catalog_version:10, balance_profile:'full-solo-dev', wave_count:100,
  debug_build:false, outcome:'lost', resumed_from_checkpoint:false, actions_truncated:false,
  starting_checkpoint:{wave:1}, wave:2, lives:0, seed:'9223372036854775807', actions:[],
  waves:[{wave:1,status:'cleared',seconds:50},{wave:2,status:'defeat',seconds:12.3}]
}});
const req = (body=fixture(), headers={}, method='POST') => new Request('https://example.test/submit-run', {
  method, headers:{'Content-Type':'application/json',Origin:'https://adellestrand.github.io',...headers},
  ...(method === 'POST' ? {body:JSON.stringify(body)} : {})
});
const handler = fetchImpl => createHandler({url:'https://project.test',serviceKey:'PRIVATE_TEST_KEY',allowedOrigins:['https://adellestrand.github.io'],fetchImpl});

test('score derived from completed waves; submitted totals cannot override it',()=>{
  const body=fixture(); body.completed_waves=100; body.user_id='spoof';
  const score=validateSubmission(body,releases);
  assert.equal(score.completed_waves,1); assert.equal(score.nickname,'Test Åke');
  assert.equal(score.simulation_seconds,62.3); assert.equal(score.user_id,undefined);
});
test('victory requires all 100 cleared waves',()=>{
  const body=fixture(); body.report.outcome='won';
  assert.throws(()=>validateSubmission(body,releases));
  body.report.wave=100; body.report.waves=Array.from({length:100},(_,i)=>({wave:i+1,status:'cleared',seconds:1}));
  assert.equal(validateSubmission(body,releases).completed_waves,100);
});
for (const [field,value] of Object.entries({debug_build:true,resumed_from_checkpoint:true,actions_truncated:true,
  outcome:'combat',wave:101,lives:-1,seed:'9223372036854775808',catalog_sha256:'a'.repeat(64),catalog_version:11,
  balance_profile:'review-v1',wave_count:10,run_id:'invalid'})) {
  test(`rejects invalid ${field}`,()=>{
    const body=fixture(); body.report[field]=value;
    assert.throws(()=>validateSubmission(body,releases));
  });
}
test('rejects incomplete, reordered and nonfinite histories',()=>{
  for(const change of [r=>r.waves.pop(),r=>r.waves[0].wave=2,r=>r.waves[1].status='cleared',r=>r.waves[0].seconds=NaN,r=>r.starting_checkpoint.wave=2,r=>r.actions=Array(2001).fill({})]) {
    const body=fixture();change(body.report);assert.throws(()=>validateSubmission(body,releases));
  }
});
test('nickname is text only, bounded, with international letters',()=>{
  assert.equal(nickname('  Åke   2 '),'Åke 2');
  for(const value of ['x','x'.repeat(25),'[url]bad','<script>','a\u0000b']) assert.throws(()=>nickname(value));
});
test('bounded JSON rejects bad types, invalid JSON, and oversized streams',async()=>{
  await assert.rejects(readLimitedJSON(new Request('https://x.test',{method:'POST',body:'hi'})),{status:415});
  await assert.rejects(readLimitedJSON(new Request('https://x.test',{method:'POST',body:'{',headers:{'content-type':'application/json'}})),{status:400});
  await assert.rejects(readLimitedJSON(req(),10),{status:413});
});
test('preflight allows only the published origin; unauthenticated writes do not reach services',async()=>{
  const h=handler(()=>assert.fail('must not fetch'));
  const preflight=await h(req(null,{},'OPTIONS')); assert.equal(preflight.status,204);
  assert.equal(preflight.headers.get('access-control-allow-origin'),'https://adellestrand.github.io');
  assert.equal((await h(req(null,{Origin:'https://evil.test'},'OPTIONS'))).status,403);
  assert.equal((await h(req())).status,401);
  assert.equal((await h(req(null,{},'GET'))).status,405);
});
test('spoofed identity rejected by Auth before reading/writing scores',async()=>{
  const calls=[];
  const h=handler(async url=>{calls.push(url);return Response.json({error:'bad token'},{status:401});});
  const response=await h(req(fixture(),{Authorization:'Bearer forged'}));
  assert.equal(response.status,401);assert.equal(calls.length,1);assert.match(calls[0],/auth\/v1\/user$/);
});
test('authenticated write uses Auth identity and derived score, never caller identity',async()=>{
  const calls=[];
  const h=handler(async(url,options)=>{
    calls.push({url,options});
    if(url.endsWith('/user')) return Response.json({id:'trusted-user'});
    if(url.includes('leaderboard_releases?')) return Response.json(releases);
    return Response.json('12345678-abcd-abcd-abcd-123456789012');
  });
  const body=fixture();body.user_id='spoof';body.verified=true;
  const response=await h(req(body,{Authorization:'Bearer real-user-token'}));
  assert.equal(response.status,200);assert.equal((await response.json()).verification,'unverified');
  const args=JSON.parse(calls[2].options.body);
  assert.equal(args.p_user,'trusted-user');assert.equal(args.p_waves,1);assert.equal(args.p_nickname,'Test Åke');
  assert.equal(args.verified,undefined);assert.equal(calls[0].options.headers.Authorization,'Bearer real-user-token');
});
test('rate limit and backend errors are safe, without privileged credentials',async()=>{
  for(const [message,status] of [['submission_rate_limit',429],['PRIVATE_TEST_KEY database failure',503]]) {
    const h=handler(async url=>url.endsWith('/user') ? Response.json({id:'user'}) : url.includes('leaderboard_releases?') ? Response.json(releases) : Response.json({message},{status:400}));
    const response=await h(req(fixture(),{Authorization:'Bearer token'}));
    assert.equal(response.status,status);assert.ok(!(await response.text()).includes('PRIVATE_TEST_KEY'));
  }
});
