"""Package verified local review builds. No upload, deletion or Git operations."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from godot import ROOT, local_environment
from verify_balance import verify


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == '__main__':
    release = json.loads((ROOT/'data/release.json').read_text(encoding='utf8'))
    version = release['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('Invalid release version.')
    if verify()['failures']:
        raise SystemExit('Balance verification failed.')
    replay_results = json.loads((ROOT/'docs/reports/replay-verification-v1.json').read_text())
    if not replay_results['all_passed'] or len(replay_results['reports']) != 20:
        raise SystemExit('Verify all twenty natural reports first.')
    for row in replay_results['reports']:
        if digest(ROOT/'output/v1-playtest'/row['report']) != row['sha256']:
            raise SystemExit('A verified playtest report changed: '+row['report'])
    executable = ROOT/'builds/windows/GemTD.exe'
    process = subprocess.run([str(executable),'--headless','--quit-after','3','--','--smoke'],
                             cwd=ROOT,env=local_environment(),stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT,encoding='utf8',errors='replace',timeout=30)
    if process.returncode or 'build=release' not in process.stdout or 'ERROR:' in process.stdout or 'WARNING:' in process.stdout:
        raise SystemExit('Build and verify a Windows release export first.\n'+process.stdout)
    destination = ROOT/'builds/release'/version
    if destination.exists():
        raise SystemExit('This release is already preserved. Use a new release version instead of overwriting it.')
    destination.mkdir(parents=True, exist_ok=True)

    def copy(source, relative):
        target = destination/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT/source,target)

    for name in ('GemTD.exe','GemTD.pck'):
        copy('builds/windows/'+name,'Windows/'+name)
    for path in (ROOT/'builds/web').iterdir():
        if path.name.startswith('index.') and path.suffix in ('.html','.js','.wasm','.pck','.png'):
            copy(path.relative_to(ROOT),'Web/'+path.name)
    for required in ('index.html','index.js','index.wasm','index.pck'):
        if not (destination/'Web'/required).exists():
            raise SystemExit('Missing web export '+required)
    for name in ('balance-v1.md','testguide-v1.md','release-notes-v1.md'):
        copy('docs/'+name,'Review/'+name)
    for name in ('balance-reference-v1.json','v1-playtest-results.json','replay-verification-v1.json'):
        copy('docs/reports/'+name,'Review/reports/'+name)
    copy('data/balance_baseline.json','Review/balance_baseline.json')
    for report in (ROOT/'output/v1-playtest').glob('*.json'):
        copy(report.relative_to(ROOT),'Review/playtests/'+report.name)
    server = '''from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import argparse
import webbrowser

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8070)
    parser.add_argument("--open", action="store_true")
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1",args.port),partial(Handler,directory=str(Path(__file__).resolve().parent)))
    url = f"http://127.0.0.1:{args.port}/"
    print(f"GemTD Solo: {url} -- Ctrl+C to stop",flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
'''
    (destination/'Web/serve.py').write_text(server,encoding='utf8')
    (destination/'Web/Start-Web.cmd').write_text('@echo off\ncd /d "%~dp0"\npython serve.py --open\npause\n',encoding='ascii')
    (destination/'README.md').write_text(f'''# GemTD Solo {version}

Packa upp hela leveransen. Starta Windows/GemTD.exe, eller Web/Start-Web.cmd för webbversionen (Python krävs för den lokala webbservern). Webbversionen öppnas på port 8070.

Läs Review/testguide-v1.md för testupplägg och hur du kopierar en speltestrapport. Review/balance-v1.md beskriver Dota-referensen och tiovågsanpassningarna.

Behåll GemTD.pck bredvid exe-filen. Sparning sker vid början av en byggfas. Windows- och webbsparning är separata. Ingen publik server eller Dota-installation behövs.
''',encoding='utf8')
    files = {str(path.relative_to(destination)).replace('\\','/'):dict(bytes=path.stat().st_size,sha256=digest(path))
             for path in sorted(destination.rglob('*')) if path.is_file() and path.name != 'MANIFEST.json'}
    (destination/'MANIFEST.json').write_text(json.dumps(dict(**release,files=files),indent=2)+'\n',encoding='utf8')
    archive = destination.parent/f'GemTD-{version}-local-review.zip'
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
        for path in sorted(destination.rglob('*')):
            if path.is_file():
                output.write(path,str(path.relative_to(destination)))
    with zipfile.ZipFile(archive) as output:
        if output.testzip() is not None:
            raise SystemExit('Archive integrity check failed.')
    (archive.parent/'SHA256SUMS.txt').write_text(f'{digest(archive)}  {archive.name}\n',encoding='ascii')
    print(f'RELEASE_PACKAGED {archive} ({archive.stat().st_size} bytes, {len(files)} content files)')
