"""Fail publication when the exported release is not accepted by the leaderboard.

Only a public read-only endpoint and publishable key are used. No player is created.
Run after prepare_web_beta.py, before uploading the Pages artifact.
"""
import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[1]


def check_release(manifest, config, opener=urlopen):
    if not config.get('enabled', False):
        return 'LEADERBOARD_RELEASE_CHECK_SKIPPED disabled in client configuration'
    identity = {key: manifest[key] for key in ('content_sha256','game_version','content_version')}
    if (not re.fullmatch('[a-f0-9]{64}',identity['content_sha256']) or
            not isinstance(identity['content_version'],int) or not identity['game_version']):
        raise ValueError('Invalid build release identity')
    project = config['project_url'].rstrip('/')
    if not project.startswith('https://'):
        raise ValueError('Leaderboard project must use HTTPS')
    query = urlencode({'action':'release-check','rules_hash':identity['content_sha256'],
                       'game_version':identity['game_version'],'content_version':identity['content_version']})
    request = Request(project+'/functions/v1/submit-run?'+query,
                      headers={'apikey':config['publishable_key'],'Origin':'https://adellestrand.github.io'})
    try:
        with opener(request,timeout=20) as response:
            result = json.load(response)
    except HTTPError as error:
        error.close()
        if error.code == 409:
            raise ValueError('Leaderboard has not approved this exact release. Apply its reviewed supabase/releases SQL before publishing.') from None
        raise ValueError(f'Leaderboard release check failed (HTTP {error.code}); publication stopped.') from None
    except (URLError, OSError):
        raise ValueError('Cannot verify leaderboard readiness; publication stopped. Try again when the service is available.') from None
    if not isinstance(result,dict) or result.get('accepting') is not True:
        raise ValueError('Leaderboard is not accepting this release; publication stopped.')
    return 'LEADERBOARD_RELEASE_CHECK_OK '+identity['content_sha256']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest',type=Path,default=ROOT/'builds/pages/build.json')
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text(encoding='utf8'))
        config = json.loads((ROOT/'assets/online/leaderboard.json').read_text(encoding='utf8'))
        print(check_release(manifest,config))
    except (ValueError,KeyError,OSError) as error:
        raise SystemExit(str(error)) from None
