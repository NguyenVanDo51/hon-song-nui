# Maps: original AE2 (s0–s11, m0–m7) vs ours (skirmish_maps.gd, levels/*.gd)

## Summary (5 lines)
1. Format decoded from loader `i.class b(I)V`: `int w, int h`, w×h tile bytes **column-major**, `int N` + N×4 bytes **skipped** by loader, `int n` units × (byte faction·12+type, short x px, short y px; /24 = tile). Terrain via `tiles0.prop`; owner = (tile−37)/2 (0 = neutral). No gold / player count in map file.
2. 1v1 (ours 3 skirmish vs orig 5 two-player): villages/player 3.3 vs 4.2 = **ours ~21% fewer**, all from pre-owned villages (orig s0/s5 give 2 each; ours 0); neutral villages/player 3.3 vs 3.4 = match. Villages/100 tiles 4.3 vs 4.9 = ours ~12% fewer (with ruins 4.8 vs 5.0 ≈ match). `dong_bang` (2.6/100) < every orig 2p map (min 3.6).
3. Castles: **ours more** in 1v1: 4 vs 3.0 per map, 2.0 vs 1.5 /player, 2.6 vs 1.7 /100 tiles; villages/castle 1.7 vs 3.0. Ours always 2 neutral castles; orig 2p has 0–2.
4. Campaign: orig m0–m7 mostly low-economy (3 of 8 maps no castle at all; vill 2.2/100, castles 0.6/100); ours m/g levels denser (vill 3.7–3.9/100, castles 1.2–1.5/100). Campaign maps vs campaign maps where both sides own a castle: villages/100 4.2 vs 3.7 (ours more), castles/100 1.9 vs 0.9 (ours ~2×), villages/castle 2.4 vs 4.1 (ours fewer).
5. Biggest divergence = terrain mix + start setup: orig skirmish water 32–45%, mountain ~10%, grass ~8%, 0 temples; ours water 5–11%, mountain 3.5%, grass 36–48%, 2 temples per skirmish map. Orig skirmish start = 1 commander ON own castle only; ours = hero next to castle + 1 soldier. Orig smaller 2p maps 121–225 tiles vs ours fixed 154.

Tools (scratchpad, read-only on inputs): `ae2tools/jdis.py` (mini class disassembler), `ae2tools/i_dis.txt` (full i.class disasm), `ae2tools/maps.py` (parser -> `ae2tools/maps.json`), `ae2tools/maps_report.py` (tables -> `ae2tools/maps_tables.md`). All bytecode refs = `i.class <method> @pc N` in `i_dis.txt`.

## 1. Original map format (evidence)

| item | original | evidence |
|---|---|---|
| tile type table | `tiles0.prop`: u16 count=47, u16 (ignored), 47 bytes type per tile id (2 trailing bytes unused) | `i.class <init>()V @pc 372–429` (readShort, readShort+pop, loop readByte into `i.h:[B`) |
| tile ids -> type | 0–14 water(5), 15–16 forest(2), 17 mountain(4), 18 grass(1), 19 hill(3), 20–26 + 28 road(0), 27 ruined village(8), 29–30 bridge(6), 31/32/34 temple-like(7), 33/35/36 hill(3), 37/39/41/43/45 village(8), 38/40/42/44/46 castle(9) | `tiles0.prop` bytes 4..50; matches `docs/review/ae2_research.md` §3 |
| header | int w, int h (first = width: assumed; `i.k = i.o*24`; transposing changes no count) | `b(I)V @pc 216–231`, `@pc 605–624` |
| grid order | `for x<w: for y<h: g[x][y]=readByte` (column-major) | `b(I)V @pc 308–340` |
| buildings | tile ≥ 37 or ==27 -> building list (x, y, owner) | `b(I)V @pc 350–414` |
| owner | `(tile − 37) / 2` if tile ≥ 37 else −1 -> 0 neutral, 1..4 = faction; ruined (27) = −1 | `i.class a(II[[B)I @pc 0–26` (`i.j=37` set `<init> @pc 486`) |
| player count (skirmish) | number of distinct castle owners > 0 | `b(I)V @pc 417–486`; preview `a(Ld;ILjava/lang/String;B)V @pc 1840–1912`. Matches the (2)/(3)/(4) prefix of all 12 names |
| player count (campaign) | fixed 2; faction 1 -> player 0, faction 2 -> player 1 | `b(I)V @pc 663–735` |
| unknown block | `int N` (24/36/48), then N ints (all = 2 in all 20 maps), **skipped** (`skip(N*4)`) | `b(I)V @pc 813–830`; meaning unknown |
| units | `int n`; each: byte t (faction = 1 + t/12, type = t%12), short x, short y (pixels; /24 = tile) | `b(I)V @pc 831–977` |
| disabled slot | if player slot `i.l[p]==2` (inferred = slot off): its buildings -> neutral, its units not created | `b(I)V @pc 744–813`, `@pc 929–937` |
| map names | skirmish `s<k>` = lang[101+k]; campaign `m<n>` = lang[113+n] (lang.txt line = index+1) | `<init> @pc 533–563`; `b(I)V @pc 154–162` |
| file exactly consumed | parser ends at EOF for all 20 files | `maps.py` assert |

