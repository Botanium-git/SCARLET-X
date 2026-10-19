#!/usr/bin/env python3
"""Read-only, thin arm64 Mach-O disassembly with nlist/indirect-stub evidence.

Requires capstone 5. Addresses are unslid VM addresses. Does not execute input.
This reports static symbols/instructions, not runtime dispatch ownership.
"""
import argparse
import hashlib
import struct
from pathlib import Path
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM


class Image:
    def __init__(self, path):
        self.data = Path(path).read_bytes()
        if self.u32(0) != 0xfeedfacf:
            raise ValueError('requires thin little-endian Mach-O64')
        self.sections, self.segments, self.symbols, self.stubs = [], [], {}, {}
        symtab = dysymtab = None
        off = 32
        for _ in range(self.u32(16)):
            cmd, size = struct.unpack_from('<II', self.data, off)
            if size < 8 or off + size > len(self.data):
                raise ValueError('invalid load command')
            if cmd == 0x19:
                vm, vs, fo, fs = struct.unpack_from('<QQQQ', self.data, off+24)
                self.segments.append((vm, vm+min(vs, fs), fo))
                for j in range(self.u32(off+64)):
                    p = off+72+j*80
                    name = self.data[p:p+16].split(b'\0')[0].decode()
                    addr, length, fileoff = struct.unpack_from('<QQI', self.data, p+32)
                    flags, reserved1, reserved2 = struct.unpack_from('<III', self.data, p+64)
                    self.sections.append((name, addr, length, fileoff, flags, reserved1, reserved2))
            elif cmd == 2:
                symtab = struct.unpack_from('<IIII', self.data, off+8)
            elif cmd == 0xb:
                dysymtab = struct.unpack_from('<18I', self.data, off+8)
            off += size
        entries = []
        if symtab:
            so, count, strings, stringsize = symtab
            for i in range(count):
                idx, typ, sect, desc, value = struct.unpack_from('<IBBHQ', self.data, so+16*i)
                name = self.cstring_offset(strings+idx)
                entries.append(name)
                if typ & 0x0e == 0x0e:
                    self.symbols.setdefault(value, []).append(name)
        if dysymtab:
            io, count = dysymtab[12:14]
            for name, addr, size, fo, flags, first, stride in self.sections:
                if flags & 0xff == 8 and stride:
                    for j in range(size//stride):
                        index = self.u32(io+4*(first+j))
                        if index < len(entries): self.stubs[addr+j*stride] = entries[index]
        self.objc_stubs = {}
        md = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
        md.detail = True
        for name, addr, size, fo, flags, first, stride in self.sections:
            if name != '__objc_stubs': continue
            for pc in range(addr, addr+size, 32):
                ins = list(md.disasm(self.data[self.offset(pc):self.offset(pc)+8], pc))
                if len(ins) != 2: continue
                a, b = ins
                if a.mnemonic != 'adrp' or b.mnemonic != 'ldr': continue
                if a.op_str.split(',')[0] != 'x1' or not b.op_str.startswith('x1, [x1'): continue
                ref = a.operands[1].imm + b.operands[1].mem.disp
                if not any(n == '__objc_selrefs' and lo <= ref < lo+sz for n,lo,sz,*_ in self.sections):
                    raise ValueError('selector reference outside expected section')
                self.objc_stubs[pc] = (ref, self.pointer_string(ref))

    def u32(self, off): return struct.unpack_from('<I', self.data, off)[0]
    def offset(self, addr, size=1):
        for lo, hi, fo in self.segments:
            if lo <= addr and addr+size <= hi: return fo+addr-lo
        raise ValueError(f'unmapped VM address {addr:#x}')
    def cstring_offset(self, off):
        end = self.data.find(b'\0', off)
        if end < 0: raise ValueError('unterminated string')
        return self.data[off:end].decode('utf-8', 'replace')
    def pointer_string(self, addr):
        ptr = struct.unpack_from('<Q', self.data, self.offset(addr, 8))[0] & ((1 << 36)-1)
        return self.cstring_offset(self.offset(ptr))
    def disassemble(self, start, end):
        md = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
        for i in md.disasm(self.data[self.offset(start):self.offset(end-1)+1], start):
            notes = []
            if i.address in self.symbols: notes += self.symbols[i.address]
            if i.mnemonic in ('b', 'bl') and i.op_str.startswith('#'):
                dest = int(i.op_str[1:], 0)
                notes += self.symbols.get(dest, [])
                if dest in self.stubs: notes.append('indirect:'+self.stubs[dest])
                if dest in self.objc_stubs:
                    ref, selector = self.objc_stubs[dest]
                    notes.append(f'objc:{selector} (selref {ref:#x})')
            yield f'{i.address:08X}  {i.bytes.hex():8s}  {i.mnemonic:9s} {i.op_str}' + (' ; '+' | '.join(notes) if notes else '')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--macho', required=True)
    p.add_argument('--range', nargs=2, action='append', required=True, type=lambda v: int(v, 0))
    a = p.parse_args()
    image = Image(a.macho)
    print('SHA256', hashlib.sha256(image.data).hexdigest())
    for start, end in a.range:
        print(f'\n## {start:#x}..{end:#x} (end exclusive)')
        print('\n'.join(image.disassemble(start, end)))


if __name__ == '__main__': main()
