"""Explicit integration test against the configured Supabase project.

Default: read/preflight/denied access only. --submit-fixture creates one disposable
anonymous test player and score; clean up the recorded ids with administrative SQL.
Never prints or saves player tokens. This is not a gameplay authenticity test.
"""
from pathlib import Path
import json
import sys
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT/'assets/online/leaderboard.json').read_text(encoding='utf8'))
report = json.loads((ROOT/'output/leaderboard-live-fixture/maze-01.json').read_text(encoding='utf8')) if '--submit-fixture' in sys.argv else None
url = config['project_url'].rstrip('/')
key = config['publishable_key']
origin = 'https://adellestrand.github.io'

def request(path, body=None, token=None, method='POST'):
    headers = {'apikey':key,'Origin':origin,'Content-Type':'application/json'}
    if token:
        headers['Authorization'] = 'Bearer '+token
    req = Request(url+path, data=json.dumps(body).encode() if body is not None else None,
                  headers=headers, method=method)
    try:
        response = urlopen(req, timeout=30)
    except HTTPError as error:
        response = error
    raw = response.read()
    return response.status, json.loads(raw) if raw else None, response.headers

if __name__ == '__main__':
    assert config['enabled'] and url.startswith('https://')
    catalog = (ROOT/'data/catalog.json').read_text(encoding='utf8').encode('utf8')
    campaign = (ROOT/'data/campaign.json').read_text(encoding='utf8').encode('utf8')
    import hashlib
    rules = hashlib.sha256(catalog+b'\n'+campaign).hexdigest()
    status, scores, headers = request('/rest/v1/rpc/leaderboard_top', {'p_rules_hash':rules,'p_limit':20})
    assert status == 200 and isinstance(scores,list), f'List failed: {status}'
    assert headers.get('Access-Control-Allow-Origin') in ('*',origin)
    status, _, headers = request('/functions/v1/submit-run',method='OPTIONS')
    assert status == 204 and headers.get('Access-Control-Allow-Origin') == origin
    status, _, _ = request('/functions/v1/submit-run',{})
    assert status == 401, f'Unauthenticated write unexpectedly returned {status}'
    status, _, _ = request('/rest/v1/leaderboard_runs?select=report',method='GET')
    assert status in (401,403), f'Raw reports accessible: {status}'
    print('LIVE_READ_AND_ACCESS_CHECK_OK')
    if report is not None:
        # A natural debug audit is used only as API fixture; flag changed explicitly
        # to exercise the release-only endpoint. The disposable score is removed.
        report['debug_build'] = False
        status, auth, _ = request('/auth/v1/signup',{'data':{}})
        assert status == 200 and 'access_token' in auth, f'Anonymous sign-in failed: {status}'
        identity = {'user_id':auth['user']['id'],'run_id':report['run_id']}
        (ROOT/'output/leaderboard-live-fixture/identity.json').write_text(json.dumps(identity),encoding='utf8')
        payload = {'nickname':'API Test - disposable','report':report}
        for _ in range(2):
            status, result, _ = request('/functions/v1/submit-run',payload,auth['access_token'])
            assert status == 200 and result.get('verification') == 'unverified', f'Submit failed: {status}'
        status, scores, _ = request('/rest/v1/rpc/leaderboard_top',{'p_rules_hash':rules,'p_limit':100})
        assert status == 200 and sum(s['display_name']=='API Test - disposable' for s in scores)==1
        assert all(set(s)=={'display_name','completed_waves','lives','verified','created_at'} for s in scores)
        print('LIVE_ANONYMOUS_SUBMIT_RETRY_CHECK_OK (disposable test identity recorded for cleanup)')