## 2. Main comparison table (1v1 / skirmish)

Orig 2p = s0 Icy Paths, s1 The Crossing, s5 Peak Island, s7 Liberty Port, s9 Morningstar (n=5). Ours = dong_bang, cua_bien, nui_rung (n=3). "villages" = living villages only; ruined listed separately. Values = mean [min–max].

| item | original 2p skirmish | ours skirmish | match? | evidence |
|---|---|---|---|---|
| map size (tiles) | 180 [121–225] (11×11 … 15×15) | 154 (all 14×11) | ours smaller than avg, inside range | header ints; `skirmish_maps.gd` rows |
| players | 2 (map files also have 3p ×1, 4p ×6) | 2 | match (we have no 3/4p maps) | castle-owner count |
| villages total | 8.4 [7–10] | 6.7 [4–8] | **ours fewer** (−20%) | per-map table §4 |
| villages / player | 4.2 [3.5–5.0] | 3.3 [2.0–4.0] | **ours fewer** (−21%) | |
| neutral villages / player | 3.4 [2.0–4.5] | 3.3 [2.0–4.0] | ≈ match | |
| own villages / player at start | 0.8 [0–2] (s0, s5: 2 each; others 0) | 0 | ours fewer | tile 39/41 in s0, s5 |
| ruined villages | 0.4 [0–2] | 0.7 [0–2] (dong_bang 2) | ≈ | tile 27 / `x` |
| villages / 100 tiles | 4.9 [3.6–6.6] | 4.3 [2.6–5.2] | **ours fewer** (−12%) | |
| (villages + ruined) / 100 tiles | 5.0 [4.4–6.6] | 4.8 [3.9–5.2] | ≈ match | |
| castles total | 3.0 [2–4] | 4 [4–4] | **ours more** (+33%) | |
| castles / player | 1.5 [1–2] | 2.0 | **ours more** | |
| neutral castles | 1.0 [0–2] (s0 2, s1 2, s7 1, s5/s9 0) | 2 on every map | ours more, and fixed | |
| castles / 100 tiles | 1.7 [0.9–2.5] | 2.6 | **ours more** (+53%); equals top orig (s1 2.5) | |
| villages / castle | 3.0 [1.8–4.0] | 1.7 [1.0–2.0] | **ours much lower** | |
| (villages+castles) / 100 tiles | 6.6 [4.4–8.3] | 6.9 [5.2–7.8] | ≈ match (ours shift villages -> castles) | |
| tiles / player | 90 [60–113] | 77 | ours denser | |
| start units | 1 commander per player, standing ON own castle (37/37 commanders in s0–s11) | hero ADJACENT to own castle + 1 soldier per side | **differs** | `b(I)V` unit block; `skirmish_maps.gd` units |
| start gold | not in map; menu {500, 1000, 2000} | 300 fixed (easy: AI 150) | differs (cross-aspect) | `<clinit> @pc 60–81` (`i.a:[S`), applied `@pc 1587–1599`; `content.gd:72` |
| unit cap | not in map; menu {10, 20, 25} | 15 | differs (cross-aspect) | `<clinit> @pc 84–102` (`i.c:[S`), `@pc 1602–1614` |
| temples / wells (type 7) | 0 in all 12 skirmish maps | 2 per map (`t`) | **ours add** | tile 31/32/34 count |
| grass % | 8.0 | 35.5 | **very different** | terrain table §3 |
| water % (incl. shore tiles 0–14) | 32.2 | 8.2 | **very different** | |
| mountain % | 10.3 | 3.5 | ours ~1/3 | |
| forest / hill % | 15.1 / 6.4 | 10.0 / 7.8 | forest lower | |
| road % | 19.7 | 24.7 | ours a bit more | |
| symmetry | 2p maps: point/mirror symmetric by eye (s0, s9 render below) | 180° rotation (by design, content.md) | ≈ | ASCII §5 |

