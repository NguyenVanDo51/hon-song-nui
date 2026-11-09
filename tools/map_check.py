#!/usr/bin/env python3
"""1 vs 1 map check (skill duel-map-maker): content/skirmish_maps.gd -> per map: symmetry, terrain mix, castles,
walking turns home -> enemy home, contested castles. Exit 1 if any map breaks a hard rule.
usage: python3 tools/map_check.py [map_id ...]   (default: every map)
Move costs mirror scripts/core/rules.gd TERRAIN (foot class); a soldier walks MV = 4 per turn."""
import heapq
import re
import sys

COST = {".": 1, "r": 1, "=": 1, "v": 1, "c": 1, "x": 1, "t": 1, "f": 2, "h": 2, "m": 3, "~": 3}
MV = 4
# hard limits (docs/content.md "Bản đồ đấu tự do"; user 2026-11-09: easy to move, no castle in the middle)
MAX_WATER = 0.33
MAX_HOME_TURNS = 5.0  # foot turns, home castle -> enemy home castle
MIN_LEAD = 1.0  # a neutral castle must be >= 1 foot turn nearer one home than the other


def load(path="content/skirmish_maps.gd"):
    src = open(path, encoding="utf-8").read()
    maps = {}
    for m in re.finditer(r'"(\w+)": \{\s*"name": "([^"]*)"', src):
        mid, name = m.group(1), m.group(2)
        body = src[m.end():]
        rows = re.findall(r'"([.~fhmr=vcxt]+)",', body[: body.index('"owner"')])
        owner = re.findall(r'\[(\d+), (\d+), "(\w)"\]', body[: body.index('"units"')])
        maps[mid] = {"name": name, "rows": rows, "owner": {(int(x), int(y)): s for x, y, s in owner}}
    return maps


def walk(rows, start):
    h, w = len(rows), len(rows[0])
    d = {start: 0}
    q = [(0, start)]
    while q:
        c, (x, y) = heapq.heappop(q)
        if c > d[(x, y)]:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                nc = c + COST[rows[ny][nx]]
                if nc < d.get((nx, ny), 1e9):
                    d[(nx, ny)] = nc
                    heapq.heappush(q, (nc, (nx, ny)))
    return d


def check(mid, m):
    rows, owner = m["rows"], m["owner"]
    h, w = len(rows), len(rows[0])
    bad = []
    if any(len(r) != w for r in rows):
        bad.append("rows of unequal width")
    if not all(rows[y][x] == rows[h - 1 - y][w - 1 - x] for y in range(h) for x in range(w)):
        bad.append("not 180° symmetric")
    n = w * h
    share = {k: sum(r.count(k) for r in rows) / n for k in "~mfhr."}
    castles = [(x, y) for y in range(h) for x in range(w) if rows[y][x] == "c"]
    homes = {owner[c]: c for c in castles if c in owner}
    if set(homes) != {"p", "e"}:
        return [mid + ": needs one owned castle per side"]
    dp, de = walk(rows, homes["p"]), walk(rows, homes["e"])
    home_turns = dp[homes["e"]] / MV
    if share["~"] > MAX_WATER:
        bad.append("water %.0f%% > %.0f%%" % (share["~"] * 100, MAX_WATER * 100))
    if home_turns > MAX_HOME_TURNS:
        bad.append("home -> enemy home %.1f foot turns > %.1f" % (home_turns, MAX_HOME_TURNS))
    neutral = []
    for c in castles:
        if c in owner:
            continue
        tp, te = dp[c] / MV, de[c] / MV
        neutral.append("(%d,%d) p %.1f / e %.1f" % (c[0], c[1], tp, te))
        if c == (w - 1 - c[0], h - 1 - c[1]) or abs(tp - te) < MIN_LEAD:
            bad.append("contested castle (%d,%d): p %.1f / e %.1f turns — first mover takes it" % (c[0], c[1], tp, te))
    vil = sum(r.count("v") for r in rows)
    print(
        "%-10s %s  %dx%d  water %.0f%% mount %.0f%% forest %.0f%% hill %.0f%% road %.0f%%  castles %d  villages %d  "
        "home->home %.1f turns  neutral castles: %s"
        % (mid, m["name"], w, h, share["~"] * 100, share["m"] * 100, share["f"] * 100, share["h"] * 100,
           share["r"] * 100, len(castles), vil, home_turns, ", ".join(neutral) or "none")
    )
    return [mid + ": " + b for b in bad]


def main():
    maps = load()
    ids = sys.argv[1:] or list(maps)
    bad = []
    for mid in ids:
        bad += check(mid, maps[mid])
    for b in bad:
        print("FAIL " + b)
    print("map_check: %s" % ("ok" if not bad else "%d problem(s)" % len(bad)))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
