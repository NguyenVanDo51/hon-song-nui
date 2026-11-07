# AE2 original vs ours: combat + terrain

## Summary (5 lines)
1. **One major difference: movement.** Original units can spend move points = `units.bin` move **− 1** (Soldier 4, Wolf 5, Catapult 3, Wyvern 6). Ours lets them spend the full table value (5 / 6 / 4 / 7) -> every unit gets +1 move. That is +1 tile on open ground, +49% reachable area for a Soldier, and +1 threat range.
2. Damage formula = exact match: `roll[min, max−1] + atk bonuses − (def + rank + terrain + def bonuses)`, × attacker hp / 100, rounded toward 0, clamped to 0..target hp. The rank, poison, aura, anti-air, Wisp-vs-Skeleton and water bonuses all match. All bonuses are added before the hp scaling, so the order they apply in does not change the result.
3. Counter attacks match: the defender must be alive, attacker exactly 1 tile away, defender min range 1, and the counter uses the defender's hp after the hit. Poison lands after the counter, and only if the target survived. Each side gains XP and promotes once per fight. Max rank 9.
4. Terrain table (defence / move cost / heal / income / capture / ruins / repair / raze), graves (3 ticks), Skeleton raise and Catapult move-or-attack all match. Missing in ours: tile 34 "crystal pedestal" (+25 atk / +15 def), used only once, in campaign map m7.
5. Cheap-unit effect: the +1 move helps every unit, but proportionally most the cheap / slow ones: Soldier 4 -> 5 (+25%), Catapult 3 -> 4 (+33%), Wyvern 6 -> 7 (+17%). Cheap Soldiers capture villages faster and threaten from farther. None of the other combat rules here favour cheap units vs the original.

Method: own mini bytecode disassembler (`ae2tools/combat_dis.py`, output `ae2tools/combat_c.txt`, `combat_i.txt`, `combat_d.txt`), own parser for `units.bin` (`ae2tools/combat_units.py`), and a decode of `tiles0.prop` and the map headers. Citations use the form `class method @pc N`. Field names were worked out from the bytecode: `c.d:I/e:I` = atk min/max (rank included), `c.f:I` = def, `c.g:I` = hp, `c.f:S` = temp atk bonus, `c.g:S` = temp def bonus, `c.g:B` = status bits (1 poison, 2 aura), `c.f:B` = state (0 ready, 2 done, 3 grave, 4 dummy village target), `c.h:B` = grave counter, `c.a:S` = rank, `c.a:I` = xp, static `c.a[]` = move, `c.c[]` = max range, `c.d[]` = min range. Ours: `~/personal/hon-song-nui` @ `ad69350`.

## 1. Damage formula

| item | original | ours | match | evidence |
|---|---|---|---|---|
| attack roll | `min + abs(rnd.nextInt()) % (max − min)` -> uniform on **[min, max−1]**; max never rolled. min/max already include rank | `atk_range` = [atk+r, atkMax−1+r], uniform | ✓ | `e.class a(II)I @pc 0–15`; ours `game.gd:363 atk_range`, `:397 damage` |
| atk side | roll + `c.f:S` (aura +10, poison −10) + 15 if attacker has bit 64 and target flies (bit 1) + 15 if attacker is type 4 (Wisp) and target type 10 (Skeleton) + 10 if attacker has bit 2 and **attacker's own tile** is water (type 5) + 25 if attacker's tile id = 34 | `_mods`: antiAir 15 vs `move=="fly"`, `vsType ghost 15`, waterAtk 10 on attacker tile, +aura, −poison; no tile 34 | ✓ (except tile 34) | `c.class a(Lc;II)I @pc 0–93`, `c(Lc;)I @pc 0–16`; ours `game.gd:371–395` |
| def side | target `def` (base + 2×rank) + `c.g:S` (poison −10) + terrain def[type] at **target tile** + 15 if target has bit 2 and is on water + 15 if target tile id = 34 | `D = def + 2×rank + terrain + waterDef 15 − poison` | ✓ (except tile 34) | `c.class b(Lc;II)I @pc 0–60` |
| hp scaling / rounding | `(atk − def) × attacker_hp / 100` (Java int division, rounds toward 0) | `floori(raw × hp / 100.0)` | ✓ (floor vs toward-0 differ only for negative raw values, and both clamp those to 0) | `c.class c(Lc;)I @pc 29–39` |
| clamps | `<0 -> 0`, `> target hp -> target hp`; no minimum damage of 1 | `clampi(.., 0, d.hp)` | ✓ | `c(Lc;)I @pc 40–65` |
| bonus order | all added before the single hp multiplication -> order does not matter | same | ✓ | as above |
| flier terrain def | no flier exception in def (Wyvern gets mountain +15, water 0) | `terrain_def` has no exception | ✓ | `b(Lc;II)I` (no bit-1 check) |
| buildings | attacker on a building: no attack bonus; defender on village / castle / temple: +15 def like any terrain | same | ✓ | `i.f[]` table below |