Extremes: orig 2p villages/100 tiles min s5 Peak Island 3.6, max s9 Morningstar 6.6; ours min dong_bang 2.6 (4 villages + 2 ruined), max cua_bien/nui_rung 5.2. Orig 4p extremes for context: s10 The Crucible 0 living villages (12 ruined, 9 castles), s3 Crossroads 1.9/100.

## 3. Campaign comparison + terrain

| item | orig campaign m0–m7 (n=8) | orig m3/m5/m7 (both sides own a castle) | ours m01–m16 (n=16) | ours g01–g20 (n=20) | ours m+g, both sides own a castle (n=21) | match? |
|---|---|---|---|---|---|---|
| tiles | 221 [144–288] | 249 [240–256] | 141 [88–192] | 148 [108–192] | 153 [117–192] | **ours ~35% smaller** |
| villages | 4.9 [0–11] | 9.3 [7–11] | 5.2 [2–8] | 5.8 [4–9] | 6.3 [4–9] | ≈ total; fewer than economy missions |
| ruined villages | 1.9 [0–6] | 1.3 | 0.4 | 0.0 | 0.2 | ours fewer |
| castles | 1.4 [0–3] | 2.3 [2–3] | 1.8 [0–4] | 2.3 [1–6] | 2.9 [2–6] | ours more |
| maps with 0 castles | 3 of 8 (m0, m2, m4) | – | 2 of 16 (m01, m13) | 0 | – | |
| villages / 100 tiles | 2.2 [0–4.3] | 3.7 [2.9–4.3] | 3.7 [1.2–5.1] | 3.9 [3.3–5.1] | 4.2 [2.9–5.1] | **ours more** |
| castles / 100 tiles | 0.6 [0–1.2] | 0.9 [0.8–1.2] | 1.2 [0–2.3] | 1.5 [0.7–3.1] | 1.9 [1.2–3.1] | **ours ~2×** |
| villages / castle | 3.2 [1.0–5.5] | 4.1 [3.3–5.5] | 3.1 [1.0–6.0] | 3.3 [1.5–6.0] | 2.4 [1.5–3.5] | ours fewer in economy maps |
| villages / player (2 sides) | 2.4 [0–5.5] | 4.7 [3.5–5.5] | 2.6 [1.0–4.0] | 2.9 [2.0–4.5] | 3.2 [2.0–4.5] | ours fewer in economy maps |
| own villages / player at start | 1.6 [0–5.5] | 3.7 [2.0–5.5] | 0.7 | 0.8 | 0.9 | **ours far fewer pre-owned** |
| start gold p / e (mean) | 313 / 231 (per map: m0 0/0, m1 300/50, m2 0/0, m3 400/400, m4 0/0, m5 600/600, m6 400/600, m7 800/200) | – | 606 / 94 | 713 / 217 | – | ours: player ~2×, enemy less (cross-aspect) |
| start units | 1–19 per map, commanders + escorts; m1/m2 escorts start **off-map** (y ≥ h, march in; loader has no bounds check) | – | 3–14 | 6–11 | – | n/a |

Orig campaign gold evidence: `i.class r()V` (per-mission setup, branch on `i.s`): `@pc 92–105` (0/0), `@pc 201–216` (300/50), `@pc 363–386` (0/0), `@pc 560–576` (400/400), `@pc 734–746` (0/0), `@pc 987–1003` (600/600), `@pc 1094–1110` (400/600), `@pc 1296–1312` (800/200). Inferred: `i.f:[I` = gold per player (same array skirmish fills with menu gold at `b(I)V @pc 645–654`); mission index `i.s` == map m<n>. Load-time default before script: `b(I)V @pc 668–681` sets 0/0, cap `i.g=100` (`@pc 738–741`, inferred = unit cap).

Terrain mix, % of tiles (mean; "village" row = living + ruined, both sides; tile 27 is type 8 in `tiles0.prop`):

