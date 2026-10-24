"""Package a Godot web export for host-independent public playtesting.

Never writes game data or changes the local review profile. Only public staging
defaults to campaign. Run after export: python tools/prepare_web_beta.py
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FILES = ('index.html', 'index.js', 'index.wasm', 'index.pck', 'index.png',
         'index.audio.worklet.js', 'index.audio.position.worklet.js')
CAMPAIGN = """<script>
// Public beta defaults to campaign; explicit profile links remain available.
const betaURL = new URL(window.location.href);
if (!betaURL.searchParams.has('profile')) {
  betaURL.searchParams.set('profile', 'campaign');
  window.history.replaceState(null, '', betaURL);
}
</script>"""


def prepare(source, destination, commit):
    source, destination = source.resolve(), destination.resolve()
    if source == destination:
        raise ValueError('Source and public staging must be separate folders')
    if destination.exists():
        unexpected = [p.name for p in destination.iterdir() if p.name not in {*FILES, 'build.json', '.nojekyll'}]
        if unexpected:
            raise ValueError('Public staging contains unexpected files: '+', '.join(unexpected))
    missing = [name for name in FILES if not (source/name).is_file()]
    if missing:
        raise ValueError('Incomplete Godot export: '+', '.join(missing))
    version_source = (ROOT/'game/core/release.gd').read_text(encoding='utf8')
    version = re.search(r'if GemCatalog.campaign\(\): return "([^"]+)"', version_source)[1]
    campaign = json.loads((ROOT/'data/campaign.json').read_text(encoding='utf8'))
    html = (source/'index.html').read_text(encoding='utf8')
    if html.count('<head>') != 1:
        raise ValueError('Unexpected Godot HTML shell: expected one head')
    html = html.replace('<head>', '<head>\n'+CAMPAIGN, 1)
    html = re.sub(r'<title>.*?</title>', '<title>GemTD Solo · Web beta</title>', html)
    destination.mkdir(parents=True, exist_ok=True)
    # Copy an explicit allowlist; never deploy source, user saves or test output.
    for name in FILES:
        if name != 'index.html': shutil.copy2(source/name, destination/name)
    (destination/'index.html').write_text(html, encoding='utf8', newline='\n')
    (destination/'.nojekyll').touch()
    content = (ROOT/'data/catalog.json').read_bytes()+b'\n'+(ROOT/'data/campaign.json').read_bytes()
    manifest = {'game_version': version, 'content_version': campaign['version'],
                'commit': commit, 'profile': 'campaign',
                'content_sha256': hashlib.sha256(content).hexdigest(),
                'files': {name: {'bytes': (destination/name).stat().st_size,
                                  'sha256': hashlib.sha256((destination/name).read_bytes()).hexdigest()}
                          for name in FILES}}
    (destination/'build.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT/'builds/web')
    parser.add_argument('--destination', type=Path, default=ROOT/'builds/pages')
    parser.add_argument('--commit', default=None)
    args = parser.parse_args()
    commit = args.commit or subprocess.check_output(['git','rev-parse','HEAD'], cwd=ROOT, text=True).strip()
    result = prepare(args.source, args.destination, commit)
    print('WEB_BETA_READY', json.dumps({k: v for k, v in result.items() if k != 'files'}))