## 2. Counter attack, poison, aura, XP

| item | original | ours | match | evidence |
|---|---|---|---|---|
| fight order | attacker hits -> if `defender.canCounter(attacker pos)` defender hits back -> post-fight step | same | ✓ | `i.class b(Lc;Lc;)V @pc 89–127` (animated) and `c()V @pc 1663–1960` (no animation) |
| who counters | defender state ≠ 4, **hp > 0 after the hit**, Manhattan distance to attacker **== 1**, defender min range == 1. Already-acted defenders still counter | `can_counter`: not siege, rmin == 1, dist == 1; called only if d.hp > 0 | ✓ | `c.class a(Lc;II)Z @pc 0–53` |
| hp used for the counter | defender's current hp (after the hit) | `d.hp` after the hit | ✓ | `c(Lc;)I` reads `this.g` |
| counter pos bonuses | `a(Lc;)` uses the counterer's own tile (Elemental water +10 applies on the counter too) | `damage(s, d, d.x, d.y, ..)` | ✓ | `c.class a(Lc;)I @pc 0–10` |
| ranged counter | Archer (1–2): counters only when hit from 1 tile away; Catapult (2–4): never counters | same | ✓ | `units.bin` ranges + `a(Lc;II)Z` |
| poison | post-fight: if defender alive and attacker has bit 128 -> status 1 (−10 atk, −10 def). Applied **after** the counter (does not weaken it). Applies even on 0 damage and even if the wolf died. Owner = current player; cleared at the start of that player's next turn. Counters do not poison | same (`game.gd:664`, cleared in `end_turn`) | ✓ | `i.class h()V @pc 46–183`; `c.class b(B)V`, `b()V @pc 15–45`; `i.class o()V @pc 147–169` |
| aura | when a Wisp finishes **any** action (`c.d()V`), every ally at distance **1–2** gets status 2 (+10 atk). It is a bit flag, so several Wisps do not stack. Runs even if the Wisp died on the counter. Cleared at the start of the owner's next turn | after any action, allies at dist ≤ 2 (`o.id != u.id`) get max(+10); cleared same way | ✓ (edge case: ours also covers a stacked ally at dist 0) | `c.class d()V @pc 29–103`, `b()V @pc 48–66`; `i.class o()V @pc 172–185` |
| XP per hit | hitter.xp += victim.quality × damage; quality = atkMin + atkMax + def **incl. rank** (+6/rank); also for counters and for 0 damage; no kill bonus | `_gain_xp`, `quality` (+3×2×rank) | ✓ | `c.class c(Lc;)I @pc 78–91`, `a()I` |
| XP needed | `quality × 100 × 2 / 3` (int); own rank included | `int(quality × 200/3.0)` | ✓ (same integers) | `c.class b()I` |
| promote | after the fight: attacker if alive, then defender if alive; ≤ 1 rank per fight; only if rank < 9; xp −= need, leftover carries | `_promote` ×2 | ✓ | `i.class h()V @pc 4–46, 186–204`; `c.class a()Z` |
| rank effect | +2 atk min, +2 atk max, +2 def per rank; move unchanged; name tier = min(rank/2, 3) (not for King) | +2 / +2 | ✓ | `c.class a(B)V @pc 0–95` |

## 3. Terrain

`tiles0.prop` (pak) = u16 count 47, u16 skip, then 47 bytes tile->type. Tables are hard-coded in `i.class <clinit>`: def `i.f[]` @pc 677–731, move cost `i.g[]` @pc 734–782.

| type | tiles (id) | def | cost foot | cost fly | cost water-unit | heal | income | capture | ours letter | match |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 road | 20–26, 28 | 0 | 1 | 1 | 1 | – | – | – | `r` 0/1 | ✓ |
| 1 grass | 18 | 5 | 1 | 1 | 1 | – | – | – | `.` 5/1 | ✓ |
| 2 forest | 15–16 | 10 | 2 | 1 | 2 | – | – | – | `f` 10/2 | ✓ |
| 3 hill | 19, 33, 35, 36 | 10 | 2 | 1 | 2 | – | – | – | `h` 10/2 | ✓ |
| 4 mountain | 17 | 15 | 3 | 1 | 3 | – | – | – | `m` 15/3 | ✓ |
| 5 water | 0–14 | 0 (+15 for an Elemental) | 3 | 1 | **1** | – | – | – | `~` 0/3, water 1 | ✓ |
| 6 bridge | 29–30 | 5 | 1 | 1 | 1 (no water bonus) | – | – | – | `=` 5/1 | ✓ |
| 7 temple / well | 31, 32, 34 | 15 | 1 | 1 | 1 | +20 any side | – | no | `t` 15/1 heals any | ✓ |
| 8 village | 37 neutral, 39/41/43/45 owned, **27 ruins** | 15 | 1 | 1 | 1 | +20 owner | 30 | Soldier, King (bit 8) | `v` / `x` | ✓ |
| 9 castle | 38 neutral, 40/42/44/46 owned | 15 | 1 | 1 | 1 | +20 owner | 50 | King only (bit 16) | `c` | ✓ |

