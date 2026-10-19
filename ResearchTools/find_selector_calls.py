#!/usr/bin/env python3
"""Find direct arm64 B/BL instructions to resolved selector stubs.

Reports LC_FUNCTION_STARTS container and class/metaclass owner where available.
Does not cover indirect objc_msgSend, dynamically resolved calls or categories.
"""
import argparse
import bisect
import hashlib
import json
import struct
from inspect_text_sizing import Image
from find_method_owners import find_methods


def calls(image, selector):
    targets = {pc for pc, (_, sel) in image.objc_stubs.items() if sel == selector}
    owners = {}
    for method in find_methods(image): owners.setdefault(int(method['imp'], 16), []).append(method)
    result = []
    for name, addr, size, fileoff, flags, *_ in image.sections:
        if name != '__text': continue
        for index, (word,) in enumerate(struct.iter_unpack('<I', image.data[fileoff:fileoff+size])):
            if word & 0x7c000000 != 0x14000000: continue
            pc = addr+index*4
            offset = word & 0x3ffffff
            if offset & 0x2000000: offset -= 0x4000000
            target = pc+offset*4
            if target not in targets: continue
            fi = bisect.bisect_right(image.function_starts, pc)-1
            start = image.function_starts[fi] if fi >= 0 else None
            result.append(dict(callsite=hex(pc), branch='bl' if word >> 31 else 'b',
                               target=hex(target), function=hex(start) if start is not None else None,
                               owners=owners.get(start, [])))
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--macho', required=True)
    p.add_argument('--selector', required=True)
    a = p.parse_args()
    image = Image(a.macho)
    print(json.dumps(dict(sha256=hashlib.sha256(image.data).hexdigest(), selector=a.selector,
                          calls=calls(image, a.selector)), ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
