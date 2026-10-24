"""Replay preserved natural playtest reports and retain independent verification results."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from godot import ROOT, ENGINE, local_environment

if __name__ == '__main__':
    rows = []
    campaign = '--campaign' in sys.argv
    folder = ROOT/('output/campaign-playtest' if campaign else 'output/v1-playtest')
    for report in sorted(folder.glob('*-*.json')):
        process = subprocess.run([str(ENGINE),'--headless','--path','.',
                                  '--script','res://tools/replay_review.gd','--',
                                  '--report='+str(report),*(['--campaign'] if campaign else [])],cwd=ROOT,env=local_environment(),
                                 stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                                 encoding='utf8',errors='replace',timeout=90)
        line = next((line for line in process.stdout.splitlines() if line.startswith('REVIEW_REPLAY ')), '')
        result = json.loads(line.removeprefix('REVIEW_REPLAY ')) if line else dict(ok=False,error=process.stdout[-1000:])
        if process.returncode or 'ERROR:' in process.stdout or 'WARNING:' in process.stdout:
            result['ok'] = False
        rows.append(dict(report=report.name,sha256=hashlib.sha256(report.read_bytes()).hexdigest(),**result))
        print(report.name, result, flush=True)
    if not rows:
        raise SystemExit('No playtest reports found.')
    destination = ROOT/('docs/reports/campaign-replays.json' if campaign else 'docs/reports/replay-verification-v1.json')
    destination.write_text(json.dumps(dict(reports=rows,all_passed=all(row['ok'] for row in rows)),indent=2)+'\n',encoding='utf8')
    raise SystemExit(not all(row['ok'] for row in rows))