| rule | original | ours | match | evidence |
|---|---|---|---|---|
| **move budget** | DFS starts with `remaining = units.bin move`; a tile is marked only if `remaining > grid` and grid is zero-filled, so a tile reached with 0 left is **not** marked; a destination needs `grid > 0`. -> **path cost ≤ move − 1**. The AI also divides by `move − 1`. The info screen shows the raw value (5) | Dijkstra, `if nc > mv: continue` -> **path cost ≤ mv** with mv = raw table value | **✗ (+1 move for all)** | `c.class b([[B)V @pc 0–32`, `a([[BIIIIBBZ)Z @pc 0–36`; `i.class a([[BI)V` (fill 0), `b(Lc;)V @pc 37–51`, `c()V @pc 4092–4106` (`ifle` = grid > 0 check), `a(Lc;IILc;Lc;)I @pc 123–132` (`move − 1`); `d.class @pc 2534` (UI shows raw); ours `game.gd:227–256` |
| effective move | Soldier / Archer / Elemental / Sorceress / Wisp / Golem / King / Skeleton **4**, Wolf **5**, Catapult **3**, Wyvern **6** | 5 / 6 / 4 / 7 | ✗ | `units.bin` byte 0 per unit = 5,5,5,5,5,6,5,4,7,5,5,4 |
| enemy tile | cost 1000 (blocks, fliers too); allies pass at normal cost | same | ✓ | `c.class a(IIBB)I @pc 28–69` |
| fliers | cost 1 on every tile | same | ✓ | `a(IIBB)I @pc 96–105` |
| water unit | cost 1 on water (type 5) only; land as foot | same | ✓ | `a(IIBB)I @pc 106–121` |
| mountain | only the Crystal (type 11) is barred; Golem / Catapult enter at cost 3 | no bar | ✓ | `a(IIBB)I @pc 80–95` |
| heal | at the start of the owner's turn: unit not a grave, on type 7 (any side) or a building owned by its side: `+min(20, 100 − hp)`; nowhere else | `heals_at` + `end_turn` | ✓ | `i.class c()V @pc 1047–1179`, `a(III)Z` |
| tile 34 crystal pedestal | type 7 (heals), plus **+25 atk / +15 def** for anyone on it. Only in campaign map m7 (×1); never in s0–s11 | absent | ✗ (campaign only) | `c.class a(Lc;II)I @pc 73–88`, `b(Lc;II)I @pc 40–55`; map scan |
| ruins (27) | type 8 village: def 15 / cost 1, not owned -> no heal, no income | `x` 15/1 | ✓ | `i.class a(II[[B)I` (id < 37 -> −1) |
| repair | unit with bit 8 on a ruin -> menu "REPAIR" -> tile = 37 (neutral village); ends the action; capture is a later action | `repairTo v`, `repairBy capV` | ✓ | `i.class a(IILc;)Z`; `a(Ld;ILjava/lang/String;B)V @pc 5926–5946` |

## 4. Catapult, graves, Skeletons

