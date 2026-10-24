"""Read an installed Valve VPK without copying game assets into the project."""
import argparse
import json
from pathlib import Path
import struct
import sys


def entries(path):
    with path.open('rb') as source:
        signature, version, tree_size = struct.unpack('<III', source.read(12))
        if signature != 0x55AA1234 or version not in (1, 2):
            raise ValueError('Unsupported VPK header')
        header_size = 28 if version == 2 else 12
        source.seek(header_size)
        tree = source.read(tree_size)
        cursor = 0

        def string():
            nonlocal cursor
            end = tree.index(b'\0', cursor)
            value = tree[cursor:end].decode('utf-8')
            cursor = end + 1
            return value

        while extension := string():
            while folder := string():
                while name := string():
                    crc, preload_count, archive, offset, length, terminator = struct.unpack_from('<IHHIIH', tree, cursor)
                    cursor += 18
                    if terminator != 65535:
                        raise ValueError('Bad entry terminator')
                    preload = tree[cursor:cursor + preload_count]
                    cursor += preload_count
                    filename = f'{name}.{extension}' if extension != ' ' else name
                    key = f'{folder}/{filename}' if folder != ' ' else filename
                    yield key, archive, header_size + tree_size + offset, length, preload


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('vpk', type=Path)
    parser.add_argument('--read')
    parser.add_argument('--out', type=Path)
    parser.add_argument('--match', default='')
    args = parser.parse_args()
    found = list(entries(args.vpk))
    if args.read:
        for key, archive, offset, length, preload in found:
            if key == args.read:
                if archive != 32767:
                    raise ValueError('External VPK archive not supported')
                with args.vpk.open('rb') as source:
                    source.seek(offset)
                    data = preload + source.read(length)
                if args.out:
                    args.out.parent.mkdir(parents=True, exist_ok=True)
                    args.out.write_bytes(data)
                    print(f'Wrote {len(data)} bytes to {args.out}')
                else:
                    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
                    print(data.decode('utf-8', errors='replace'))
                return
        raise ValueError('Entry not found')
    print(json.dumps([{'path': k, 'bytes': n + len(p), 'archive': a} for k, a, o, n, p in found if args.match.lower() in k.lower()], indent=2))


if __name__ == '__main__':
    main()
