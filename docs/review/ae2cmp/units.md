# AE2 original vs ours: UNITS

## Summary (5 lines)
1. `pak/units.bin` fully parsed (12 records, 209 B, 0 bytes left over); layout comes from loader `c.class a(Li;)V` pc 17–191. Stats for all 10 playable types (cost / atk min-max / def / mv / rmin-rmax / move class) are **byte-identical** to our `rules.gd UNITS`. (Since 2026-11-08 ours stores mv = original − 1 = steps really walked; see combat.md "move budget".)
2. units.bin holds only **flag bits**; every amount (+15 anti-air, +15 Wisp vs Skeleton, +10/+15 water, −10/−10 poison, +10 aura, +2/rank, max rank 9, King 200 +200 → 1000) is a constant in the code. Ours matches every one.
3. Real differences: ghost `cost: 150` (original −1 = not buyable; ours only feeds the AI `aiValue` default); Crystal (type 11) missing (campaign only, deliberate); ours-only fields `heavy` / `shot` / `aiWeight` / `aiValue` (cosmetic / AI); `raze` is a flag in ours vs hard-coded `type == 7` in the original (same behavior). Edge case: aura min distance 1 in the original vs 0 in ours (a unit stacked on the Wisp's tile).
4. 3 items that spec.md lists as "mod only, not yet checked" are **original behavior** (bytecode): the roll never hits atkMax; poison is applied after the counter and even if the wolf died; a dead Wisp still gives its aura.
5. "Soldier = cheap but strong" also holds in the original (same numbers): best avg attack per 100 gold of any shop unit = 34.7, vs 20.8 for Archer (next).

Tools: `/private/tmp/claude-502/-Users-do-nguyen-personal/cfff715e-1d2a-4526-a70a-0a4efef517da/scratchpad/ae2tools/jdis.py` (mini javap), `units.py` (units.bin parser), disassembly `c.txt`, `i.txt`, `e.txt`, `g.txt` in the same dir.

---

## 1. units.bin record layout (evidence: `c.class a(Li;)V` pc 17–191, statics created in `<clinit>` pc 16–73)

Loop `i = 0..11` (pc 19–22 `bipush 12`), per record, all `DataInputStream` reads, big-endian:

| # | bytes | read | stored in | meaning | evidence |
|---|---|---|---|---|---|
| 1 | 1 | readByte | `c.a[B][i]` | move points | pc 25–33; used as the flood-fill budget `c.a[t] + c.e:S` in `b([[B)V` pc 9–21; `c.e:S` (move bonus) only ever set to 0 (`b()V` pc 2) |
| 2 | 1 | readByte | `c.b[[B][i][0]` | atk min | pc 34–44; `a(B)V` pc 11–23 -> `c.d:I` |
| 3 | 1 | readByte | `c.b[[B][i][1]` | atk max (exclusive) | pc 45–55; `a(B)V` pc 27–39 -> `c.e:I` |
| 4 | 1 | readByte | `c.b[B][i]` | defence | pc 56–64; `a(B)V` pc 43–53 -> `c.f:I` |
| 5 | 1 | readByte | `c.c[B][i]` | range **max** | pc 65–73; `a(IIB)[Lc;` pc 11 passes it as the upper bound of `a(IIIIB)` (dist > p4 -> skip, pc 113–135) |
| 6 | 1 | readByte | `c.d[B][i]` | range **min** | pc 74–82; same call, lower bound; counter needs `c.d[t]==1` (`a(Lc;II)Z` pc 38–47) |
| 7–8 | 2 | readShort (signed) | `c.a[S][i]` | cost; −1 (0xFFFF) = not buyable | pc 83–91; buy check `i.a(BII)Z` pc 54–59 needs cost > 0 |
| 9 | 1 | readByte n | — | battle-scene figure count | pc 92–107 |
| … | 2n | readByte×2 | `c.a[[[B][i][k][0..1]` | figure (x, y) in battle scene, **not gameplay** | pc 108–148; copied to the unit `c.a:[[B` (`a(BBIIZ)` pc 40–47); `g.class b()V` pc 2819 arraylength; `c.c()I` = figures drawn ∝ hp |
| … | 1 | readByte m | — | number of property bits | pc 151–155 |
| … | m | readByte×m | `c.b[S][i] |= 1<<idx` | property mask | pc 157–185; read back by `c.a(BS)Z` (mask & v) |

Property bits (value = 1<<idx): 1 fly, 2 water, **4 = King only, never read in any class a–i (inferred: commander marker; code uses `type==9`)**, 8 capture village, 16 capture castle, 32 raise, 64 anti-air, 128 poison, 256 aura, 512 siege. Uses: see §3.

## 2. Parsed unit table (original) vs ours

Lang names: `lang.txt` line 140 + 4×type (rank 0 name), description line 185 + type. Commander name = lang line 94 + (color−1): GALAMAR / DEMON LORD / VALADORN / SAETH (`c.b(I)V` pc 6–14, `a(BBIIZ)` pc 60–78).

| type | file off | original (lang) | ours key | cost | atk min–max | def | mv | range | move | prop bits (mask) | figures |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 0x00 | SOLDIER | soldier | 150 | 50–55 | 5 | 5 | 1–1 | foot | 3 (8) capV | 5 |
| 1 | 0x15 | ARCHER | archer | 250 | 50–55 | 5 | 5 | 1–2 | foot | 6 (64) anti-air | 5 |
| 2 | 0x2a | ELEMENTAL | boat | 300 | 50–55 | 10 | 5 | 1–1 | water | 1 (2) water | 5 |
| 3 | 0x3f | SORCERESS | shaman | 400 | 40–45 | 5 | 5 | 1–1 | foot | 5 (32) raise | 5 |
| 4 | 0x54 | WISP | drum | 500 | 35–40 | 10 | 5 | 1–1 | foot | 8 (256) aura | 3 |
| 5 | 0x65 | DIRE WOLF | wolf | 600 | 60–65 | 15 | 6 | 1–1 | foot | 7 (128) poison | 3 |
| 6 | 0x76 | GOLEM | elephant | 600 | 60–70 | 30 | 5 | 1–1 | foot | none (0) | 3 |
| 7 | 0x86 | CATAPULT | catapult | 700 | 50–70 | 10 | 4 | 2–4 | foot | 9 (512) siege | 3 |
| 8 | 0x97 | DRAGON (sprite `wyvern`) | bird | 1000 | 70–80 | 25 | 7 | 1–1 | fly | 0 (1) fly | 1 |
| 9 | 0xa4 | COMMANDER (King) | hero | 200 | 55–65 | 20 | 5 | 1–1 | foot | 2,3,4 (28) | 1 |
| 10 | 0xb3 | SKELETON | ghost | −1 | 40–50 | 2 | 5 | 1–1 | foot | none (0) | 5 |
| 11 | 0xc7 | CRYSTAL | — | −1 | 0–0 | 15 | 4 | 0–0 | foot, no mountain (`c.a(IIBB)I` pc 80–95) | none | 0 |

atk max is exclusive: roll = `min + |rand| % (max − min)` (`e.class a(II)I` pc 0–14) -> Soldier rolls 50..54.

## 3. Field-by-field: original vs ours (`scripts/core/rules.gd` UNITS, `scripts/core/game.gd`)

### 3a. Base stats
| item | original | ours | match? | evidence |
|---|---|---|---|---|
| cost / atk / atkMax / def / mv / rmin / rmax, types 0–9 | table §2 | rules.gd:34–106 same numbers | ✓ all 70 values | units.bin offsets §2 |
| Skeleton atk / def / mv / range | 40–50 / 2 / 5 / 1 | ghost 40/50/2/5/1–1 | ✓ | off 0xb3 |
| Skeleton cost | −1 (not buyable) | `cost: 150` + `buyable: false` | ✗ value (no gameplay effect: hidden in UI `style.gd:416`; only the AI `aiValue` default = cost -> AI scores a ghost as 150) | off 0xb9–0xba = `ff ff` |
| Commander cost (first buy) | 200 | hero 200 / heroBase 200 | ✓ | off 0xaa–0xab; `a(BBIIZ)` pc 50–57 -> `c.k` |
| Commander rebuy | `if c.k < 1000: c.k += 200` per death; pay `c.k`, hp = 100, keeps rank / xp | heroStep 200, heroMax 1000, heroSaved | ✓ | `i.class` pc 2894–2931; `i.a(Lc;II)Lc;` pc 0–19 |
| Commanders all the same stats | one type 9 for every king | HEROES {} = no overrides | ✓ | units.bin only has 1 king record |
| Commander in normal shop | no: shop covers types 0..`i.I`; `i.I` = 8 (skirmish default), campaign 0/1/7/8 per map | not in BUY_ORDER; rebuy only | ✓ | `i.a(BII)Z` pc 29–34; `i.I` set at i.class pc 545 etc. |
| Crystal (type 11) | exists, campaign escort unit | absent | ✗ (deliberate, spec "Để sau") | off 0xc7 |
| move class | fly = bit 1 -> every tile costs 1; water = bit 2 -> water tile costs 1; others use the terrain table | `move` foot/fly/water, `move_cost` game.gd:206 | ✓ | `c.a(IIBB)I` pc 96–128 |
| rank bonus | +2 atk min, +2 atk max, +2 def per rank; mv unchanged | rankBonus 2 on atk ends + def; quality +3×2×rank | ✓ | `c.a(B)V` pc 6–53 |
| max rank | 9 (promote only if rank < 9) | maxRank 9 | ✓ | `c.a()Z` pc 1–6 |
| rank name | changes every 2 ranks, max 4 names (lang 140+4t+min(r/2,3)); Commander keeps its own name | (names = UI aspect) | n/a | `c.a(B)V` pc 56–95 |

### 3b. Specials (magnitudes are code constants)
| item | original | ours | match? | evidence |
|---|---|---|---|---|
| anti-air | +15 atk if attacker has bit 64 and target has bit 1 | archer `antiAir: 15` vs `sd.move=="fly"` | ✓ | `c.a(Lc;II)I` pc 10–27 |
| Wisp vs Skeleton | +15 atk, hard-coded `type 4` vs `type 10` (not a bit) | drum `vsType {ghost: 15}` | ✓ | same method pc 30–47 |
| water atk | +10 if bit 2 and the **attacker's** tile = terrain 5 (water) | boat `waterAtk 10`, checks (ax, ay) | ✓ | pc 50–70 |
| water def | +15 if bit 2 and the defender's tile = water | boat `waterDef 15` | ✓ | `c.b(Lc;II)I` pc 23–37 |
| tile 34 (crystal altar) | +25 atk / +15 def for anyone on it | — | ✗ (terrain aspect, campaign only) | `a(Lc;II)I` pc 73–88, `b(Lc;II)I` pc 40–55 |
| poison: amount | status bit 1 -> −10 atk, −10 def; move NOT reduced (lang says "slow", code doesn't) | wolf `poison: 10` (atk + def) | ✓ | `c.b()V` pc 15–45; `c.e:S` only = 0 |
| poison: trigger | only if the **attacker** has bit 128 and the defender survives the whole exchange; even if the wolf died, even with 0 dmg; the wolf's counter-hits do not poison | game.gd:664 checks the attacker `u`, `d.hp > 0` branch | ✓ | `i.h()V` pc 46–183 |
| poison: expiry | cleared at the start of the poisoner's side's turn (`c.i` = side) | `end_turn` clears `poison == s.side` | ✓ | `i.o()V` pc 147–169 |
| aura: amount | status bit 2 -> +10 atk, no stacking (bit) | drum `aura: 10`, `maxi` | ✓ | `c.b()V` pc 48–66 |
| aura: who / range | same-team units, Manhattan **1..2** around the Wisp | same side, `dist <= 2`, skips self by id | ≈ (ours also buffs a unit stacked on the Wisp's tile, dist 0) | `c.d()V` pc 29–51 -> `a(IIIIB)` mode 2 |
| aura: when | `finishMove` after every action, also when the Wisp attacked and died | after every action, from where it stands | ✓ | `i.h()V` pc 317–321 (unconditional) |
| aura: expiry | start of the unit's own side's turn | `aura == s.side` cleared | ✓ | `i.o()V` pc 172–185 |
| raise | bit 32 (Sorceress) -> Skeleton (type 10), grave next to it | shaman `raise: "ghost"`, dist 1 | ✓ | `i.a(Lc;B)[B` pc 171; `i.e(Lc;)V` pc 2180 |
| Skeleton cap | cap count = all units − Skeletons | ghost `noCap` | ✓ | `i.a(BII)Z` pc 1–26 |
| siege | bit 512: attack only from its own tile (no move + attack) | catapult `siege` | ✓ | `c.a([[B)V` pc 1–23; `i.e(Lc;)V` pc 2083 |
| counter | defender alive, adjacent (dist 1), `rmin == 1` | `can_counter`: same + `not siege` (redundant, catapult rmin 2) | ✓ | `c.a(Lc;II)Z` pc 0–51; call `i.b(Lc;Lc;)V` pc 95–113 |
| raze villages | hard-coded `type == 7` vs terrain 8 (village), not a bit | catapult `raze: true` flag | ✓ behavior, different mechanism | `c.a(IIIIB)` pc 196–285 |
| capture | bit 8 village (Soldier + King), bit 16 castle (King) | capV soldier + hero, capC hero | ✓ | `i.a(IILc;)Z`, `i.b(IILc;)Z` pc 0–76 |
| `heavy` | no such thing | hero / elephant / catapult / bird | ours only (fx / sound) | — |
| `shot`, `aiWeight`, `aiValue` | no such thing | various | ours only (fx / AI) | — |

## 4. Attack per gold and defence (avg roll = (min + max−1)/2, max exclusive)

Original = ours for every buyable type (identical bytes), so both columns are equal.

| unit (orig / ours) | cost | rolls | avg atk | avg atk / 100 g orig | ours | def | def / 100 g orig | ours |
|---|---|---|---|---|---|---|---|---|
| Soldier / soldier | 150 | 50–54 | 52 | 34.7 | 34.7 | 5 | 3.3 | 3.3 |
| Archer / archer | 250 | 50–54 | 52 | 20.8 | 20.8 | 5 | 2.0 | 2.0 |
| Elemental / boat | 300 | 50–54 | 52 | 17.3 | 17.3 | 10 | 3.3 | 3.3 |
| Sorceress / shaman | 400 | 40–44 | 42 | 10.5 | 10.5 | 5 | 1.2 | 1.2 |
| Wisp / drum | 500 | 35–39 | 37 | 7.4 | 7.4 | 10 | 2.0 | 2.0 |
| Dire Wolf / wolf | 600 | 60–64 | 62 | 10.3 | 10.3 | 15 | 2.5 | 2.5 |
| Golem / elephant | 600 | 60–69 | 64.5 | 10.8 | 10.8 | 30 | 5.0 | 5.0 |
| Catapult / catapult | 700 | 50–69 | 59.5 | 8.5 | 8.5 | 10 | 1.4 | 1.4 |
| Dragon / bird | 1000 | 70–79 | 74.5 | 7.5 | 7.5 | 25 | 2.5 | 2.5 |
| Commander / hero (1st buy) | 200 | 55–64 | 59.5 | 29.8 | 29.8 | 20 | 10.0 | 10.0 |
| Commander / hero (rebuy 400…1000) | 400–1000 | 55–64 | 59.5 | 14.9–6.0 | same | 20 | 5.0–2.0 | same |
| Skeleton / ghost | not buyable (ours "150") | 40–49 | 44.5 | — | (29.7 if 150 counted) | 2 | — | — |

## 5. Comment / doc notes found (repo is read-only, not edited; for docs/TODO.md "Nợ kỹ thuật")
- `docs/spec.md` "Còn theo mã bản mod": roll `[min, max−1]` = original (`e.class a(II)I`); poison after the counter (even if the wolf died) = original (`i.h()V` pc 46–183); dead Wisp still gives aura = original (`i.h()V` pc 317–321). Only "campaign cap 100" is left unchecked here.
- `game.gd:362` comment cites RM `Renderer.java` -> the original `e.class a(II)I` now confirms it.
- `rules.gd:108` ghost `cost: 150`: no source in the original (−1); only feeds the AI `aiValue` default. Either drop it + set `aiValue` explicitly, or leave a comment saying it's a deliberate AI value.
- `game.gd:717` aura `dist <= 2` also hits a unit stacked on the Wisp's tile (original min dist 1). Rare (only a freshly bought unit on the castle).
- `game.gd:419` `not siege` is redundant (catapult rmin 2 already blocks). Harmless.

## Verdict
Soldier "cheap but strong" is the original's own design: same 50–55 atk as Archer / Elemental for 150 g, avg atk / 100 g = 34.7 (best of any shop unit; Commander 29.8 at its first 200 g price, not shop-buyable), but def 5 = joint lowest.

## Cross-aspect (1 line each)
- AI: original shop AI `i.q()V` pc 1672–1746 skips a type it already owns when that type costs < 600 (AI army mix): for the AI agent.
- Terrain / raze: original raze target = village tile with sprite id ≥ `i.j` and not owned by own team (`c.a(IIIIB)` pc 220–262): check whether neutral villages can be razed (ours: enemy or unowned).
