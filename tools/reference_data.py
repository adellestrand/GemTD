"""Parse public-style Valve KeyValues locally; never execute reference Lua."""
import json
from pathlib import Path
import re


def parse_kv(text):
    text = re.sub(r'//[^\n]*', '', text)
    tokens = re.findall(r'"((?:\\.|[^"\\])*)"|([{}])', text)
    flat = [a if b == '' else b for a, b in tokens]
    cursor = 0

    def block():
        nonlocal cursor
        result = {}
        while cursor < len(flat) and flat[cursor] != '}':
            key = flat[cursor]
            cursor += 1
            value = flat[cursor]
            cursor += 1
            if value == '{':
                value = block()
                cursor += 1
            result[key] = value
        return result

    return block()


if __name__ == '__main__':
    for kind in ('units', 'abilities'):
        data = parse_kv(Path(f'.tools/reference/{kind}.txt').read_text(encoding='utf-8-sig'))
        root = next(iter(data.values()))
        Path(f'.tools/reference/{kind}.json').write_text(json.dumps(root, ensure_ascii=False, indent=2), encoding='utf-8')
    units = json.loads(Path('.tools/reference/units.json').read_text(encoding='utf-8'))
    for name in ('gemtd_b1', 'gemtd_p1', 'gemtd_g1', 'gemtd_baiyin', 'gemtd_kongqueshi', 'gemtd_xingcaihongbaoshi'):
        unit = units.get(name, {})
        print(name, json.dumps({k:v for k,v in unit.items() if k.startswith(('Attack', 'Ability', 'Combat', 'Armor', 'Magical', 'Status'))}, ensure_ascii=True))
