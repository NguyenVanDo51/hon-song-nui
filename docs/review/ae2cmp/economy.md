# AE2 original vs ours: economy

## Summary
1. Core rules match the original exactly: village +30 / castle +50 per turn, paid at the start of the owner's own turn (first mover gets nothing before its turn 1). Heal = min(20, 100-hp) at turn start on own building or temple (any side). Cap counts all living units except Skeletons. Commander rebuy 200 -> +200 per death -> 1000 cap.
2. Capture, repair and raze match: capture/repair are free and end the move. Repair turns ruin -> neutral village. Catapult razes only villages (never castles): enemy or neutral, empty tile, in range. No gold from kills, captures or razing, and campaign scripts never add gold.
3. **Skirmish settings differ.** Original Money = {500, 1000, 2000}, default **500**; Unit Cap = {10, 20, 25}, default **10**. Ours gold = {300, 500, 1000, 2000}, default **300**; cap = {10, 15, 20, 30}, default **15**. "Easy = enemy half gold" exists only in ours; the original gives every side the same gold.
4. Skirmish maps store no gold; gold comes only from the setting. Original 2p maps start each side with a King only and 1 castle (50/turn), or 2 villages + 1 castle (110/turn) on s0 / s5. Ours: hero + soldier + 1 castle (50/turn). At defaults ours has ~200 less gold every turn (300 vs 500 start, same income).
5. Campaign: original start gold per map is hard-coded (m0..m7 = 0/0, 300/50, 0/0, 400/400, 0/0, 600/600, 400/600, 800/200 for player/enemy) and cap = 100 always. Ours m* 0..1200 (own content, not ports) and cap 100 (match). g* levels use cap 15 (ours only).

Method: own disassembler `ae2tools/econ_dis.py` (javap = macOS stub, no JDK) -> `ae2cmp/econ_work/*.dis`; map parser `ae2tools/econ_maps.py`. Citations = `class method @pc N`. Lang indices in the code = lang.txt line after "en" + 1 (`bipush 39` = "2 players and 2 teams minimum…", so Money = 40, Unit Cap = 41).

## Table

