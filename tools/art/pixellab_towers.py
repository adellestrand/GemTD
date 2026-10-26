"""Prepare/pack stationary PixelLab crystal idle loops. No generation calls.

python tools/art/pixellab_towers.py prepare | build [--activate]
"""
import argparse
import colorsys
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'output/pixellab-towers-v1'
DEST=ROOT/'assets/graphics/pixellab-towers-v1'


def core_override(id,reference):
    regions={
        'special_v1_heiyaoshi':[(.30,.25,.72,.41),(.38,.62,.67,.82)],
        'special_v1_huguoshenyishi':[(.34,.29,.68,.46)],
    }
    if id not in regions: return None
    left,top,right,bottom=reference.getbbox();w,h=right-left,bottom-top
    mask=Image.new('L',reference.size)
    for x0,y0,x1,y1 in regions[id]:
        for y in range(top+round(y0*h),top+round(y1*h)):
            for x in range(left+round(x0*w),left+round(x1*w)):
                r,g,b,a=reference.getpixel((x,y))
                hue,sat,value=colorsys.rgb_to_hsv(r/255,g/255,b/255)
                if a and sat>.4 and value>.3 and hue<.2: mask.putpixel((x,y),255)
    return mask


def prepare():
    if (WORK/'plan.json').exists(): raise SystemExit('Existing tower plan retained; resume it.')
    WORK.mkdir(parents=True,exist_ok=True)
    m=json.loads((ROOT/'assets/graphics/manifest.json').read_text())
    catalog=json.loads((ROOT/'data/campaign.json').read_text())
    ids=set()
    for kind,binding in m['bindings']['gems'].items():
        if kind=='stone' or catalog['specials'].get(kind,{}).get('slab',False): continue
        ids.update(binding.values() if isinstance(binding,dict) else [binding])
    plan=[]
    # Yellow cores need geometry to distinguish them from gold fittings.
    yellow={'topaz','special_v1_jin','special_v1_manao','special_v1_huangcailanbaoshi',
            'special_v1_you235','special_v1_xiameishi','special_v1_heisemaoyanshi',
            'special_v1_furongshi'}
    for n,id in enumerate(sorted(ids)):
        if id=='sapphire': continue
        entry=m['sprites'][id]
        source=Image.open(ROOT/entry['texture'].removeprefix('res://')).convert('RGBA')
        w,h=source.size
        width,height=math.ceil((w+16)/8)*8,math.ceil((h+16)/8)*8
        dx,dy=(width-w)//2,(height-h)//2
        reference=Image.new('RGBA',(width,height));reference.paste(source,(dx,dy))
        mask=Image.new('L',(width,height))
        yellow_core=id.split('_2_')[0].split('_3_')[0] in yellow or id in yellow
        for y in range(h):
            for x in range(w):
                r,g,b,a=source.getpixel((x,y))
                hue,sat,value=colorsys.rgb_to_hsv(r/255,g/255,b/255)
                # Coloured upper cores and side crystals; exclude gold and masonry.
                chromatic=(sat>.27 and value>.24 and not .07<hue<.19)
                white_core=(sat<.25 and value>.62 and .3*w<x<.7*w and y<h*.22)
                gold_core=(yellow_core and .32*w<x<.68*w and y<h*.23 and value>.35 and sat>.25)
                if a and ((y<h*.46 and chromatic) or white_core or gold_core): mask.putpixel((x+dx,y+dy),255)
        override=core_override(id,reference)
        if override is not None: mask=override
        if not mask.getbbox(): raise ValueError(f'{id}: no crystal mask')
        reference.save(WORK/f'{id}_reference.png');mask.save(WORK/f'{id}_mask.png')
        action=('A seamless calm eight-frame idle lighting loop. Only the existing crystals and magical energy cores gently brighten, with a tiny moving facet highlight, then dim back to their starting brightness. '
                'Keep the original crystal colours. Keep all stonework, foundations, walls, roof, gold fittings, silhouette and all crystal shapes completely still. '
                'Lighting only: no movement, no rotation, no zoom, no deformation, no growth, no particles, no expanding rings, no rays outside the tower. '
                'Preserve the exact pixel-art appearance and transparent background. Return to the original brightness at the end.')
        plan.append(dict(id=id,reference=str(WORK/f'{id}_reference.png'),size=[width,height],
                         previous=entry.copy(),seed=26103000+n,frames=8,action=action,
                         mask_pixels=mask.histogram()[255],estimated_generations=math.ceil(width*height*8/65536)))
    (WORK/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    (WORK/'jobs.json').write_text('{}\n')
    overview=Image.new('RGB',(1120,math.ceil(len(plan)/8)*110),'#283329');draw=ImageDraw.Draw(overview)
    for n,e in enumerate(plan):
        ref=Image.open(e['reference']).convert('RGBA');mask=Image.open(WORK/f'{e["id"]}_mask.png')
        highlight=ref.copy();highlight.paste((255,80,170,255),mask=mask)
        x,y=(n%8)*140,(n//8)*110
        overview.paste(highlight,(x+(140-ref.width)//2,y),highlight)
        draw.text((x+2,y+92),e['id'].replace('special_v1_','')[:22],fill='white')
    overview.save(WORK/'masks.png')
    print(f'{len(plan)} loops; estimated {sum(e["estimated_generations"] for e in plan)} generations')


def build(activate=False):
    plan=json.loads((WORK/'plan.json').read_text())
    mpath=ROOT/'assets/graphics/manifest.json';m=json.loads(mpath.read_text())
    DEST.mkdir(parents=True,exist_ok=True)
    missing=[];report=[];animations=[]
    for e in plan:
        id=e['id'];directory=WORK/id;paths=[directory/f'{i:02d}.png' for i in range(9)]
        if not all(p.exists() for p in paths): missing.append(id);continue
        ref=Image.open(e['reference']).convert('RGBA');mask=Image.open(WORK/f'{id}_mask.png').convert('L')
        raw=[Image.open(p).convert('RGBA') for p in paths]
        if any(im.size!=ref.size for im in raw): raise ValueError(f'{id}: frame size changed')
        if raw[0].tobytes()!=ref.tobytes(): raise ValueError(f'{id}: input frame changed')
        pixels=[(x,y) for y in range(ref.height) for x in range(ref.width) if mask.getpixel((x,y))]
        frames=[];changes=[]
        for index,generated in enumerate(raw[:8]):
            frame=ref.copy();changed=0
            for xy in pixels:
                r,g,b,a=ref.getpixel(xy);gr,gg,gb,ga=generated.getpixel(xy)
                if not ga: continue
                # Transfer bounded provider light intensity; retain exact source
                # hue, geometry and alpha. This prevents displaced AI facets
                # from drawing gold/stone into a crystal at the mask boundary.
                light=.2126*r+.7152*g+.0722*b
                glow=.2126*gr+.7152*gg+.0722*gb
                factor=max(.82,min(1.25,(glow+1)/(light+1)))
                colour=tuple(min(255,round(v*factor)) for v in (r,g,b))+(a,)
                frame.putpixel(xy,colour)
                changed+=colour!=(r,g,b,a)
            if frame.getchannel('A').tobytes()!=ref.getchannel('A').tobytes(): raise ValueError(id+' alpha changed')
            changes.append(changed);frames.append(frame)
        unique=len({f.tobytes() for f in frames})
        if unique<4 or max(changes)<4: raise ValueError(f'{id}: insufficient lighting animation')
        w,h=ref.size;strip=Image.new('RGBA',(w*8,h))
        for i,frame in enumerate(frames): strip.paste(frame,(i*w,0))
        path=DEST/f'{id}_idle_v1.png';strip.save(path)
        ref.save(DEST/f'{id}_reference.png');mask.save(DEST/f'{id}_mask.png')
        receipt=json.loads((WORK/'jobs'/f'{id}.json').read_text())
        metadata={**{k:v for k,v in e.items() if k!='reference'},'provider':'PixelLab','tool':'animate_image',
                  'date':'2026-10-26','receipt':receipt['content'][0]['text'],
                  'reference':f'assets/graphics/pixellab-towers-v1/{id}_reference.png',
                  'mask':f'assets/graphics/pixellab-towers-v1/{id}_mask.png',
                  'selected_provider_indices':list(range(8)),
                  'postprocessing':'Bounded provider luminance inside saved crystal mask only; source hue, alpha and every unmasked pixel remain exact.',
                  'validation':dict(unique_frames=unique,changed_pixels=changes,static_structure_identical=True,alpha_identical=True),
                  'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        (DEST/f'{id}.generation.json').write_text(json.dumps(metadata,indent=2)+'\n')
        report.append(dict(id=id,unique_frames=unique,changed_pixels=changes,mask_pixels=len(pixels)))
        animations.append((id,frames))
        if activate:
            entry=m['sprites'][id];entry['texture']='res://'+path.relative_to(ROOT).as_posix()
            entry['frames']=8;entry['idle_fps']=5.25
    for page,start in enumerate(range(0,len(animations),10)):
        group=animations[start:start+10]
        sheet=Image.new('RGB',(820,len(group)*100),'#304932');draw=ImageDraw.Draw(sheet)
        for row,(id,frames) in enumerate(group):
            draw.text((2,row*100),id.replace('special_v1_','')[:27],fill='white')
            for col,f in enumerate(frames): sheet.paste(f,(160+col*80,row*100+14),f)
        sheet.save(WORK/f'review-{page+1}.png')
    (WORK/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    (WORK/'status.json').write_text(json.dumps(dict(built=[r['id'] for r in report],remaining=missing,activated=activate),indent=2)+'\n')
    if activate:
        if missing: raise ValueError(f'Missing tower loops: {missing}')
        mpath.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(dict(built=len(report),remaining=len(missing),activated=activate)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['prepare','build']);parser.add_argument('--activate',action='store_true')
    args=parser.parse_args()
    if args.command=='prepare': prepare()
    else: build(args.activate)
