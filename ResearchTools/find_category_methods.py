#!/usr/bin/env python3
"""Read-only owner lookup for observed X v12.25 relative category methods.

Only __objc_catlist and indirect relative lists with header 0x8000000C.
Class pointers are resolved with verified chained bind/rebase lookup.
Does not infer runtime category loading/override precedence.
"""
import argparse
import hashlib
import json
import struct
from inspect_text_sizing import Image
from resolve_chained_bind import resolve


def find_categories(image, selector):
    def ptr(addr):
        return struct.unpack_from('<Q', image.data, image.offset(addr, 8))[0] & ((1 << 36)-1)
    def rel(addr):
        return struct.unpack_from('<i', image.data, image.offset(addr, 4))[0]
    for section, lo, size, *_ in image.sections:
        if section != '__objc_catlist': continue
        for slot in range(lo, lo+size, 8):
            category = ptr(slot)
            for offset, kind in [(16, 'instance'), (24, 'class')]:
                methods = ptr(category+offset)
                if not methods: continue
                head, count = struct.unpack_from('<II', image.data, image.offset(methods, 8))
                if head != 0x8000000c: continue
                if count > 20000: raise ValueError('implausible method count')
                for index in range(count):
                    entry = methods+8+12*index
                    sel = image.pointer_string(entry+rel(entry))
                    if sel != selector: continue
                    binding = resolve(image, category+8)
                    symbols = [binding['symbol']] if binding['kind'] == 'bind' else binding['symbols']
                    pc = entry+8+rel(entry+8)
                    yield dict(category=image.pointer_string(category), category_address=hex(category),
                               class_reference=binding, owner_symbols=symbols, kind=kind,
                               method_list=hex(methods), entry=hex(entry), selector=sel,
                               types=image.cstring_offset(image.offset(entry+4+rel(entry+4))),
                               imp=hex(pc), executable=pc % 4 == 0 and any(
                                   a <= pc < a+s and flags & 0x80000400
                                   for _, a, s, _, flags, *_ in image.sections))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--macho', required=True)
    p.add_argument('--selector', required=True)
    a = p.parse_args()
    image = Image(a.macho)
    print(json.dumps(dict(sha256=hashlib.sha256(image.data).hexdigest(),
                          matches=list(find_categories(image, a.selector))), ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
