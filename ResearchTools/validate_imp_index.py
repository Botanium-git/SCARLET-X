#!/usr/bin/env python3
"""Validate ObjC implementation addresses against Mach-O executable sections.

Produces a new SQLite file; never mutates the original index.
Requires only Python 3 stdlib.
"""
import argparse
import json
import shutil
import sqlite3
import struct
from pathlib import Path

LC_SEGMENT_64 = 0x19
S_ATTR_PURE_INSTRUCTIONS = 0x80000000
S_ATTR_SOME_INSTRUCTIONS = 0x00000400


def executable_sections(path):
    data = Path(path).read_bytes()
    if struct.unpack_from("<I", data)[0] != 0xFEEDFACF:
        raise ValueError("requires a thin little-endian Mach-O 64-bit slice")
    ncmds = struct.unpack_from("<I", data, 16)[0]
    off = 32
    sections = []
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, off)
        if cmdsize < 8 or off + cmdsize > len(data):
            raise ValueError("invalid load command")
        if cmd == LC_SEGMENT_64:
            count = struct.unpack_from("<I", data, off + 64)[0]
            pos = off + 72
            for _ in range(count):
                name = data[pos:pos+16].split(b"\0")[0].decode("utf-8", "replace")
                addr, size = struct.unpack_from("<QQ", data, pos + 32)
                flags = struct.unpack_from("<I", data, pos + 64)[0]
                if flags & (S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS):
                    sections.append((addr, addr + size, name))
                pos += 80
        off += cmdsize
    if not sections:
        raise ValueError("no executable sections found")
    return sections


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--db", required=True, type=Path, help="existing SQLite index")
    p.add_argument("--macho", required=True, type=Path, help="extracted matching thin Mach-O")
    p.add_argument("--binary", required=True, help="name in binaries table")
    p.add_argument("--output", required=True, type=Path, help="new validated SQLite")
    a = p.parse_args()
    if not a.db.is_file() or not a.macho.is_file():
        p.error("database or Mach-O missing")
    if a.output.resolve() == a.db.resolve() or a.output.exists():
        p.error("output must be a new, distinct file")
    sections = executable_sections(a.macho)
    # Read original via SQLite backup API so live journal state is respected.
    src = sqlite3.connect(f"file:{a.db.resolve()}?mode=ro", uri=True)
    dst = sqlite3.connect(a.output)
    try:
        src.backup(dst)
        row = dst.execute("SELECT id FROM binaries WHERE name=?", (a.binary,)).fetchone()
        if not row:
            raise ValueError(f"binary not indexed: {a.binary}")
        bid = row[0]
        methods = dst.execute("SELECT rowid,imp FROM objc_methods WHERE binary_id=?", (bid,)).fetchall()
        invalid = [rowid for rowid, imp in methods
                   if not any(start <= imp < end for start, end, _ in sections)]
        dst.executemany("DELETE FROM objc_methods WHERE rowid=?", ((n,) for n in invalid))
        dst.commit()
        print(json.dumps({
            "binary": a.binary,
            "input_count": len(methods),
            "validated_count": len(methods)-len(invalid),
            "rejected_count": len(invalid),
            "executable_sections": sections,
            "output": str(a.output),
        }, ensure_ascii=False, indent=2))
    finally:
        src.close()
        dst.close()


if __name__ == "__main__":
    main()
