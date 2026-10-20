#!/usr/bin/env python3
"""Token and tool-efficiency report from the local Copilot session store.

    python3 agent-tools/token-report.py [--db PATH] [--days N]

Reports cache hit rate, effective token cost, the most expensive sessions, and the
read/re-read ratio. Re-run it after changing habits to see whether anything improved —
the numbers in rules/context-discipline.md came from this.

Read-only. Never reads .env or any credential file.
"""

import argparse
import sqlite3
import sys
from pathlib import Path

# A cache read is billed at roughly a tenth of a fresh input token, a cache write at
# roughly 1.25x. Used only for relative comparison, not billing.
CACHE_READ_W = 0.10
CACHE_WRITE_W = 1.25


def q(con, sql, args=()):
    try:
        return con.execute(sql, args).fetchall()
    except sqlite3.Error:
        return []


def human(n):
    for unit, div in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if n >= div:
            return f"{n/div:.1f}{unit}"
    return str(int(n))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(Path.home() / ".copilot" / "session-store.db"))
    ap.add_argument("--days", type=int, default=90)
    args = ap.parse_args()

    db = Path(args.db)
    if not db.exists():
        print(f"no session store at {db}")
        return 1

    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    since = f"-{args.days} days"

    rows = q(con, """
        SELECT model,
               COUNT(DISTINCT session_id),
               SUM(input_tokens), SUM(output_tokens),
               SUM(cache_read_tokens), SUM(cache_write_tokens)
        FROM assistant_usage_events
        WHERE substr(created_at,1,10) >= date('now', ?)
        GROUP BY model ORDER BY SUM(input_tokens) DESC
    """, (since,))

    if not rows:
        print(f"no usage events in the last {args.days} days")
        return 0

    print(f"\nTOKEN USAGE — last {args.days} days\n")
    print(f"{'model':28} {'sess':>5} {'input':>9} {'cached':>9} {'hit%':>6} {'effective':>10}")
    print("-" * 72)

    tot_in = tot_cached = tot_eff = 0
    for model, sess, inp, out, cr, cw in rows:
        inp, out, cr, cw = inp or 0, out or 0, cr or 0, cw or 0
        hit = 100.0 * cr / inp if inp else 0.0
        eff = (inp - cr) + CACHE_READ_W * cr + CACHE_WRITE_W * cw + out
        tot_in += inp
        tot_cached += cr
        tot_eff += eff
        print(f"{(model or '?')[:28]:28} {sess:>5} {human(inp):>9} {human(cr):>9} {hit:>5.1f}% {human(eff):>10}")

    hit = 100.0 * tot_cached / tot_in if tot_in else 0.0
    print("-" * 72)
    print(f"{'TOTAL':28} {'':>5} {human(tot_in):>9} {human(tot_cached):>9} {hit:>5.1f}% {human(tot_eff):>10}")
    print(f"\ncache hit rate {hit:.1f}% — raw input {human(tot_in)} bills like ~{human(tot_eff)}")
    if hit < 80:
        print("  ! below 80%: sessions are restarting too often, or context is being churned")

    exp = q(con, """
        SELECT session_id,
               SUM(input_tokens - cache_read_tokens), SUM(cache_read_tokens), COUNT(*)
        FROM assistant_usage_events
        WHERE substr(created_at,1,10) >= date('now', ?)
        GROUP BY session_id
        ORDER BY 2 DESC LIMIT 8
    """, (since,))
    if exp:
        print(f"\nMOST UNCACHED INPUT (the part that actually costs)\n")
        print(f"{'session':38} {'uncached':>9} {'cached':>9} {'calls':>6}")
        print("-" * 66)
        for sid, unc, cr, n in exp:
            print(f"{sid[:38]:38} {human(unc or 0):>9} {human(cr or 0):>9} {n:>6}")

    reads = q(con, """
        SELECT session_id, file_path, COUNT(*)
        FROM session_files
        WHERE substr(first_seen_at,1,10) >= date('now', ?)
        GROUP BY session_id, file_path
    """, (since,))
    if reads:
        total = sum(r[2] for r in reads)
        repeats = sum(r[2] - 1 for r in reads)
        pct = 100.0 * repeats / total if total else 0.0
        print(f"\nFILE TOUCHES (last {args.days} days) — {total} total, {repeats} repeats ({pct:.1f}%)")
        if pct > 25:
            print("  ! above 25%: re-reading files already in context (rules/context-discipline.md)")
        worst = sorted(reads, key=lambda r: -r[2])[:5]
        for sid, path, n in worst:
            if n > 2:
                print(f"    {n:>3}x  {Path(path).name}")

    tools = q(con, """
        SELECT command, COUNT(*) FROM forge_trajectory_events
        WHERE command IS NOT NULL AND command <> ''
          AND substr(created_at,1,10) >= date('now', ?)
        GROUP BY command ORDER BY 2 DESC LIMIT 12
    """, (since,))
    if tools:
        print(f"\nTOP TOOLS (last {args.days} days)\n")
        for cmd, n in tools:
            print(f"  {n:>5}  {str(cmd)[:60]}")

    con.close()
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
