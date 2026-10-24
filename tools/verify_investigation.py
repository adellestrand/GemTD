"""Independently replay the extended natural campaign investigation."""
import hashlib
import json
import subprocess
from godot import ROOT, ENGINE, local_environment


if __name__ == '__main__':
    rows=[]
    reports=sorted((ROOT/'output/campaign-extended').glob('maze-*.json'))
    if len(reports) != 12: raise SystemExit('Expected twelve natural campaign reports.')
    for path in reports:
        result=subprocess.run([str(ENGINE),'--headless','--path','.',
                               '--script','res://tools/replay_review.gd','--','--campaign','--report='+str(path)],
                              cwd=ROOT,env=local_environment(),capture_output=True,text=True,
                              encoding='utf8',errors='replace',timeout=90)
        line=next((line for line in result.stdout.splitlines() if line.startswith('REVIEW_REPLAY ')),None)
        verdict=json.loads(line.removeprefix('REVIEW_REPLAY ')) if line else dict(ok=False,error=result.stdout[-500:])
        if result.returncode or 'ERROR:' in result.stdout or 'WARNING:' in result.stdout or not verdict['ok']:
            raise SystemExit(f'{path.name}: {verdict}')
        rows.append(dict(report=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),**verdict))
        print('EXTENDED_REPLAY_OK '+path.name,flush=True)
    (ROOT/'docs/reports/investigation-extended-replays.json').write_text(json.dumps(dict(all_passed=True,reports=rows),indent=2)+'\n',encoding='utf8')
    print('EXTENDED_REPLAYS_OK '+str(len(rows)))
