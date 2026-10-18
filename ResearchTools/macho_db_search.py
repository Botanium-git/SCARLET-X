#!/usr/bin/env python3
"""Read-only search/triage of SCARLET Mach-O SQLite indexes (Python stdlib)."""
import argparse
import json
import sqlite3
import sys
from pathlib import Path

TABLES = {
    "objc_methods": ("selector", "types", "imp", "list_address", "entry_index"),
    "symbols": ("name", "kind", "address"),
    "functions": ("name", "address"),
    "strings": ("text", "address", "file_offset"),
    "imports": ("symbol", "source", "address"),
}


def run():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--db", type=Path, required=True, help="Existing scarlet_macho.sqlite")
    p.add_argument("--table", choices=[*TABLES, "all"], default="all")
    p.add_argument("--query", required=True, help="Literal substring (not raw SQL)")
    p.add_argument("--binary", help="Optional indexed binary name, e.g. T1Twitter")
    p.add_argument("--limit", type=int, default=40)
    p.add_argument("--json", action="store_true", help="JSON lines for downstream analysis")
    args = p.parse_args()
    if not args.db.is_file():
        p.error(f"database not found: {args.db}")
    if not 1 <= args.limit <= 1000:
        p.error("--limit must be 1..1000")
    try:
        conn = sqlite3.connect(f"file:{args.db.resolve()}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        existing = {r["name"] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if "binaries" not in existing:
            p.error("missing binaries table")
        found = 0
        for table in ([args.table] if args.table != "all" else TABLES):
            if table not in existing:
                continue
            available = {r["name"] for r in conn.execute(f"PRAGMA table_info({table})")}
            fields = [f for f in TABLES[table] if f in available]
            terms = [f for f in fields if f not in ("address", "imp", "file_offset", "list_address", "entry_index")]
            if not terms:
                continue
            remaining = args.limit - found
            if remaining <= 0:
                break
            conditions = "(" + " OR ".join(f"{f} LIKE ? ESCAPE '\\'" for f in terms) + ")"
            # Escape LIKE metacharacters to ensure literal substring search.
            needle = "%" + args.query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
            params = [needle] * len(terms)
            if args.binary:
                conditions += " AND b.name = ?"
                params.append(args.binary)
            stmt = (
                f"SELECT b.name AS binary_name, t.* FROM {table} t "
                "JOIN binaries b ON b.id=t.binary_id WHERE " + conditions +
                " LIMIT ?"
            )
            params.append(remaining)
            for row in conn.execute(stmt, params):
                item = dict(row)
                for key in ("address", "imp", "file_offset", "list_address"):
                    if item.get(key) is not None:
                        item[key + "_hex"] = f"0x{item[key]:X}"
                item["table"] = table
                if args.json:
                    print(json.dumps(item, ensure_ascii=False))
                else:
                    print(f"[{table}] " + json.dumps(item, ensure_ascii=False))
                found += 1
        if not args.json:
            print(f"total={found}", file=sys.stderr)
    except sqlite3.DatabaseError as exc:
        p.error(f"SQLite error: {exc}")
    finally:
        if "conn" in locals():
            conn.close()


if __name__ == "__main__":
    run()
