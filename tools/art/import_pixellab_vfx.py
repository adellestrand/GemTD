"""Import the PixelLab VFX pass (ability effects v1) into the game.

Each effect was built in PixelLab's vfx_workbench around the 32 px boar and
exported as a game pack: separate sprite sheets for what plays behind and in
front of the enemy, with offsets from the subject's feet. This script downloads
the packs (no auth, the export id is the key), repacks every layer into a
horizontal strip and writes the clip table into assets/graphics/ability-effects.json.

Presentation only: no simulation, balance or save data is read or written.

    python -I tools/art/import_pixellab_vfx.py
"""
import hashlib
import io
import json
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/graphics/pixellab-vfx-v1'
CACHE = ROOT / 'output/pixellab-vfx-v1'
EFFECTS = ROOT / 'assets/graphics/ability-effects.json'
BASE = 'https://api.pixellab.ai/mcp/pixel-tools'
# Reference subject: assets/graphics/pixellab-v1/boar_walk_v1_reference.png at 32 px wide.
SUBJECT = [32, 28]

# clip id -> (export image id, file slug, PixelLab part, My effects id)
CLIPS = {
    'status_burn': ('4880c46b-1f8a-40f8-bddd-56dba432ffe1', 'gemtd-status-burn-v1', 'burn_status', '72d9b931-2715-4a78-aca8-3fcaa2f28f4b'),
    'status_poison': ('88312aff-419e-4851-9d79-2677727a424f', 'gemtd-status-poison-v1', 'poison_bubbles', 'de4d4945-43c6-48ce-889d-930007c014e6'),
    'status_frost': ('395c9877-bca8-4736-b3c2-9b918c3309a9', 'gemtd-status-frost-v2', 'freeze_status', '4c7336ed-6101-4040-80ea-09cff4bf1cda'),
    'status_fracture': ('186e1b8e-e5ce-48af-a598-50ff92287eec', 'gemtd-status-fracture-v1', 'debuff_arrows', '12a8678f-36b3-428a-8441-3413261a579b'),
    'status_stun': ('0ddc4a70-fa5a-45ea-8500-1cc33ad068af', 'gemtd-status-stun-v1', 'stun_stars', '0ae435b3-5c8f-4b5f-8013-a092dcae64d8'),
    'status_shield': ('41c89a21-5a58-443b-a007-dae36b5ae39f', 'gemtd-status-shield-v1', 'bubble_shield', '4eb9d5b5-4c38-4a0c-b063-4c80a69e254c'),
    'status_shock': ('a09e2034-a873-4efd-85af-b1abdc50ba1d', 'gemtd-status-shock-v1', 'lightning_arcs', '8026de2d-be26-4f34-ac8d-4e3fb4ec9c96'),
    'status_support': ('0b0bc7af-54af-4d8b-90c3-4737bb7b6f48', 'gemtd-status-support-v1', 'buff_arrows', '531f57f8-5ecf-45bb-bdb8-d2d454b1dcfe'),
    'hit_lightning': ('e663bf64-059c-4e09-a8ba-112f0af063fd', 'gemtd-hit-lightning-v1', 'bolt_strike', '10020499-78e6-45ca-9bca-5ef8f3eaab48'),
    'hit_critical': ('2292a12e-68fe-4227-a827-d717c10fbf04', 'gemtd-hit-critical-v1', 'hit_star', 'a8734829-6199-42fb-8196-e2acdf82feb2'),
    'hit_blast': ('ac685a1b-6c71-4991-b8f9-3fd13d1df034', 'gemtd-hit-blast-v1', 'cartoon_boom', '0d3a287e-03cd-46c4-ab0a-037c31fb0225'),
    'hit_fire': ('03221975-9a69-46d7-b883-3ba9675378ad', 'gemtd-hit-fire-v1', 'fire_blast', 'f19e4b71-de96-4def-90f3-075e4fce9732'),
    'hit_frost': ('113dd98d-7ba0-4805-a169-ce3af86b7881', 'gemtd-hit-frost-v1', 'ice_shatter', '94080506-79d0-4c7d-8a15-746552cca1ed'),
    'hit_poison': ('2b11ad80-0f49-4a88-910a-f52d673cb7bd', 'gemtd-hit-poison-v1', 'blood_splat', 'b32109cf-66ef-46ed-b190-55bab1b609da'),
    'hit_stone': ('13c373f0-cc08-48b4-be0d-84bf4674a867', 'gemtd-hit-stone-v1', 'petrify', 'b85ee876-2bdf-49a6-ae9a-efc262d95125'),
    'hit_fracture': ('19d36164-97a2-48d5-bc13-845de5f2690a', 'gemtd-hit-fracture-v1', 'shield_break', 'b0e9a735-32d9-49fd-a977-6ebcc38881c8'),
    'hit_stun': ('2e0ca757-98dc-40ea-9ad8-0476134363f8', 'gemtd-hit-stun-v1', 'star_burst', '0311cbe0-22ee-42f0-86b1-6d7fa74198e2'),
    'hit_shield': ('a94829b0-b33c-4973-8cb2-92f5b72de1fd', 'gemtd-hit-shield-v1', 'collect_pop', 'a74ae1ad-12a8-44a5-a050-b394c2e7e8ec'),
    'hit_support': ('098ae513-ef8e-4bc4-8904-6efc9ea5fcd1', 'gemtd-hit-support-v1', 'collect_pop', '6250594e-9776-4d87-ad5b-07a1e520d487'),
}