| terrain | orig skirm all (12) | orig skirm 2p (5) | orig skirm 4p (6) | orig campaign (8) | ours skirmish (3) | ours m (16) | ours g (20) |
|---|---|---|---|---|---|---|---|
| grass | 7.8 | 8.0 | 6.2 | 11.0 | 35.5 | 47.7 | 45.7 |
| road | 15.0 | 19.7 | 13.5 | 17.5 | 24.7 | 13.6 | 17.8 |
| forest | 12.4 | 15.1 | 10.7 | 21.0 | 10.0 | 10.3 | 12.4 |
| hill | 6.9 | 6.4 | 6.9 | 9.3 | 7.8 | 7.4 | 9.1 |
| mountain | 10.6 | 10.3 | 8.6 | 13.9 | 3.5 | 3.4 | 3.7 |
| water | 38.7 | 32.2 | 44.9 | 21.6 | 8.2 | 11.0 | 4.8 |
| bridge | 1.9 | 1.4 | 2.7 | 1.3 | 1.7 | 1.2 | 0.8 |
| temple/well | 0.0 | 0.0 | 0.0 | 0.8 | 1.3 | 0.2 | 0.3 |
| village (+ruined) | 4.7 | 5.0 | 4.4 | 2.9 | 4.8 | 4.0 | 3.9 |
| castle | 1.9 | 1.7 | 2.2 | 0.6 | 2.6 | 1.2 | 1.5 |

Note: orig water count includes shore/coast tiles 0–14 (all type 5 in `tiles0.prop`); tile art is a winter set (tile 18 "grass" = snow field, tile 17 = icy rock = mountain), checked visually on `tiles0_15/17/18.png`.

## 4. Per-map tables (every map)

### per-map original

| map | name | size | tiles | players | villages (start owner:count, 0 = neutral) | ruined vill. | castles (owner:count) | vill/castle | vill/100 tiles | castles/100 tiles | vill/player | neutral vill/player | start units |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| s0 | (2)Icy Paths | 15x15 | 225 | 2 | 10 (0:6 1:2 2:2) | 0 | 4 (0:2 1:1 2:1) | 2.5 | 4.4 | 1.8 | 5.0 | 3.0 | f1:1 f2:1 |
| s1 | (2)The Crossing | 16x10 | 160 | 2 | 7 (0:7) | 0 | 4 (0:2 1:1 2:1) | 1.8 | 4.4 | 2.5 | 3.5 | 3.5 | f1:1 f2:1 |
| s2 | (3)Frozen fields | 15x12 | 180 | 3 | 6 (0:6) | 3 | 3 (1:1 2:1 3:1) | 2.0 | 3.3 | 1.7 | 2.0 | 2.0 | f1:1 f2:1 f3:1 |
| s3 | (4)Crossroads | 11x19 | 209 | 4 | 4 (1:1 2:1 3:1 4:1) | 4 | 4 (1:1 2:1 3:1 4:1) | 1.0 | 1.9 | 1.9 | 1.0 | 0.0 | f1:1 f2:1 f3:1 f4:1 |
| s4 | (4)Solitude | 15x15 | 225 | 4 | 9 (0:9) | 0 | 4 (1:1 2:1 3:1 4:1) | 2.2 | 4.0 | 1.8 | 2.2 | 2.2 | f1:1 f2:1 f3:1 f4:1 |
| s5 | (2)Peak Island | 15x15 | 225 | 2 | 8 (0:4 1:2 2:2) | 2 | 2 (1:1 2:1) | 4.0 | 3.6 | 0.9 | 4.0 | 2.0 | f1:1 f2:1 |
| s6 | (4)Waterways | 15x15 | 225 | 4 | 8 (0:8) | 2 | 4 (1:1 2:1 3:1 4:1) | 2.0 | 3.6 | 1.8 | 2.0 | 2.0 | f1:1 f2:1 f3:1 f4:1 |
| s7 | (2)Liberty Port | 13x13 | 169 | 2 | 9 (0:9) | 0 | 3 (0:1 1:1 2:1) | 3.0 | 5.3 | 1.8 | 4.5 | 4.5 | f1:1 f2:1 |
| s8 | (4)Winterstorm | 13x13 | 169 | 4 | 4 (0:4) | 8 | 4 (1:1 2:1 3:1 4:1) | 1.0 | 2.4 | 2.4 | 1.0 | 1.0 | f1:1 f2:1 f3:1 f4:1 |
| s9 | (2)Morningstar | 11x11 | 121 | 2 | 8 (0:8) | 0 | 2 (1:1 2:1) | 4.0 | 6.6 | 1.7 | 4.0 | 4.0 | f1:1 f2:1 |
| s10 | (4)The Crucible | 19x19 | 361 | 4 | 0 (-) | 12 | 9 (0:5 1:1 2:1 3:1 4:1) | 0.0 | 0.0 | 2.5 | 0.0 | 0.0 | f1:1 f2:1 f3:1 f4:1 |
| s11 | (4)Shadowlands | 19x19 | 361 | 4 | 12 (0:12) | 2 | 10 (0:6 1:1 2:1 3:1 4:1) | 1.2 | 3.3 | 2.8 | 3.0 | 3.0 | f1:1 f2:1 f3:1 f4:1 |
| m0 | The Temple of Courage | 12x12 | 144 | 2 | 4 (1:2 2:2) | 0 | 0 (-) | - | 2.8 | 0.0 | 2.0 | 0.0 | f1:4 f2:2 |
| m1 | The Temple of Wisdom | 15x12 | 180 | 2 | 5 (0:5) | 2 | 2 (0:1 2:1) | 2.5 | 2.8 | 1.1 | 2.5 | 2.5 | f1:3 f2:2 |
| m2 | Forest of Mists | 10x17 | 170 | 2 | 0 (-) | 0 | 0 (-) | - | 0.0 | 0.0 | 0.0 | 0.0 | f1:4 f2:2 |
| m3 | The Temple of Life | 16x16 | 256 | 2 | 11 (1:6 2:5) | 0 | 2 (1:1 2:1) | 5.5 | 4.3 | 0.8 | 5.5 | 0.0 | f1:3 f2:7 |
| m4 | Pathway to Thorin | 20x12 | 240 | 2 | 0 (-) | 3 | 0 (-) | - | 0.0 | 0.0 | 0.0 | 0.0 | f1:6 |
| m5 | The Gates of Thorin | 12x20 | 240 | 2 | 7 (0:3 1:2 2:2) | 2 | 2 (1:1 2:1) | 3.5 | 2.9 | 0.8 | 3.5 | 1.5 | f1:6 f2:7 |
| m6 | Outside the City | 16x18 | 288 | 2 | 2 (0:2) | 6 | 2 (0:2) | 1.0 | 0.7 | 0.7 | 1.0 | 1.0 | f1:1 |
| m7 | The Ancient Citadel | 14x18 | 252 | 2 | 10 (0:3 1:2 2:5) | 2 | 3 (1:1 2:2) | 3.3 | 4.0 | 1.2 | 5.0 | 1.5 | f1:11 f2:8 |

