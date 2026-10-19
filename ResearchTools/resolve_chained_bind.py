#!/usr/bin/env python3
"""Read-only bind/rebase pointer lookup for observed X v12.25 chained fixups.

Supports format 6 (DYLD_CHAINED_PTR_64_OFFSET), imports format 1, uncompressed
symbols and single-start pages. Verifies requested address is on its page chain.
Other pointer/import/page formats are deliberately rejected.
"""
import argparse
import hashlib
import json
import struct
from inspect_text_sizing import Image


def resolve(image, addr):
    data = image.data
    off = 32
    fixup = None
    for _ in range(image.u32(16)):
        cmd, size = struct.unpack_from('<II', data, off)
        if cmd == 0x80000034: fixup = struct.unpack_from('<II', data, off+8)
        off += size
    if fixup is None: raise ValueError('no chained fixups')
    base, length = fixup
    version, starts, imports, symbols, count, fmt, symfmt = struct.unpack_from('<7I', data, base)
    if (version, fmt, symfmt) != (0, 1, 0): raise ValueError('unsupported fixup/import format')
    segment_index = next(i for i, (lo, hi, _) in enumerate(image.segments) if lo <= addr < hi)
    starts += base
    if segment_index >= image.u32(starts): raise ValueError('segment missing')
    rel = image.u32(starts+4+segment_index*4)
    if not rel: raise ValueError('segment has no fixups')
    segment = starts+rel
    size, page_size, pointer_format, segment_offset, max_valid, pages = struct.unpack_from('<IHHQIH', data, segment)
    if pointer_format != 6: raise ValueError('unsupported pointer format')
    image_base = min(lo for lo, _, _ in image.segments)
    page = (addr-image_base-segment_offset)//page_size
    if not 0 <= page < pages: raise ValueError('address outside fixup pages')
    page_start = struct.unpack_from('<H', data, segment+22+page*2)[0]
    if page_start == 0xffff or page_start & 0x8000: raise ValueError('unsupported or empty fixup page')
    pc = image_base+segment_offset+page*page_size+page_start
    while pc < addr:
        raw = struct.unpack_from('<Q', data, image.offset(pc, 8))[0]
        step = ((raw >> 51) & 0xfff)*4
        if not step: raise ValueError('requested address not on chain')
        pc += step
    if pc != addr: raise ValueError('requested address not on chain')
    raw = struct.unpack_from('<Q', data, image.offset(addr, 8))[0]
    if not raw >> 63:
        if (raw >> 36) & 0xff: raise ValueError('unsupported high8 rebase target')
        target = image_base+(raw & ((1 << 36)-1))
        image.offset(target)
        return dict(address=hex(addr), raw=hex(raw), pointer_format=pointer_format,
                    kind='rebase', target=hex(target), symbols=image.symbols.get(target, []),
                    chain_verified=True)
    ordinal = raw & 0xffffff
    if ordinal >= count: raise ValueError('bind ordinal out of range')
    entry = image.u32(base+imports+ordinal*4)
    nameoff = base+symbols+(entry >> 9)
    if nameoff >= base+length: raise ValueError('symbol name out of fixup data')
    return dict(address=hex(addr), raw=hex(raw), pointer_format=pointer_format, kind='bind',
                ordinal=ordinal, symbol=image.cstring_offset(nameoff), chain_verified=True)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--macho', required=True)
    p.add_argument('--address', action='append', type=lambda value: int(value, 0), required=True)
    a = p.parse_args()
    image = Image(a.macho)
    print(json.dumps(dict(sha256=hashlib.sha256(image.data).hexdigest(),
                          bindings=[resolve(image, addr) for addr in a.address]), indent=2))


if __name__ == '__main__': main()
