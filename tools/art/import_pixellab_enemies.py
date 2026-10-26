"""Validate and pack the PixelLab enemy pass. --activate updates the manifest.

Provider frames/receipts remain in output; reproducible provenance, references
and final strips are versioned. No resizing or per-frame auto-centering.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'output/pixellab-enemies-v1'
DEST = ROOT / 'assets/graphics/pixellab-enemies-v1'


def build(activate=False):
    plan = json.loads((WORK/'plan.json').read_text())
    jobs = json.loads((WORK/'jobs.json').read_text())
    jobs.update({p.stem:json.loads(p.read_text()) for p in (WORK/'jobs').glob('*.json')})
    manifest_path = ROOT/'assets/graphics/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    DEST.mkdir(parents=True, exist_ok=True)
    report, animations = [], []
    missing = []
    for e in plan:
        enemy = e['id']
        directory = WORK/enemy
        paths = [directory/f'{i:02d}.png' for i in range(9)]
        if not all(p.exists() for p in paths):
            missing.append(enemy)
            continue
        originals = [Image.open(p).convert('RGBA') for p in paths]
        if any(im.size != tuple(e['size']) for im in originals):
            raise ValueError(f'{enemy}: unexpected frame dimensions')
        reference = Image.open(e['reference']).convert('RGBA')
        if originals[0].tobytes() != reference.tobytes():
            raise ValueError(f'{enemy}: provider changed the input frame')
        frames = [im.copy() for im in originals[:8]]  # terminal pose is the loop closure
        # PixelLab makes generated silhouettes opaque even for a translucent
        # reference (the invisible spider). Keep its authored opacity constant
        # across the loop, instead of flashing opaque after frame zero.
        opacity=reference.getchannel('A').getextrema()[1]
        if opacity<255:
            for im in frames[1:]:
                im.putalpha(im.getchannel('A').point(lambda a: round(a*opacity/255)))
        boxes = [im.getbbox() for im in frames]
        if any(box is None for box in boxes):
            raise ValueError(f'{enemy}: empty frame')
        if len({im.tobytes() for im in frames}) < 6:
            raise ValueError(f'{enemy}: too few distinct frames')
        w,h = reference.size
        touches_edge = any(b[0]==0 or b[1]==0 or b[2]==w or b[3]==h for b in boxes)
        if activate and touches_edge:
            raise ValueError(f'{enemy}: review possible clipping before activation')
        strip = Image.new('RGBA',(w*8,h))
        for i,im in enumerate(frames): strip.paste(im,(i*w,0))
        filename = DEST/f'{enemy}_move_v1.png'
        strip.save(filename)
        reference.save(DEST/f'{enemy}_reference.png')
        receipt = jobs[enemy]['content'][0]['text']
        metadata = {**{k:v for k,v in e.items() if k!='reference'},
                    'provider':'PixelLab', 'tool':'animate_image',
                    'date':'2026-10-26',
                    'reference':f'assets/graphics/pixellab-enemies-v1/{enemy}_reference.png',
                    'receipt':receipt, 'provider_frame_count':9,
                    'selected_provider_indices':list(range(8)),
                    'last_frame':'same_as_first', 'no_background':True,
                    'restored_reference_opacity':opacity if opacity<255 else None,
                    'sha256':hashlib.sha256(filename.read_bytes()).hexdigest()}
        (DEST/f'{enemy}.generation.json').write_text(json.dumps(metadata,indent=2)+'\n')
        # All frames remain at fixed positions on the same canvas.
        contact = Image.new('RGB',(w*8*2,h*2+22),'#304932')
        for i,im in enumerate(frames):
            large=im.resize((w*2,h*2),Image.Resampling.NEAREST)
            contact.paste(large,(i*w*2,22),large)
        ImageDraw.Draw(contact).text((4,4),enemy,fill='white')
        contact.save(directory/'contact.png')
        animations.append((enemy,frames))
        report.append(dict(id=enemy,size=[w,h],frames=8,touches_edge=touches_edge,
                           boxes=boxes,unique_frames=len({im.tobytes() for im in frames})))
        if activate:
            entry=manifest['sprites'][enemy]
            entry['texture']='res://'+filename.relative_to(ROOT).as_posix()
            entry['frames']=8
            entry.setdefault('motion',{}).update(bounce=0.0,squash=0.0,sway=0.0)
    (WORK/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    # Animated overview in pages, viewable independently of the game.
    for page,start in enumerate(range(0,len(animations),16)):
        group=animations[start:start+16]
        overview=[]
        for f in range(8):
            image=Image.new('RGB',(800,640),'#283329')
            draw=ImageDraw.Draw(image)
            for n,(enemy,frames) in enumerate(group):
                im=frames[f]
                x,y=(n%4)*200,(n//4)*160
                im=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
                image.paste(im,(x+(200-im.width)//2,y+4),im)
                draw.text((x+8,y+144),enemy,fill='white')
            overview.append(image)
        overview[0].save(WORK/f'overview-{page+1}.gif',save_all=True,
                         append_images=overview[1:],duration=110,loop=0,disposal=2)
        overview[0].save(WORK/f'overview-{page+1}.png')
    for page,start in enumerate(range(0,len(animations),8)):
        group=animations[start:start+8]
        review=Image.new('RGB',(900,len(group)*110),'#304932')
        draw=ImageDraw.Draw(review)
        for row,(enemy,frames) in enumerate(group):
            draw.text((4,row*110+6),enemy,fill='white')
            for col,frame in enumerate(frames):
                review.paste(frame,(120+col*96+(96-frame.width)//2,row*110+20),frame)
        review.save(WORK/f'review-{page+1}.png')
    if activate:
        if missing: raise ValueError(f'Missing animations: {missing}')
        manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'built':len(report),'missing':missing,
                      'edge_warnings':[r['id'] for r in report if r['touches_edge']],
                      'activated':activate}))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--activate',action='store_true')
    build(parser.parse_args().activate)