### per-map ours

| map | title | size | tiles | sides | villages (start owner:count, n = neutral) | ruined (x) | castles (owner:count) | vill/castle | vill/100 tiles | castles/100 tiles | vill/player | neutral vill/player | win | units p/e |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dong_bang | dong_bang | 14x11 | 154 | 2 | 4 (n:4) | 2 | 4 (e:1 n:2 p:1) | 1.0 | 2.6 | 2.6 | 2.0 | 2.0 | castles | 2/2 |
| cua_bien | cua_bien | 14x11 | 154 | 2 | 8 (n:8) | 0 | 4 (e:1 n:2 p:1) | 2.0 | 5.2 | 2.6 | 4.0 | 4.0 | castles | 2/2 |
| nui_rung | nui_rung | 14x11 | 154 | 2 | 8 (n:8) | 0 | 4 (e:1 n:2 p:1) | 2.0 | 5.2 | 2.6 | 4.0 | 4.0 | castles | 2/2 |
| g01 | Bến Đò | 13x9 | 117 | 2 | 6 (e:1 n:4 p:1) | 0 | 2 (e:1 p:1) | 3.0 | 5.1 | 1.7 | 3.0 | 2.0 | castles | 3/4 |
| g02 | Đồi Sim | 14x10 | 140 | 2 | 5 (n:4 p:1) | 0 | 1 (p:1) | 5.0 | 3.6 | 0.7 | 2.5 | 2.0 | rout | 3/7 |
| g03 | Ngã Ba Sông | 15x10 | 150 | 2 | 6 (e:1 n:4 p:1) | 0 | 4 (e:2 p:2) | 1.5 | 4.0 | 2.7 | 3.0 | 2.0 | castles | 3/3 |
| g04 | Giữ Đồn | 14x10 | 140 | 2 | 5 (n:4 p:1) | 0 | 1 (p:1) | 5.0 | 3.6 | 0.7 | 2.5 | 2.0 | survive | 4/2 |
| g05 | Rừng Lim | 15x11 | 165 | 2 | 6 (e:1 n:4 p:1) | 0 | 2 (e:1 p:1) | 3.0 | 3.6 | 1.2 | 3.0 | 2.0 | hero | 4/5 |
| g06 | Bãi Bồi | 15x10 | 150 | 2 | 6 (n:5 p:1) | 0 | 1 (p:1) | 6.0 | 4.0 | 0.7 | 3.0 | 2.5 | rout | 3/8 |
| g07 | Cửa Sông | 15x10 | 150 | 2 | 6 (e:1 n:4 p:1) | 0 | 2 (e:1 p:1) | 3.0 | 4.0 | 1.3 | 3.0 | 2.0 | hero | 4/5 |
| g08 | Sông Đáy | 15x11 | 165 | 2 | 6 (e:1 n:4 p:1) | 0 | 4 (e:2 p:2) | 1.5 | 3.6 | 2.4 | 3.0 | 2.0 | castles | 4/4 |
| g09 | Làng Ven Đê | 13x9 | 117 | 2 | 6 (e:1 n:4 p:1) | 0 | 2 (e:1 p:1) | 3.0 | 5.1 | 1.7 | 3.0 | 2.0 | hero | 4/5 |
| g10 | Rừng Đêm | 14x10 | 140 | 2 | 5 (n:4 p:1) | 0 | 1 (p:1) | 5.0 | 3.6 | 0.7 | 2.5 | 2.0 | rout | 4/6 |
| g11 | Thành Đá | 15x11 | 165 | 2 | 6 (e:1 n:4 p:1) | 0 | 4 (e:2 p:2) | 1.5 | 3.6 | 2.4 | 3.0 | 2.0 | castles | 4/4 |
| g12 | Bãi Lau | 12x9 | 108 | 2 | 4 (n:3 p:1) | 0 | 1 (p:1) | 4.0 | 3.7 | 0.9 | 2.0 | 1.5 | rout | 4/4 |
| g13 | Miếu Cổ | 14x10 | 140 | 2 | 6 (e:1 n:4 p:1) | 0 | 2 (e:1 p:1) | 3.0 | 4.3 | 1.4 | 3.0 | 2.0 | castles | 4/5 |
| g14 | Đầm Lầy | 13x9 | 117 | 2 | 4 (n:3 p:1) | 0 | 1 (p:1) | 4.0 | 3.4 | 0.9 | 2.0 | 1.5 | survive | 5/2 |
| g15 | Thành Mới | 16x11 | 176 | 2 | 8 (e:1 n:6 p:1) | 0 | 4 (e:2 p:2) | 2.0 | 4.5 | 2.3 | 4.0 | 3.0 | castles | 4/5 |
| g16 | Núi Rồng | 15x11 | 165 | 2 | 6 (e:1 n:4 p:1) | 0 | 2 (e:1 p:1) | 3.0 | 3.6 | 1.2 | 3.0 | 2.0 | hero | 4/4 |
| g17 | Lũy Tre | 15x11 | 165 | 2 | 6 (e:1 n:4 p:1) | 0 | 4 (e:2 p:2) | 1.5 | 3.6 | 2.4 | 3.0 | 2.0 | castles | 4/4 |
| g18 | Trăng Khuyết | 14x10 | 140 | 2 | 5 (n:4 p:1) | 0 | 1 (p:1) | 5.0 | 3.6 | 0.7 | 2.5 | 2.0 | rout | 5/7 |
| g19 | Giữ Thành | 15x10 | 150 | 2 | 5 (n:4 p:1) | 0 | 1 (p:1) | 5.0 | 3.3 | 0.7 | 2.5 | 2.0 | survive | 4/3 |
| g20 | Trận Cuối | 16x12 | 192 | 2 | 9 (e:1 n:7 p:1) | 0 | 6 (e:3 p:3) | 1.5 | 4.7 | 3.1 | 4.5 | 3.5 | castles | 5/6 |
| m01 | Lời Thề Hát Môn | 11x8 | 88 | 2 | 4 (n:4) | 0 | 0 (-) | - | 4.5 | 0.0 | 2.0 | 2.0 | rout | 3/4 |
| m02 | Về Lại Mê Linh | 13x9 | 117 | 2 | 6 (n:5 p:1) | 0 | 2 (e:1 p:1) | 3.0 | 5.1 | 1.7 | 3.0 | 2.5 | castles | 3/3 |
| m03 | Giữ Làng Hạ Lôi | 12x9 | 108 | 2 | 5 (n:3 p:2) | 0 | 1 (p:1) | 5.0 | 4.6 | 0.9 | 2.5 | 1.5 | survive | 4/0 |
| m04 | Phá Đồn Cổ Loa | 14x10 | 140 | 2 | 7 (e:1 n:6) | 0 | 2 (e:1 p:1) | 3.5 | 5.0 | 1.4 | 3.5 | 3.0 | hero | 5/5 |
| m05 | Đêm Hồ Tây | 14x10 | 140 | 2 | 6 (e:1 n:5) | 0 | 2 (e:1 p:1) | 3.0 | 4.3 | 1.4 | 3.0 | 2.5 | castles | 4/5 |
| m06 | Trận Bãi Sông | 14x10 | 140 | 2 | 7 (n:7) | 0 | 2 (e:1 p:1) | 3.5 | 5.0 | 1.4 | 3.5 | 3.5 | hero | 4/6 |
| m07 | Vây Thành Long Biên | 15x10 | 150 | 2 | 7 (e:1 n:6) | 0 | 3 (e:2 p:1) | 2.3 | 4.7 | 2.0 | 3.5 | 3.0 | castles | 5/6 |
| m08 | Trị Sở Luy Lâu | 16x12 | 192 | 2 | 8 (n:8) | 0 | 4 (e:2 n:1 p:1) | 2.0 | 4.2 | 2.1 | 4.0 | 4.0 | castles | 5/7 |
| m09 | Tin Dữ Hợp Phố | 14x10 | 140 | 2 | 6 (n:3 p:3) | 0 | 1 (p:1) | 6.0 | 4.3 | 0.7 | 3.0 | 1.5 | survive | 4/0 |
| m10 | Sóng An Biên | 15x10 | 150 | 2 | 5 (e:1 n:3 p:1) | 2 | 2 (e:1 p:1) | 2.5 | 3.3 | 1.3 | 2.5 | 1.5 | hero | 5/5 |
| m11 | Bát Nàn Giữ Ải | 14x10 | 140 | 2 | 4 (e:1 n:2 p:1) | 1 | 2 (e:1 p:1) | 2.0 | 2.9 | 1.4 | 2.0 | 1.0 | castles | 5/5 |
| m12 | Trận Lãng Bạc | 16x11 | 176 | 2 | 6 (e:2 n:2 p:2) | 2 | 4 (e:2 n:1 p:1) | 1.5 | 3.4 | 2.3 | 3.0 | 1.0 | castles | 6/8 |
| m13 | Địu Con Phá Vây | 14x10 | 140 | 2 | 2 (n:1 p:1) | 0 | 0 (-) | - | 1.4 | 0.0 | 1.0 | 0.5 | reach | 6/6 |
| m14 | Rút Về Cấm Khê | 16x10 | 160 | 2 | 2 (n:2) | 1 | 2 (p:2) | 1.0 | 1.2 | 1.2 | 1.0 | 1.0 | reach | 4/8 |
| m15 | Thành Cấm Khê | 14x10 | 140 | 2 | 3 (p:3) | 0 | 1 (p:1) | 3.0 | 2.1 | 0.7 | 1.5 | 0.0 | survive | 5/0 |
| m16 | Đêm Sông Hát | 14x10 | 140 | 2 | 5 (n:3 p:2) | 1 | 1 (p:1) | 5.0 | 3.6 | 0.7 | 2.5 | 1.5 | survive | 5/0 |
| t01 | Bài Học Đầu | 9x7 | 63 | 2 | 1 (n:1) | 0 | 0 (-) | - | 1.6 | 0.0 | 0.5 | 0.5 | rout | 1/2 |
| t02 | Chiêu Binh | 9x7 | 63 | 2 | 1 (p:1) | 0 | 2 (e:1 p:1) | 0.5 | 1.6 | 3.2 | 0.5 | 0.0 | castles | 2/0 |

