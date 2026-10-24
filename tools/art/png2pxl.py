"""Convert a sprite PNG into a pxl (claude-pxl) text-grid sprite (presentation only).

Standard library only (no Pillow): decodes 8-bit RGB/RGBA, non-interlaced PNGs, reduces the
colours to a palette (k-means), assigns one key per colour and writes a .px.js file with
`pal({...})` + `sprite(...)`. Fully transparent pixels become '.'; partial alpha is kept as #rrggbbaa.
Usage: python tools/art/png2pxl.py <sprite.png> [out.px.js] [--name NAME] [--colors N] [--part]
  --colors  palette size (default 48, max 86)
  --part    emit the sprite as a pxl part ("_name"), for files that build anims on top of it.
"""
import struct
import sys
import zlib
from pathlib import Path

# '.', '_', '#' and space are reserved by pxl; '`', '$' and '\\' would break template literals.
KEYS = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!%&()*+,-/:;<=>?@[]^{|}~'


def read_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'{path}: not a PNG')
    pos, idat, header, palette, alphas = 8, b'', None, [], b''
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', chunk)
        elif kind == b'IDAT':
            idat += chunk
        elif kind == b'PLTE':
            palette = [tuple(chunk[i:i + 3]) for i in range(0, length, 3)]
        elif kind == b'tRNS':
            alphas = chunk
        pos += 12 + length
    width, height, depth, colour, _, _, interlace = header
    channels = {2: 3, 3: 1, 6: 4}.get(colour)
    if depth != 8 or channels is None or interlace:
        raise ValueError(f'{path}: only 8-bit RGB/RGBA/indexed non-interlaced PNGs are supported')
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, prev = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for x in range(stride):
            left = line[x - channels] if x >= channels else 0
            up = prev[x]
            corner = prev[x - channels] if x >= channels else 0
            if kind == 1:
                line[x] = (line[x] + left) & 255
            elif kind == 2:
                line[x] = (line[x] + up) & 255
            elif kind == 3:
                line[x] = (line[x] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                line[x] = (line[x] + (left if pa <= pb and pa <= pc else up if pb <= pc else corner)) & 255
        if channels == 1:
            rows.append([palette[i] + (alphas[i] if i < len(alphas) else 255,) for i in line])
        else:
            rows.append([tuple(line[x:x + channels]) + ((255,) if channels == 3 else ())
                         for x in range(0, stride, channels)])
        prev = line
    return width, height, rows


def quantize(rows, colours):
    """Deterministic k-means in RGB: the AI-derived sprites carry thousands of near-identical
    shades, while pxl grids need one key per colour. Returns new rows and the max channel error."""
    pixels = [px for row in rows for px in row if px[3]]
    if len(set(pixels)) <= colours:
        return rows, 0
    # Farthest-point initialisation from the most common colour keeps runs reproducible.
    counts = {}
    for px in pixels:
        counts[px[:3]] = counts.get(px[:3], 0) + 1
    unique = sorted(counts, key=lambda c: (-counts[c], c))
    dist = lambda a, b: sum((x - y) ** 2 for x, y in zip(a, b))
    centres = [unique[0]]
    nearest = {c: dist(c, centres[0]) for c in unique}
    while len(centres) < colours:
        far = max(unique, key=lambda c: (nearest[c], counts[c]))
        centres.append(far)
        for c in unique:
            nearest[c] = min(nearest[c], dist(c, far))
    for _ in range(20):
        owner = {c: min(range(len(centres)), key=lambda i: dist(c, centres[i])) for c in unique}
        sums = [[0, 0, 0, 0] for _ in centres]
        for c, i in owner.items():
            n = counts[c]
            sums[i] = [sums[i][0] + c[0] * n, sums[i][1] + c[1] * n, sums[i][2] + c[2] * n, sums[i][3] + n]
        moved = [tuple(round(s[j] / s[3]) for j in range(3)) if s[3] else centres[i] for i, s in enumerate(sums)]
        if moved == centres:
            break
        centres = moved
    owner = {c: centres[min(range(len(centres)), key=lambda i: dist(c, centres[i]))] for c in unique}
    error = max(max(abs(x - y) for x, y in zip(c, owner[c])) for c in unique)
    return [[owner[px[:3]] + (px[3],) if px[3] else px for px in row] for row in rows], error


def to_pxl(rows, name, part=False, colours=48):
    rows, error = quantize(rows, colours)
    counts = {}
    for row in rows:
        for px in row:
            if px[3]:
                counts[px] = counts.get(px, 0) + 1
    if len(counts) > len(KEYS):
        raise ValueError(f'{len(counts)} colours; pxl text grids support at most {len(KEYS)} here')
    # Most common colours get the simplest keys, so hand edits stay readable.
    order = sorted(counts, key=lambda px: (-counts[px], px))
    key_of = {px: KEYS[i] for i, px in enumerate(order)}
    hexes = {key_of[px]: '#%02x%02x%02x' % px[:3] + ('' if px[3] == 255 else '%02x' % px[3]) for px in order}
    grid = '\n'.join('  ' + ''.join(key_of.get(px, '.') if px[3] else '.' for px in row) for row in rows)
    pal = ',\n'.join(f'  "{k}": "{v}"' for k, v in hexes.items())
    sprite_name = ('_' if part else '') + name
    return (f'// Generated by tools/art/png2pxl.py; {len(order)} colours, max channel error {error}.\n'
            f'pal({{\n{pal}\n}})\n\n'
            f'sprite("{sprite_name}", `\n{grid}`)\n')


def main(argv):
    options, args, i = {}, [], 0
    while i < len(argv):
        if argv[i] in ('--name', '--colors'):
            options[argv[i]] = argv[i + 1]
            i += 2
        else:
            args.append(argv[i])
            i += 1
    paths = [a for a in args if not a.startswith('--')]
    if not paths:
        print(__doc__)
        return 1
    src = Path(paths[0])
    out = Path(paths[1]) if len(paths) > 1 else src.with_suffix('.px.js')
    name = options.get('--name', src.stem)
    _, _, rows = read_png(src)
    text = to_pxl(rows, name, '--part' in args, int(options.get('--colors', 48)))
    out.write_text(text, encoding='utf-8', newline='\n')
    print(f'{src} -> {out} ({text.splitlines()[0][3:]})')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
