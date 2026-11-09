#!/usr/bin/env python3
"""Coverage table from instrument.py's map + the hit bytes, run by tools/coverage.sh.
usage: report.py <cov_map.json> <hits_file> [missed_substr]   (missed_substr: list uncovered lines of matching files)
"""

import json
import os
import sys
from collections import defaultdict

mapping = json.load(open(sys.argv[1]))
hits = open(sys.argv[2], "rb").read() if os.path.exists(sys.argv[2]) else b""
if not hits:
    sys.exit("coverage: no hits written (runner crashed before exit?)")
tot = defaultdict(int)
hit = defaultdict(int)
missed = defaultdict(list)
for i, (rel, ln) in enumerate(mapping):
    tot[rel] += 1
    if i < len(hits) and hits[i]:
        hit[rel] += 1
    else:
        missed[rel].append(ln)
for rel in sorted(tot, key=lambda r: (hit[r] / tot[r], r)):
    print("%6.1f%%  %5d/%5d  %s" % (100.0 * hit[rel] / tot[rel], hit[rel], tot[rel], rel))
T = sum(tot.values())
H = sum(hit.values())
print("%6.1f%%  %5d/%5d  TOTAL" % (100.0 * H / T, H, T))
if len(sys.argv) > 3:
    for rel in sorted(missed):
        if sys.argv[3] in rel and missed[rel]:
            print("missed %s: %s" % (rel, " ".join(map(str, missed[rel]))))