Notes: orig "start units" = count per faction (f1 = faction 1 = player in campaign). Orig "vill/player" uses players from castle owners (skirmish) / 2 (campaign). Unit type 9 = commander (King Galamar/Valadorn, Saeth, …): m7 has 5 commanders (2 for f1, 3 for f2). m1/m2: some f1 units start at y ≥ map height (off-map column). Ours "sides" = 2 always (engine is p vs e); m03/m09/m15/m16 have no enemy at start (waves). Ours: "n" = neutral.

Full average table (all groups, incl. 4p and "all levels"): `ae2tools/maps_tables.md` section "averages".

## 5. ASCII view (2 original skirmish maps)

Legend: `.` grass/snow, `r` road, `f` forest, `h` hill, `m` mountain, `~` water (incl. shore), `=` bridge, `t` temple/well, `x` ruined village, `v ` neutral village, `v1`/`v2` village of faction 1/2, `C ` neutral castle, `C1` castle of faction 1, `K1`/`K2` commander of faction 1/2 standing on its own castle (castle hidden). x = column, y = row (orientation assumed, see §1).

s0 (2)Icy Paths, 15×15: 10 villages (6 neutral + 2 each pre-owned), 4 castles (2 neutral), 0 ruined.
```
m . r h ~ ~ ~ f h m f ~ ~ ~ ~
f K2r v2~ ~ f . v f f m ~ ~ ~
r r r r = = r r . h m f m h f
m v2r f ~ ~ m r m f f . f . h
~ ~ = ~ ~ ~ ~ r . f m h . C m
~ ~ = ~ ~ ~ ~ r f r r r r r .
f h . f m ~ ~ r v r . v . f f
f . f h . r r r r r h f f f m
h . . v m r v r ~ ~ . f m ~ f
f r r r r r . r ~ ~ ~ ~ = ~ ~
f C m . h f f r ~ ~ ~ ~ = ~ ~
m h . f m f m r m ~ ~ f r v1m
f m h m h m . r r = = r r r r
~ ~ ~ f f h v . f ~ ~ v1r K1f
~ ~ ~ ~ f f . f ~ ~ ~ h r . m
```

