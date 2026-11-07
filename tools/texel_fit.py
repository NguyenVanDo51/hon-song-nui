#!/usr/bin/env python3
"""Texel-style fit: logistic regression of final result (side to move) on eval features. Pure python (no numpy).
usage: texel_fit.py <csv>... [--feats a,b,c] [--minturn N]"""
import csv, math, sys, random

args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--"))
rows = []
for p in args:
    with open(p) as f:
        rows += list(csv.DictReader(f))
minturn = int(opts.get("minturn", "0"))
rows = [r for r in rows if int(r["turn"]) >= minturn]
CUR = {"val": 1, "dmg_cap": -1, "gold": 1, "inc": 4, "castles": 300, "adv": -4, "adv_hero": -12}


def cur_eval(r):
    return sum(w * float(r[k]) for k, w in CUR.items())


def solve(A, b):
    n = len(b)
    M = [A[i][:] + [b[i]] for i in range(n)]
    for c in range(n):
        piv = max(range(c, n), key=lambda i: abs(M[i][c]))
        M[c], M[piv] = M[piv], M[c]
        for i in range(n):
            if i != c and M[c][c] != 0:
                f = M[i][c] / M[c][c]
                for j in range(c, n + 1):
                    M[i][j] -= f * M[c][j]
    return [M[i][n] / M[i][i] if M[i][i] else 0.0 for i in range(n)]


def fit(X, y, l2=1e-3, it=25):
    d = len(X[0])
    w = [0.0] * d
    for _ in range(it):
        g = [0.0] * d
        H = [[0.0] * d for _ in range(d)]
        for x, t in zip(X, y):
            z = sum(a * b for a, b in zip(w, x))
            p = 1 / (1 + math.exp(-max(-30, min(30, z))))
            e = p - t
            s = p * (1 - p)
            for i in range(d):
                g[i] += e * x[i]
                xi = s * x[i]
                for j in range(i, d):
                    H[i][j] += xi * x[j]
        for i in range(d):
            g[i] += l2 * w[i] * len(X)
            H[i][i] += l2 * len(X)
            for j in range(i):
                H[i][j] = H[j][i]
        step = solve(H, g)
        w = [a - b for a, b in zip(w, step)]
    return w


def logloss(X, y, w):
    L = 0.0
    for x, t in zip(X, y):
        z = sum(a * b for a, b in zip(w, x))
        p = 1 / (1 + math.exp(-max(-30, min(30, z))))
        p = min(max(p, 1e-9), 1 - 1e-9)
        L -= t * math.log(p) + (1 - t) * math.log(1 - p)
    return L / len(X)


cells = sorted({(r["map"], r["seat_p"]) for r in rows})
feats = opts.get("feats", "val,dmg_cap,gold,inc,castles,adv,adv_hero,hero,risk_me,risk_foe").split(",")
mu = {k: sum(float(r[k]) for r in rows) / len(rows) for k in set(feats) | {"risk_me", "risk_foe"}}
sd = {k: (sum((float(r[k]) - mu[k]) ** 2 for r in rows) / len(rows)) ** 0.5 or 1.0 for k in mu}
ce = [cur_eval(r) for r in rows]
cmu = sum(ce) / len(ce)
csd = (sum((c - cmu) ** 2 for c in ce) / len(ce)) ** 0.5


def design(r, fs, cur=False):
    x = [1.0 if (r["map"], r["seat_p"]) == c else 0.0 for c in cells]
    if cur:
        x.append((cur_eval(r) - cmu) / csd)
    for k in fs:
        x.append((float(r[k]) - mu[k]) / sd[k])
    return x


games = sorted({r["game"] for r in rows})
random.Random(1).shuffle(games)
test_g = set(games[: len(games) // 3])
tr = [r for r in rows if r["game"] not in test_g]
te = [r for r in rows if r["game"] in test_g]
y = lambda rs: [float(r["result"]) for r in rs]
print("rows %d (train %d / test %d), games %d, cells %d" % (len(rows), len(tr), len(te), len(games), len(cells)))
for name, fs, cur in [("cells only", [], False), ("current eval", [], True), ("cur + risk", ["risk_me", "risk_foe"], True), ("free fit", feats, False)]:
    w = fit([design(r, fs, cur) for r in tr], y(tr))
    print("%-14s test logloss %.4f  train %.4f" % (name, logloss([design(r, fs, cur) for r in te], y(te), w), logloss([design(r, fs, cur) for r in tr], y(tr), w)))
w = fit([design(r, feats) for r in rows], y(rows))
wf = w[len(cells):]
raw = {k: wf[i] / sd[k] for i, k in enumerate(feats)}
print("free fit on all rows: logit per unit, and relative to val (eval weight)")
for k in feats:
    print("  %-9s %+.6f  rel %+.3f   (current %s)" % (k, raw[k], raw[k] / raw["val"], CUR.get(k, 0)))
