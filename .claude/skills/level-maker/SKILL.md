---
name: level-maker
description: Use when adding, redrawing or rebalancing Thử thách levels in Công Thành Chiến (content/levels/*.gd) — writing a recipe, generating candidate maps with sim/levelgen.gd, picking one, installing it, then calibrating tier + stars with sims.
---

# Level maker (Công Thành Chiến)

Levels = `content/levels/<id>.gd` (`const DEF`), sorted by `order`. Hand-made `m01`–`m16` sit at order 10…160; generated levels are `g01`, `g02`… slotted between (e.g. order 45). Design: `docs/superpowers/specs/2026-11-07-levels-design.md`. DEF format: `docs/content.md` § "Thêm level".

## Hard rules
- **Never edit bot logic** (`scripts/core/ai.gd`, `ai_plan.gd`, `AI.DEFAULT` / `PRESETS`, `ai_goals` / `ai_tile` in `objectives.gd`). Difficulty comes from map, troops, gold, waves — not from a dumber bot.
- Enemy bot per level: `"ai": "normal"` or `"hard"`. Never `"easy"` (validator rejects it).
- No story keys (`story`, `history`, `tips`, `chapter`, `pos`, `place`, `region`).
- Run Godot through `tools/run_guarded.sh <log> -- <args>`; windowed shots need the Mac display awake.

## Pacing (spec §8)
- Every new thing (unit, terrain, night, win type, effect) goes **see → hold → buy**: enemy has it / it is pre-placed for us → we can buy it a level later.
- No 2 debut levels in a row (m01–m04 tutorial exempt). A debut level is never `hard`. After a `hard` level comes an `easy` / `mid` breather.
- ≤ 3 `reach` levels until the enemy learns to block goals (bot work, later).
- Mix win types: never 3 in a row with the same one.
- Table of what each level introduces: `docs/content.md` § "Nhịp ra mắt".

## Recipe (sim/level_recipes.gd, one dict per level)
| key | meaning |
|---|---|
| `id` `title` `order` | `gNN`, short Vietnamese name (a place), slot between neighbours |
| `tier` `ai` | `easy`/`mid`/`hard` (provisional until sims), `normal`/`hard` |
| `w` `h` | 11–16 × 8–12 like the hand-made maps; **odd** `w` (river `v`) / odd `h` (river `h`) keeps sym rivers one tile wide |
| `castles` | `{p, e}` counts (0 = castle-less side: rout / reach / survive maps) |
| `villages` `own_villages` | total villages; how many nearest each side owns at start |
| `river` `bridges` | `none` / `v` / `h`; bridges along it |
| `rough` | share of open land as forest / hill / mountain (~0.3) |
| `temples` | 0–2 in the middle band |
| `sym` | 180° symmetric (fair duels); needs equal castles + identical `start` |
| `win` | as DEF (`castles`, `rout`, `hero`, `survive` + `turns`, `reach` + `turns`; reach goal auto-placed east if no `at`) |
| `allowed` `gold` `unitCap` `night` `newUnits` | as DEF |
| `start` | `{p: [types], e: [types]}` placed by the castle / west / east edge; `hero` first |
| `waves` | `[{turn, units: [types]}]` spawned on the east edge |
| `stars` | provisional bar; reset from sims |

## Loop
1. Write / edit the recipe.
2. `godot --headless --path . -s sim/levelgen.gd -- recipe=<id> seeds=12 out=<dir>` → candidates, best score first (score: village balance, bare castles, walking distance). `error` / `invalid` lines = rejected seeds.
3. Look before picking: install the top 2–3 one at a time and shoot them (`-- mission=<id> fresh nointro profile=test shots=<dir> quit_at=4`), Read the PNGs. Reject: roads not joining, castle in the open, river with no crossing near the action, map that copies a neighbour.
4. `godot --headless --path . -s sim/levelgen.gd -- install=<dir>/<id>_s<seed>.gd`, then `gdscript-formatter --max-line-length 150 --blank-lines-around-definitions 1 content/levels/<id>.gd`, `godot --headless --path . --import`, `tools/lint.sh`, tests (`sim/tests.gd`, "content valid: <id>" runs every level).
5. Calibrate: `TEMP=<dir> bash tools/sim_many.sh "<ids>" 12 4` → `p X/12` = our bot's wins vs the level's enemy bot.
   - Tier bands (spec §9): `easy` ≥ 80 % · `mid` 55–80 % · `hard` 30–55 %. Outside every band → change gold / start troops / waves, re-sim.
   - Median turns 8–25; longer → fewer enemy troops / waves or a smaller map.
   - Stars: `turns` = median win turn (`win: turns med`), survive maps `lost` = median troops lost.
6. Commit per ~5 levels: `content: levels gNN–gMM`.

## Done means
Lint ok, tests green, click driver `fails=0`, every level in its tier band (sims logged in the commit or HANDOFF), pacing table updated.