| item | original | ours | match | evidence |
|---|---|---|---|---|
| move or attack | the ATTACK menu item is offered for type 7 only in the pre-move menu (mode 1) -> attack from the start tile or move, never both. Attack range 2–4, so no adjacent attacks | `targets_from`: siege -> only from its own tile | ✓ | `i.class a(Lc;B)[B @pc 123–169` |
| raze | targets: tile type 8 with id ≥ 37 (neutral or owned village), **not own**, no unit on it, in range 2–4 -> becomes tile 27 (ruins); castles cannot be razed; no XP; ends the action | `razable_from`: `razeTo` (village), owner ≠ side (incl. unowned), empty, in range, own tile only | ✓ | `c.class a(IIIIB)[Lc; @pc 196–295`; `i.class a(Lc;Lc;)V @pc 0–51`, `c()V @pc 2634–2693` |
| death | state 3, counter 3. Skeleton (10) / Crystal (11) removed with no grave. King moved off-map, no grave, rebuy cost +200 (max 1000) | `_kill`: grave ttl 3; hero / ghost (`noGrave`) none | ✓ | `i.class c()V @pc 2806–2931` |
| grave life | at every player switch, every grave counter −1, removed at ≤ 0 (2 players: dies at the start of the killer's opponent's 2nd turn) | `end_turn` ttl −1 per side switch | ✓ | `i.class o()V @pc 77–139` |
| grave cleared | finishing any action on the grave tile (`c.d()V`) removes it; graves do not block movement | removed when a move ends on it | ✓ (same in practice: only a unit that moved there can stand on a grave) | `c.class d()V @pc 0–28`; `i.class a(IIB)Lc;` (mode 0 skips graves) |
| raise who / where | unit with bit 32 (Sorceress, range 1–1) -> graves (mode 1, **any side**) at distance exactly 1; allowed after moving; no unit-cap check | `raisable_graves`: dist == 1, any side, no cap | ✓ | `i.class a(Lc;B)[B @pc 170–206`, `a(IIB)Lc; @pc 100–116` |
| raised unit | grave removed -> new type 10 for the raiser's side at the grave tile, rank 0, hp 100, state 2 (acted). Skeletons are not counted toward the cap (count − skeletons) | `spawn(.., acted=true)`, `noCap` | ✓ | `i.class c()V @pc 3315–3379`; `a(BII)Z @pc 0–26` |

## 5. Differences ranked by gameplay impact

1. **Move +1 for every unit (major).** Original effective move = table − 1 (`c.class a([[BIIIIBBZ)Z` marks only tiles with remaining > 0; destinations need `grid > 0`; AI uses `move − 1`). Ours spends the full value (`game.gd:246 if nc > mv`).
   - Open ground, Soldier: 41 -> 61 reachable tiles (+49%); threat radius 5 -> 6. The 2-move rough tiles also differ: forest / hill (cost 2) ×2 is reachable in both, but ours adds +1 grass tile; wading (cost 3) + 1 grass in the original vs + 2 in ours.
   - Relative gain is largest for cheap / slow units: Soldier, Archer, Elemental, Sorceress, Wisp, Golem, King 4 -> 5 (+25%); Catapult 3 -> 4 (+33%); Wolf 5 -> 6 (+20%); Wyvern 6 -> 7 (+17%). Cheap Soldiers reach and capture villages a turn sooner, and melee rushes land earlier. The Catapult's move-or-attack penalty gets lighter.
   - Fix options: (a) store original effective move in `rules.gd` (soldier 4 … bird 6) and keep the UI showing that value, or (b) keep the table and use `nc > mv − 1` in `_reach_all`. The AI's mv uses (`ai.gd:185/266/422/761`, `ai_plan.gd:279/329/346`, `ai_buy.gd:116`, `content.gd:210–213` text) must follow the same change. Option (a) is simpler and keeps the AI consistent.
2. **Tile 34 crystal pedestal (+25 atk / +15 def, heals): not in ours (minor).** Original uses it only in campaign map m7, once. Ours has no such tile; only relevant if a level ports m7.
3. **Aura at distance 0 (tiny edge case).** Ours `dist ≤ 2` with `o.id != u.id` also buffs an ally stacked on the same tile (just bought on the castle). The original uses range 1–2, so a stacked ally gets nothing. Practically irrelevant.

Nothing else in combat / terrain differs. None of the damage, counter, XP or terrain rules favour cheap units vs the original; only the move rule (#1) does.

## Notes / unverified
- A `Math.abs(Integer.MIN_VALUE)` roll edge case (< min) exists in the original; negligible.
- Effective move is derived from bytecode, not checked in a running original (never execute the jar). Three independent code paths agree (player fill + `grid > 0`, buy-expand check, AI `move − 1`).

## Tech-debt notes for docs/TODO.md (repo is read-only for this task; caller should add)
- `scripts/core/game.gd:246` — move budget = table `mv`, original = `mv − 1` -> every unit +1 move vs AE2 (fix in rules table or here; keep the AI in sync).
- `scripts/core/game.gd:717` — aura radius `<= 2` includes a stacked ally at dist 0 (original 1–2) -> negligible; use `>= 1`.
- `scripts/core/game.gd:362` comment cites RM `Renderer.java` for the roll; now confirmed in original `e.class a(II)I` -> update the citation.

## Cross-aspect (one line each)
- Maps: original skirmish maps s0–s11 contain **no temple tiles** (31/32/34 absent; temples only in campaign m0–m4, m6, m7), but ours has 6 `t` tiles in `content/skirmish_maps.gd`.
- Units: `units.bin` stats match `rules.gd` UNITS 1:1 (atk / def / range / cost / flags); only the meaning of `mv` differs (#1).
