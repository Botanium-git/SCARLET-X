#!/usr/bin/env python3
"""Resolve class/metaclass-owned relative methods in the supplied X v12.25 images.

Read-only; requires inspect_text_sizing.py and capstone. Only nlist-defined
ObjC classes/metaclasses and observed 0x8000000C lists are supported.
Categories and dynamically attached/replaced methods are not covered.
"""
import argparse
import hashlib
import json
import struct
from inspect_text_sizing import Image


def find_methods(image, selector=None, imp=None):
    def ptr(addr):
        return struct.unpack_from('<Q', image.data, image.offset(addr, 8))[0] & ((1 << 36)-1)
    def rel(addr):
        return struct.unpack_from('<i', image.data, image.offset(addr, 4))[0]
    for address, names in image.symbols.items():
        for symbol in names:
            if not symbol.startswith(('_OBJC_CLASS_$_', '_OBJC_METACLASS_$_')):
                continue
            ro = ptr(address+32) & ~7
            name = image.pointer_string(ro+24)
            if name != symbol.split('$_', 1)[1]:
                raise ValueError(f'class name mismatch: {symbol}')
            methods = ptr(ro+32)
            if not methods: continue
            head, count = struct.unpack_from('<II', image.data, image.offset(methods, 8))
            if head != 0x8000000c:
                continue
            if count > 20000: raise ValueError('implausible method count')
            for index in range(count):
                entry = methods+8+12*index
                pc = entry+8+rel(entry+8)
                if imp is not None and imp != pc: continue
                sel = image.pointer_string(entry+rel(entry))
                if selector is not None and selector != sel: continue
                executable = pc % 4 == 0 and any(
                    lo <= pc < lo+size and flags & 0x80000400
                    for _, lo, size, _, flags, *_ in image.sections)
                types = image.cstring_offset(image.offset(entry+4+rel(entry+4)))
                yield dict(owner=name, kind='class' if 'METACLASS' in symbol else 'instance',
                           class_address=hex(address), ro=hex(ro), method_list=hex(methods),
                           entry=hex(entry), selector=sel, types=types, imp=hex(pc), executable=executable)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--macho', required=True)
    p.add_argument('--selector')
    p.add_argument('--imp', type=lambda value: int(value, 0))
    a = p.parse_args()
    if a.selector is None and a.imp is None: p.error('specify --selector and/or --imp')
    image = Image(a.macho)
    print(json.dumps(dict(sha256=hashlib.sha256(image.data).hexdigest(),
                          matches=list(find_methods(image, a.selector, a.imp))),
                     ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
