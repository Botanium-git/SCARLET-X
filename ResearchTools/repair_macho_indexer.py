#!/usr/bin/env python3
"""Make a repaired COPY of the external SCARLET Mach-O indexer.

Never modifies its input. Fixes relative-method false positives where the
recorded IMP falls outside a Mach-O executable section.
"""
import argparse
from pathlib import Path

OLD_INIT = """        results = []
        seen = set()
        candidates ="""
NEW_INIT = """        results = []
        seen = set()
        executable = [(sec['addr'], sec['addr'] + sec['size']) for sec in self.sections
                      if sec['flags'] & (0x80000000 | 0x00000400)]
        candidates ="""
OLD_IMP = """                    imp = (imp_field_va + imp_rel) & 0xffffffffffffffff
"""
NEW_IMP = """                    imp = (imp_field_va + imp_rel) & 0xffffffffffffffff
                    if imp % 4 != 0 or not any(lo <= imp < hi for lo, hi in executable):
                        good = False; break
"""


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--original", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    if not args.original.is_file():
        p.error("original indexer not found")
    if args.original.resolve() == args.output.resolve() or args.output.exists():
        p.error("output must be a new file; original is kept untouched")
    text = args.original.read_text(encoding="utf-8")
    for old in (OLD_INIT, OLD_IMP):
        if text.count(old) != 1:
            p.error("unexpected indexer revision; refusing unsafe patch")
    repaired = text.replace(OLD_INIT, NEW_INIT).replace(OLD_IMP, NEW_IMP)
    compile(repaired, str(args.output), "exec")
    args.output.write_text(repaired, encoding="utf-8")
    print(f"Created repaired indexer: {args.output}")


if __name__ == "__main__":
    main()
