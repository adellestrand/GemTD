"""Prepare native-size references for the active enemy animation pass.

No credentials or network calls. Reuses the exact first pose currently in game.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/pixellab-enemies-v1'

MOTIONS = {
    'alpaca': 'The alpaca walks in place with four alternating planted hooves, a gentle neck nod and small blanket movement.',
    'azuremir': 'The four-legged dragon walks in place with alternating claws and a gently counterbalancing tail. Its back spikes stay attached.',
    'baby_roshan': 'The little winged demon flies in place, repeatedly beating both bat wings smoothly up and down. Its legs tuck beneath its steady body.',
    'baekho': 'The wolf trots in place with alternating forelegs and hindlegs, flexing paws and a slight tail sway.',
    'bajie': 'The pig walks in place with four alternating hooves and a slight head nod. Its headband stays attached.',
    'blue_courier': 'The balloon courier floats in place. Its balloons gently bob and sway together, ropes stay connected, the suspended animal slowly swings beneath them. No walking.',
    'bookwyrm': 'The four-legged dragon walks in place with alternating planted claws, a slight head nod and gentle tail sway.',
    'boooofus': 'The hooded reaper walks in place with alternating feet, gentle robe movement and a tiny scythe sway. Both hands hold the scythe throughout.',
    'boss_hound': 'The armored heavy hound walks powerfully in place, alternating all four paws with deliberate weight transfer and subtle head nod. Armor stays firmly attached.',
    'bulldog': 'The bulldog walks in place with four alternating paws and gentle weight transfer. Its muzzle and ears keep their shape.',
    'carpet_rider': 'The rider floats in place on the magic carpet. The carpet corners undulate gently and tassels sway while the seated rider makes a subtle bob. No walking.',
    'chicken': 'The chicken walks in place with alternating raised and planted feet. Its head makes a tiny coordinated nod and its folded wings stay folded.',
    'chirpy': 'The winged creature flies in place with a continuous full upstroke and downstroke of both feathered wings, steady head and tucked legs.',
    'corsair': 'The small flying ship hovers in place. Both feathered side wings repeatedly beat up and down; the red sail gently ripples and the hull remains rigid.',
    'courier_robot': 'The mechanical robot marches in place with alternating metal feet and bent leg joints. Its round chassis stays rigid and both eye lenses remain steady.',
    'crummy': 'The shaggy wizard beast walks in place on alternating paws. Fur and beard sway subtly while its pointed hat remains attached.',
    'drodo': 'The dodo walks in place on two alternating bird feet, with a slight beak nod and tiny folded-wing sway.',
    'dusky': 'The dark dog trots in place with four alternating planted paws and gentle tail movement.',
    'flamingo': 'The flamingo rides its skateboard in place: wheels rotate subtly and the bent legs and long neck balance with a small rhythmic movement. Keep both feet on the skateboard and the deck rigid.',
    'fox': 'The fox flies in place using steady upstrokes and downstrokes of its feathered wings, keeping its legs tucked and head steady.',
    'frog': 'The frog makes a continuous small forward hopping cycle in place: hind legs compress, extend, and land, forefeet catch the landing. Very small vertical rise, no travel.',
    'furry_fish': 'The round fish swims in place with alternating tail sweeps and small fluttering fins. Keep its round body stable with only a subtle bob.',
    'ghost': 'The ghost floats in place. Its long wispy tendrils ripple and curl gently beneath a steady hooded head. No limbs or new objects appear.',
    'goldfish': 'The goldfish swims in place with clear side-to-side tail beats, gently fluttering fins and a steady round body.',
    'huntling': 'The winged creature flies in place with repeated synchronized feathered wing upstrokes and downstrokes. Keep its legs tucked and head steady.',
    'ig_dragon': 'The green bat-winged dragon flies in place with both wings beating up and down and a gentle tail sway. Its feet remain tucked beneath the body.',
    'invisible_spider': 'The eight-legged spider crawls in place with coordinated alternating groups of bent legs. Feet lift and plant clearly while the abdomen remains steady.',
    'jinyin_fox': 'The black and white fox flies in place with a smooth feathered wing flap cycle and a small tail sway. Keep its head steady.',
    'jumo': 'The small dressed courier walks in place with two alternating planted feet and gentle arm swing. Its lantern stays held, cap and scarf move only slightly.',
    'kupu': 'The butterfly flies in place, repeatedly opening and closing both patterned wings at their body joints. Keep the tiny head and antennae steady.',
    'lilnova': 'The small dark armored beast walks in place with alternating planted paws, subtle shoulder movement and a slight tail sway.',
    'lizard': 'The four-legged lizard walks in place, alternately lifting and planting its claws, with a gentle tail sweep. Back spikes remain attached.',
    'lockjaw': 'The mechanical treasure chest marches in place using its small alternating metal feet. The lid, coins and chest stay rigid and closed.',
    'machjaw': 'The mechanical chest robot marches in place using alternating jointed metal legs. Its chassis, open chest lid and coins retain their shapes and positions.',
    'mermaid': 'The rider and flying fish hover in place. The fish beats its tail and flutters its fins while the seated rider stays balanced with subtle hair movement.',
    'panda_flyer': 'The tiny panda flies in place suspended beneath its overhead rotor. The rotor spins around its central hub while the panda gently bobs. Keep the bamboo harness attached.',
    'pig_princess': 'The crowned pig walks in place with four alternating planted hooves and a gentle head nod. The crown stays attached and rigid.',
    'rabbit': 'The rabbit makes a small in-place hopping loop, compressing and extending its hind legs, then landing on its forepaws. Ears sway slightly, no forward travel.',
    'red_courier': 'The red bat flies in place with full synchronized wing upstrokes and downstrokes. Body and head stay steady and feet tucked.',
    'ripper': 'The skeletal dinosaur strides in place with two alternating hind feet, slight counterbalancing tail sweep and tiny forearm movement. Its skull and bones stay connected.',
    'shagbark': 'The heavy wooden beast walks in place with four alternating planted feet. Its leafy mane sways gently while the wooden body remains solid.',
    'shark': 'The small shark walks in place using its little alternating feet, with a gentle tail sweep and tiny fin movement. Keep its body and grin stable.',
    'sheep': 'The small woodland archer walks in place with two alternating feet, slight arm movement and gentle cloak movement. The bow stays held and rigid.',
    'shroomy': 'The mushroom creature walks in place with two alternating short feet and a gentle cap bob. The spotted cap keeps its rounded shape.',
    'stump': 'The living tree stump walks in place on alternating root feet. Its twig arms gently counter-swing and the small leaves sway slightly.',
    'trapjaw': 'The purple mimic chest walks in place on its alternating thin legs. The toothed chest lid and eye stalks gently bob, with no opening or closing of the lid.',
    'wabbit': 'The winged white rabbit flies in place with smooth feathered wing upstrokes and downstrokes, tucked legs and slight ear movement.',
    'yak': 'The shaggy yak walks in place with four alternating planted hooves and gentle weight transfer. Its saddle stays attached and its long fur sways slightly.',
    'young_demon': 'The small red demon walks in place with two alternating planted feet and counter-swinging arms. Its wings stay mostly folded and tail sways gently.',
    'zombie': 'The dressed zombie walks stiffly in place with two alternating feet, a small arm counter-swing and gentle robe movement. Its hat and face ribbon stay attached.',
}


def main():
    if (OUT/'plan.json').exists():
        raise SystemExit('Existing pass retained. Resume from output/pixellab-enemies-v1/plan.json; do not overwrite references for submitted jobs.')
    manifest = json.loads((ROOT / 'assets/graphics/manifest.json').read_text())
    campaign = json.loads((ROOT / 'data/campaign.json').read_text())
    bindings = manifest['bindings']['enemies']
    used = sorted(set(bindings.values()))
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGB', (800, ((len(used)+7)//8)*125), '#283329')
    draw = ImageDraw.Draw(sheet)
    entries = []
    for n, enemy in enumerate(used):
        entry = manifest['sprites'][enemy]
        source = ROOT / entry['texture'].removeprefix('res://')
        strip = Image.open(source).convert('RGBA')
        frame = strip.crop((0, 0, strip.width//entry['frames'], strip.height))
        body = frame.crop(frame.getbbox())
        x, y = (n % 8)*100, (n//8)*125
        thumb = body.resize((body.width*min(2,90//body.width), body.height*min(2,90//body.width)), Image.Resampling.NEAREST)
        sheet.paste(thumb, (x+(100-thumb.width)//2,y+5), thumb)
        draw.text((x+2,y+105),enemy,fill='white')
        if enemy == 'boar':
            continue
        # Transparent room for moving limbs; preserve the native pixel size.
        width = ((body.width+23)//8)*8
        height = ((body.height+23)//8)*8
        reference = Image.new('RGBA', (width,height))
        reference.paste(body, ((width-body.width)//2,(height-body.height)//2))
        dest = OUT / f'{enemy}_reference.png'
        reference.save(dest)
        waves = [w for w in campaign['waves'] if bindings.get(w['source_id']) == enemy]
        entries.append(dict(id=enemy, reference=str(dest), previous=entry.copy(),
                            size=[width,height], frames=8,
                            air=any(w['air'] for w in waves) or any('_fly' in source for source,id in bindings.items() if id==enemy),
                            wave_names=sorted(set(w['name'] for w in waves)),
                            seed=26102600+n, estimated_generations=(width*height*8+65535)//65536))
        entries[-1]['action'] = ('An eight-frame seamless looping locomotion animation. '+MOTIONS[enemy]+
            ' Maintain exactly the original facing, character identity, proportions, accessories and pixel-art style.'
            ' Locked camera, no turn, no zoom, no horizontal translation, no squash or stretching.'
            ' Keep the whole character and moving limbs inside the transparent canvas.'
            ' Return smoothly to the starting stance at the end for a continuous loop.')
    (OUT/'plan.json').write_text(json.dumps(entries,indent=2)+'\n')
    sheet.save(OUT/'references.png')
    print(f'{len(entries)} new loops, estimated {sum(x["estimated_generations"] for x in entries)} generations')
    for e in entries:
        print(e['id'], e['size'], 'air' if e['air'] else 'ground', ', '.join(e['wave_names']))


if __name__ == '__main__':
    main()