s9 (2)Morningstar, 11×11: 8 neutral villages, 2 castles, nothing pre-owned; highest village density of all originals (6.6 / 100 tiles).
```
~ ~ ~ ~ ~ v m f m h v
~ ~ ~ ~ ~ f r r r r .
v r = = r r r m K2r f
. r ~ ~ ~ ~ m f h r m
f r ~ ~ ~ ~ ~ m f r ~
~ r v ~ ~ ~ ~ ~ v r ~
~ r f m ~ ~ ~ ~ ~ r f
m r h f m ~ ~ ~ ~ r .
f r K1m r r r = = r v
. r r r r f ~ ~ ~ ~ ~
v h m f m v ~ ~ ~ ~ ~
```

Ours for contrast, dong_bang 14×11 (rows as in `skirmish_maps.gd`; c at (1,9) = p, (12,1) = e, 2 neutral c): 4 villages, 2 ruined, 4 castles.
```
......hf......
....ffmh....c.
..c.hfhf...rv.
..r.hmrxrrrrrh
..rrhfrrrrrvrf
.~~=~~tt~~=~~.
frvrrrrrfhrr..
hrrrrrxrmh.r..
.vr...fhfh.c..
.c....hmff....
......fh......
```

## 6. Verdict
- Per player (1v1): ours **fewer villages** (3.3 vs 4.2; gap = orig pre-owned villages), **more castles** (2.0 vs 1.5). Neutral villages per player = original.
- Per area (1v1): villages slightly fewer (4.3 vs 4.9 / 100 tiles; ≈ equal counting ruins), castles much more (2.6 vs 1.7 / 100 tiles).
- Campaign: ours denser in both villages and castles per area than orig m0–m7 (orig campaign is sparse: 3 maps without castles, many ruins, temples), but fewer villages per castle and far fewer pre-owned villages than orig economy missions (m3/m5/m7).
- Not original-like: terrain mix (ours mostly open grass, little water/mountain), temples in skirmish, 2 neutral castles on every 1v1 map, hero+soldier start beside castle.
- Unverified / inferred: meaning of the skipped N-int block; `i.l[p]==2` = disabled slot; `i.f:[I` = gold and `i.g` = unit cap (from fill order); mission index `i.s` == map index; width-vs-height orientation (no count depends on it).

Cross-aspect: start gold (orig menu 500/1000/2000 vs our 300) and unit cap (orig 10/20/25 vs our 15) belong to the economy aspect; campaign per-mission gold listed in §3 for them.