| item | original | ours | match | evidence (original) |
|---|---|---|---|---|
| village income | +30 / turn | `TERRAIN.v.income` 30 | ✓ | `i.o()V @pc 241–263`: terrain type 8 -> `ar += 30` |
| castle income | +50 / turn | `TERRAIN.c.income` 50 | ✓ | `i.o()V @pc 266–285`: type 9 -> `ar += 50` |
| who gets income | tiles whose owner color = current side's color (`i.j[side]`); neutral (owner 0) and ruins (tile 27 < 37 -> owner -1) pay nothing | `income()` over `s.owner == side`; ruin `x` has no income | ✓ | `i.b(III)Z`, `i.a(II[[B)I` (tile ≥ `i.j`=37 -> (tile-37)/2, else -1) |
| when paid | start of the new side's turn: `o()V` switches `i.f` = side, then pays `gold[side] += ar` | `end_turn` switches side, then `gold[side] += income` | ✓ | `i.o()V @pc 43–55` (switch), `@pc 199–315` (sum + pay); `o()` runs only after END TURN (`n()V` sets state 8 -> `c()V @pc 854–929`) |
| first mover, turn 1 | no income before its turn 1 (game start never calls `o()`); 2nd side gets income at its turn 1 | p: no income turn 1; e: income at its turn 1 | ✓ | `i.b(I)V` (map load) has no `o()` call; skirmish start sets state 0 (`menu a(Ld;ILjava/lang/String;B)V @pc 1663–1681`) |
| income shown | "INCOME: %U" popup; CPU side shows "?" | `income` event | ✓ (UI) | `c()V @pc 932–998` (lang 75/76) |
| skirmish start gold | setting `i.a:[S` = {500, 1000, 2000}, default index 0 = **500**, same for every side | `skirmish_def` gold=300; menu {300, 500, 1000, 2000}, default **300** | ✗ | `i.<clinit> @pc 60–81`; applied `menu @pc 1587–1599` (`i.f:I = i.a[k.i]`), copied to all sides `i.b(I)V @pc 627–660`. Default: the selector `new d(14,4)` (`menu @pc 1058–1069`) never sets `d.i` -> 0 |
| skirmish unit cap | setting `i.c:[S` = {10, 20, 25}, default **10** | default **15**; menu {10, 15, 20, 30} | ✗ | `i.<clinit> @pc 84–102`; `menu @pc 1602–1614` (`i.g:I = i.c[l.i]`) |
| easy mode (enemy half gold) | none: every side gets the same `i.f:I`; no difficulty string in lang.txt | `easy` -> enemy gold/2 | ✗ (ours only) | `i.b(I)V @pc 635–660` |
| gold stored in map files | no. s*/m* = w, h, tiles, n×4 bytes skipped, units (type, x, y) | n/a (maps in .gd) | — | `i.b(I)V @pc 216–977`; parsed s0–s11, m0–m7: 0 trailing bytes |
| campaign start gold (player / enemy) | m0 0/0, m1 300/50, m2 0/0, m3 400/400, m4 0/0, m5 600/600, m6 400/600, m7 800/200 | m01–m16: p 0–1200, e 0–300; t01/t02 0 / 150; g01–g20 p 150–1500, e 0–750 | — (own content, not ports) | `i.r()V @pc 87–105` (m0), `195–216` (m1), `357–386` (m2), `549–576` (m3), `728–746` (m4), `980–1003` (m5), `1083–1110` (m6), `1285–1312` (m7) |
| campaign unit cap | 100 (always) | `RULES.unitCap` 100 (m*, t*); g* = 15 | ✓ m* / ✗ g* | `i.b(I)V @pc 738–741` (`i.g = 100` in the campaign branch). The `rules.gd:141` comment cites RM; this is original evidence |
| cap rule | can buy while `cap > (non-grave units of side) − (Skeletons of side)`; dead King is in grave state -> not counted | `full = cap_count >= unitCap`; ghost `noCap`; dead hero removed | ✓ | `i.a(BII)Z @pc 0–26`, `i.a(Lc;II)Z @pc 0–26`; counter `i.a(IIB)I` (state -1 = all but state 3); King death `c()V @pc 2806–2891` sets state 3 |
| Skeletons count toward cap | no | no (`ghost.noCap`) | ✓ | same: `− a(10, -1, side)` |
| heal amount | `min(20, 100 − hp)` | `mini(RULES.heal=20, 100−hp)` | ✓ | `c()V @pc 1140–1179` |
| heal when | start of own turn, right after income | same (`end_turn`) | ✓ | `c()V` state 8: `@pc 929` (o + income) then `@pc 1047–1249` (heal loop over the new side's units) |
| heal where | terrain type 7 (temple / well / tile 34) for any side; village / castle owned by the unit's **team**; neutral or ruin: no | `t` heals any; `v`/`c` owner only; `x` none | ✓ (2 sides: team = owner) | `c()V @pc 1094–1137` (`a(II)B == 7` OR `a(III)Z(x,y,i.k[side])`) |
| commander rebuy cost | starts at King unit cost 200; each death `if cost < 1000: cost += 200` -> 200, 400, …, 1000 | `min(1000, 200 + 200×deaths)` | ✓ | `c.a(BBIIZ)Lc; @pc 52–57` (`c.k = c.a[type]`); `i.c()V @pc 2894–2931` |
| rebuy rule | pays `c.k`, hp = 100, same object (keeps rank / xp); same cap + gold + free-tile checks | `heroSaved` restored; same checks | ✓ | `i.a(Lc;II)Lc; @pc 0–53`; `i.a(Lc;II)Z` |
| capture | flag 8 (Soldier, King) on a village with tile ≥ 37 not owned by own team; flag 16 (King) on a castle not owned by own team. Free, instant, ends the move | `capV` / `capC`, not own; act ends | ✓ | `i.b(IILc;)Z`; action `menu @pc 5991–6108` (`b(III)V` sets owner, `c.d()` = finish move), lang 67 OCCUPY / 73 OCCUPIED! |
| repair | flag 8 standing on a ruin (type 8, tile < 37 = 27) -> tile 37 = neutral village. Free, ends the move; needs another turn to occupy | `x.repairTo v`, `repairBy capV`, unowned | ✓ | `i.a(IILc;)Z`; `menu @pc 5914–5990` (`a(BII)V` writes `i.j`=37), lang 68 REPAIR / 74 REPAIRED! |
| raze | Catapult only (type 7); target = village type 8, tile ≥ 37 (not already ruined), **not castles**, owner not own team (enemy or neutral), tile has no unit, distance in the Catapult's attack range. Result tile 27 (ruin); ends the move; no gold | `raze` flag; only `v` has `razeTo`; enemy/unowned, empty, in range | ✓ | `c.a(IIIIB)[Lc; @pc 196–295` (pseudo-target state 4); `i.a(Lc;Lc;)V @pc 0–51`; `c()V @pc 2634–2693` (tile = 27) |
| other gold sources | none. Writers of `gold[]` (`i.f:[I`): `<init>`, `o()V` income, `a(BII)Lc;` / `a(Lc;II)Lc;` buy / rebuy, `r()V` campaign preset, `a([B)V` load, `a(II)V` cheat. Campaign script `s()V` never writes it -> no kill / capture / raze / event gold | none | ✓ | grep of every `i.f:[I` access in i.class |
| cheat | campaign only: key sequence `18241824` -> +1000 gold (`14281428` = win the level) | none | — | `i.a(II)V @pc 97–117`; strings `i.<clinit> @pc 914–924` |

## Gold per turn, early game

Gold available at the **start of own turn N** before spending (start + all income so far; buys not deducted). P1 moves first (no turn-1 income).
"take k" = one soldier captures 1 neutral village per own turn from turn 2 (paid from the next turn). This pace is an assumption, not measured. Value after the colon = cumulative gold (income that turn).

| scenario | holdings at start | T1 | T3 | T5 | T10 |
|---|---|---|---|---|---|
| orig s9 Morningstar / s1 The Crossing, default 500, P1, no capture | 1 castle (50) | 500 | 600 | 700 | 950 |
| same, P1, take 4 | | 500 | 630 (+80) | 880 (+140) | 1730 (+170) |
| same, P2, take 4 | | 550 | 680 | 930 | 1780 |
| orig s0 Icy Paths / s5 Peak Island, default 500, P1, no capture | 2 villages + 1 castle (110) | 500 | 720 | 940 | 1490 |
| same, P1, take 3 | | 500 | 750 (+140) | 1120 (+200) | 2120 (+200) |
| **ours** dong_bang, default 300, P1, no capture | 1 castle (50) | 300 | 400 | 500 | 750 |
| ours dong_bang, P1, take 2 (4 villages + 2 ruins on the map) | | 300 | 430 (+80) | 650 (+110) | 1200 (+110) |
| **ours** cua_bien / nui_rung, default 300, P1, take 4 (8 villages on the map) | 1 castle (50) | 300 | 430 | 680 (+140) | 1530 (+170) |
| ours cua_bien at the 500 option, P1, take 4 | | 500 | 630 | 880 | 1730 |

Notes:
- Income rates are identical. Most original 2p maps (s1, s7, s9) also start at 1 castle = 50/turn, like ours.
- At default settings the gap is only the start gold: ours = original − 200 every turn (300 vs 500). Ours also starts with a free soldier (cost 150), so effective start ≈ 450 vs 500. The original 2p maps start with a King only.
- Original start holdings per 2p map: s0 Icy Paths 2v+1c (6 neutral v, 2 neutral c), s1 The Crossing 1c (7v, 2c), s5 Peak Island 2v+1c (4v, 2 ruins), s7 Liberty Port 1c (9v, 1c), s9 Morningstar 1c (8v). Ours: 1c each; dong_bang 4v + 2 ruins + 2 neutral c, cua_bien / nui_rung 8v + 2 neutral c.
- Original cap 10 (default) binds earlier than our 15: about 9 bought units + King.

## What to change (suggestions, not applied)
- For original defaults: skirmish/duel default gold 500 and cap 10; options {500, 1000, 2000} / {10, 20, 25}. Our 300 / 15 / 30 and "easy" are deliberate deviations; label them so in the comments (`menus.gd:20–21, 527`, `content.gd:71–72`).
- `rules.gd:141`: change the comment "AE2 RM MainDisplayable:3310" -> original `i.b(I)V @pc 738–741`.

## Cross-aspect (one line each)
- Max buyable unit type `i.I`: skirmish 8 (all except King re-buy, Skeleton, Crystal); campaign m0..m7 = 0, 1, 0, 7, 0, 7, 8, 8 (`i.r()V`, `menu @pc 1638`).
- `o()V @pc 414–441`: a side with 0 units and 0 castles is skipped (turn passes on).
- AI (`q()V @pc 1632–1659`) checks gold < 1000 and unit count ≥ 8 (saving logic, not analysed).
