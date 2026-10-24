"""Package a separate local campaign review without overwriting version 1.0."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from godot import ROOT, local_environment
from verify_campaign import verify


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package():
    version=re.search(r'if GemCatalog.campaign\(\): return "([^"]+)"',
                      (ROOT/'game/core/release.gd').read_text()).group(1)
    destination=ROOT/'builds/release'/('campaign-'+version)
    if destination.exists():
        raise SystemExit('Campaign review already preserved; choose a new version for another package.')
    result=verify()
    if result['failures']:
        raise SystemExit('Campaign source verification failed.')
    replays=json.loads((ROOT/'docs/reports/campaign-replays.json').read_text())
    if not replays['all_passed'] or len(replays['reports']) != 5:
        raise SystemExit('Independently replay all five natural campaign reports first.')
    for row in replays['reports']:
        report=ROOT/'output/campaign-playtest'/row['report']
        if sha(report) != row['sha256'] or json.loads(report.read_text())['game_version'] != version:
            raise SystemExit('A verified campaign report changed.')
    executable=ROOT/'builds/windows/GemTD.exe'
    process=subprocess.run([str(executable),'--headless','--quit-after','5','--','--campaign','--smoke'],
                           cwd=ROOT,env=local_environment(),capture_output=True,text=True,
                           encoding='utf8',errors='replace',timeout=30)
    log=process.stdout+process.stderr
    if process.returncode or 'build=release' not in log or 'ERROR:' in log or 'WARNING:' in log:
        raise SystemExit('Campaign release export did not pass its startup check.\n'+log)
    distribution=json.loads((ROOT/'output/prd-distribution.json').read_text())
    if distribution['game_version'] != version: raise SystemExit('PRD distribution report has the wrong version.')
    extended=json.loads((ROOT/'docs/reports/investigation-extended-replays.json').read_text())
    if not extended['all_passed'] or len(extended['reports']) != 12: raise SystemExit('Verify twelve extended natural reports first.')
    for row in extended['reports']:
        report=ROOT/'output/campaign-extended'/row['report']
        if sha(report) != row['sha256'] or json.loads(report.read_text())['game_version'] != version: raise SystemExit('Extended report changed.')
    late=json.loads((ROOT/'output/late-game-audit.json').read_text())
    if late['game_version'] != version or len(late['cases']) != 7 or len(late['all_trial_openings']) != 50: raise SystemExit('Complete the current late-game fixture audit first.')
    destination.mkdir(parents=True)
    def copy(source,target):
        target=destination/target
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/source,target)
    for name in ['GemTD.exe','GemTD.pck']: copy('builds/windows/'+name,'Windows/'+name)
    (destination/'Windows/Start-Campaign.cmd').write_text('@echo off\ncd /d "%~dp0"\nstart "" "GemTD.exe" -- --campaign\n',encoding='ascii')
    for path in (ROOT/'builds/web').iterdir():
        if path.name.startswith('index.') and path.suffix in ['.html','.js','.wasm','.pck','.png']:
            copy(path.relative_to(ROOT),'Web/'+path.name)
    for name in ['index.html','index.js','index.wasm','index.pck']:
        if not (destination/'Web'/name).exists(): raise SystemExit('Missing web export '+name)
    server='''from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import webbrowser

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control','no-store')
        super().end_headers()

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--port',type=int,default=8070)
    parser.add_argument('--open',action='store_true')
    args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),partial(Handler,directory=str(Path(__file__).resolve().parent)))
    url=f'http://127.0.0.1:{args.port}/?profile=campaign'
    print('GemTD campaign: '+url,flush=True)
    if args.open: webbrowser.open(url)
    try: server.serve_forever()
    except KeyboardInterrupt: server.server_close()
'''
    (destination/'Web/serve.py').write_text(server,encoding='utf8')
    (destination/'Web/Start-Web.cmd').write_text('@echo off\ncd /d "%~dp0"\npython serve.py --open\npause\n',encoding='ascii')
    for name in ['campaign-review.md','graphics-review-campaign.md','balance-research-campaign.md','progression-options.md','investigation-five-steps.md','teststatus.md']:
        copy('docs/'+name,'Review/'+name)
    for name in ['campaign-reference.json','campaign-replays.json','progression-options.json','boss-diagnostics-baseline.json','investigation-extended-replays.json']:
        copy('docs/reports/'+name,'Review/reports/'+name)
    for path in (ROOT/'output/campaign-playtest').glob('*.json'):
        copy(path.relative_to(ROOT),'Review/playtests/'+path.name)
    copy('output/prd-distribution.json','Review/reports/prd-distribution.json')
    copy('output/late-game-audit.json','Review/reports/late-game-audit.json')
    for path in (ROOT/'output/campaign-extended').glob('*.json'): copy(path.relative_to(ROOT),'Review/extended-playtests/'+path.name)
    copy('assets/graphics/readability.json','Review/readability.json')
    copy('data/campaign.json','Review/campaign-data.json')
    (destination/'README.md').write_text(f'''# GemTD Solo campaign {version}

Packa upp hela arkivet. Windows: starta Windows/Start-Campaign.cmd. Webb: starta Web/Start-Web.cmd (Python krävs för den lokala webbservern). Webbprofilen är http://127.0.0.1:8070/?profile=campaign.

100 vågor, sex kvaliteter, 59 receptalternativ och 24 stentavlor. Läs Review/campaign-review.md för spelregler, teststatus och skillnader mot Dota. Detta är en lokal granskningsversion; mänsklig slutbalansering och full Dota-motorparitet återstår.

Behåll GemTD.pck bredvid GemTD.exe. Run-menyn kan byta mellan kampanj, den äldre 1.0-profilen och gemutvecklingsprofilen. Sparfiler är separata. Ingen publik uppladdning eller automatisk rapportöverföring sker.
''',encoding='utf8')
    files={str(p.relative_to(destination)).replace('\\','/'):dict(bytes=p.stat().st_size,sha256=sha(p))
           for p in sorted(destination.rglob('*')) if p.is_file()}
    (destination/'MANIFEST.json').write_text(json.dumps(dict(version=version,profile='full-solo-dev',files=files),indent=2)+'\n')
    archive=destination.parent/('GemTD-campaign-'+version+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
        for path in sorted(destination.rglob('*')):
            if path.is_file(): output.write(path,str(path.relative_to(destination)))
    with zipfile.ZipFile(archive) as output:
        if output.testzip() is not None: raise SystemExit('Archive CRC failed.')
    sums=archive.parent/'CAMPAIGN-SHA256SUMS.txt'
    previous=sums.read_text().splitlines() if sums.exists() else []
    previous=[line for line in previous if not line.endswith('  '+archive.name)]
    sums.write_text('\n'.join(previous+[sha(archive)+'  '+archive.name])+'\n')
    print(f'CAMPAIGN_PACKAGED {archive} ({archive.stat().st_size} bytes)')


if __name__=='__main__': package()
