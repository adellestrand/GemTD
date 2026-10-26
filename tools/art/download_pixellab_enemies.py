"""Download original PNG frames for already submitted PixelLab MCP jobs.

Uses the user's existing PIXELLAB_API_KEY; never saves or prints credentials.
Generation and status tracking use the connected PixelLab tools.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import io
import json
import os
from pathlib import Path
import re
import urllib.request

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'output/pixellab-enemies-v1'


def main():
    global WORK
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work',type=Path,default=WORK)
    parser.add_argument('enemies',nargs='+')
    args=parser.parse_args()
    WORK=args.work.resolve()
    token=os.environ.get('PIXELLAB_API_KEY')
    if not token:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,'Environment') as key:
            token=winreg.QueryValueEx(key,'PIXELLAB_API_KEY')[0]
    jobs=json.loads((WORK/'jobs.json').read_text())
    jobs.update({p.stem:json.loads(p.read_text()) for p in (WORK/'jobs').glob('*.json')})
    tasks=[]
    for enemy in args.enemies:
        job=re.search(r'job_id: ([^\n]+)',jobs[enemy]['content'][0]['text']).group(1)
        directory=WORK/enemy
        directory.mkdir(parents=True,exist_ok=True)
        tasks.extend((enemy,job,i,directory/f'{i:02d}.png') for i in range(9))
    def download(task):
        enemy,job,index,path=task
        if path.exists(): return
        url=f'https://api.pixellab.ai/mcp/images/{job}/download?index={index}'
        request=urllib.request.Request(url,headers={'Authorization':'Bearer '+token})
        with urllib.request.urlopen(request,timeout=60) as response: data=response.read()
        im=Image.open(io.BytesIO(data))
        if im.format!='PNG': raise ValueError(f'{enemy}/{index}: expected PNG')
        im.verify()
        path.write_bytes(data)
    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(download,tasks))
    print('Downloaded: '+', '.join(args.enemies))


if __name__=='__main__': main()