def pack(clip):
    image_id, slug = CLIPS[clip][:2]
    cached = CACHE / f'{slug}-game.zip'
    if not cached.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(f'{BASE}/{image_id}/{slug}-game.zip', timeout=60) as response:
            cached.write_bytes(response.read())
    return zipfile.ZipFile(io.BytesIO(cached.read_bytes()))


def strip(archive, entry, total):
    """Grid sheet -> horizontal strip of all `total` effect frames, or None when empty.

    A layer only covers its own window (start_frame, frames); the rest stays
    transparent so every layer of an effect shares one frame index.
    """
    frame_w, frame_h = entry['frame']['w'], entry['frame']['h']
    if frame_w < 1 or frame_h < 1:
        return None
    result = Image.new('RGBA', (frame_w*total, frame_h))
    for sheet in entry['sheets']:
        image = Image.open(io.BytesIO(archive.read(sheet['file']))).convert('RGBA')
        for i in range(sheet['frames']):
            column, row = i % sheet['columns'], i // sheet['columns']
            cell = image.crop((column*frame_w, row*frame_h, (column+1)*frame_w, (row+1)*frame_h))
            result.paste(cell, ((entry['start_frame']+sheet['first_frame']+i)*frame_w, 0))
    return result if result.getbbox() else None


def build():
    DEST.mkdir(parents=True, exist_ok=True)
    clips = {}
    for clip, (image_id, slug, part, effect_id) in CLIPS.items():
        archive = pack(clip)
        manifest = json.loads(archive.read('manifest.json'))
        if manifest['anchor']['kind'] != 'feet':
            raise ValueError(f'{clip}: expected a feet anchor')
        entry = {'fps': manifest['fps'], 'frames': manifest['frames'], 'loop': manifest['loop'], 'subject': SUBJECT, 'layers': {}}
        provenance = {'source': 'PixelLab vfx_workbench', 'part': part, 'my_effects_id': effect_id, 'export_image_id': image_id, 'pack': manifest, 'files': {}}
        for depth in ['behind', 'front']:
            layer = next((c for c in manifest['clips'] if c['name'] == depth), None)
            image = strip(archive, layer, manifest['frames']) if layer else None
            if image is None:
                continue
            filename = DEST / f'{clip}_{depth}_v1.png'
            image.save(filename)
            entry['layers'][depth] = {
                'texture': 'res://' + filename.relative_to(ROOT).as_posix(),
                'size': [layer['frame']['w'], layer['frame']['h']],
                'offset': [layer['offset']['x'], layer['offset']['y']],
            }
            provenance['files'][filename.name] = hashlib.sha256(filename.read_bytes()).hexdigest()
        if not entry['layers']:
            raise ValueError(f'{clip}: no visible layer')
        (DEST / f'{clip}.generation.json').write_text(json.dumps(provenance, indent=2) + '\n', newline='\n')
        clips[clip] = entry
    effects = json.loads(EFFECTS.read_text())
    effects['clips'] = clips
    EFFECTS.write_text(json.dumps(effects, indent=2, ensure_ascii=False) + '\n', newline='\n')
    print(f'PIXELLAB_VFX_IMPORTED clips={len(clips)}')


if __name__ == '__main__':
    build()
