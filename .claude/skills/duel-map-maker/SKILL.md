---
name: duel-map-maker
description: Use when adding, redrawing or fixing a 1 đấu 1 (duel / skirmish) map in Công Thành Chiến (content/skirmish_maps.gd) — or when a duel feels slow, one seat wins too often, or a castle in the middle decides the game.
---

# Duel map maker (Công Thành Chiến)

Maps = `content/skirmish_maps.gd` `MAPS` (`name`, `blurb`, `rows`, `owner`, `units`), used by 1 đấu 1 **and** by every bot sim (`sim/tune.gd`, `army_probe`, `sim/trace.gd` golden). Format + terrain letters: `docs/content.md` § "Bản đồ đấu tự do". AE2 start: each side = 1 commander alone on its home castle.

## Hard rules (user 2026-11-09)
1. **Easy to move, short games.** Water ≤ 33 %; home castle → enemy home ≤ 5 foot turns; ≥ 3 ways across the middle, ≥ 2 of them land / bridge (wading costs 3 and boats in a river get +15 atk / +25 def → a river with one bridge is a wall). No island ring that forces a detour.
2. **No contested castle.** No castle on the centre tile and no neutral castle the two homes reach in about the same time: whoever moves first takes it, buys units in the middle of the map and wins. Neutral castles only as a mirrored pair, each ≥ 1 foot turn nearer one home — or none.
3. **Fair.** 180° symmetric (terrain, `owner`, `units`); 8–10 villages, 2 owned by each home at start.

## Loop
1. Draw `rows` (11–16 × 8–12). Edit both a tile and its 180° twin `(w-1-x, h-1-y)` — the twin of a road tile may be a village you just deleted. Script it: build the top half, append the rotated rows.
2. `python3 tools/map_check.py <id>` → must print `map_check: ok` (symmetry, water, home → home turns, contested castles; exit 1 otherwise). `WARN tied village` = both homes walk there on the same whole turn → the first mover gets it.
3. Sim, bot both sides, **192 games** (48 is noise: one tile edit swung p 24 → 42 / 48): `godot --headless --path . -s sim/sim.gd -- skirmish 192 normal <id>`.
   - `p X/192` in 77–115 (40–60 %). Outside → fix the `WARN tied village`s first: move each tied village so one twin is a whole turn nearer each home (cua_bien: one tied pair moved, p 147 → 112 / 192).
   - `turns med` not longer than before the redraw. Bot games run 19–29 turns and barely react to terrain edits; the user's own playtest judges pace.
   - Sims never prove rule 2 (the bot does not rush castles) — the check in step 2 does.
4. Regenerate the golden trace (map change = new games): `godot --headless --path . -s sim/trace.gd 2>/dev/null | grep -E '^[a-z0-9_]+ [0-9]+ ' > sim/golden.txt`; only the `sk_<id>` lines should change.
5. `blurb` changed → `python3 tools/i18n_extract.py`, translate `locale/en.po` (`docs/i18n.md`); `tools/lint.sh`; tests `sim/tests.gd` (map symmetry test included).
6. Same commit: one line per map in `docs/content.md` § "Bản đồ đấu tự do" (what changed, `map_check` + sim numbers before → after). Bot win-rate tables in `docs/ai.md` measured on old maps are then stale — say so there.

## Common mistakes
| Mistake | Fix |
|---|---|
| Fixed one half only | Generate the bottom half by rotating the top half |
| Village count dropped | The 180° twin of the tile you opened was a village |
| Centre castle "for action" | Rule 2: mirrored pair nearer each side, or none |
| Sim looks fine, so the map is fine | Bots ignore castle races and play slower than people; rules 1–2 are checked statically |
| Steering by a 48-game sim | 192 games; at 48 the seat score swings ±8 from seed noise |
| Removing a middle castle and nothing else | Fights then start later: open a lane (mountain → hill) or widen the crossing it fed |
| Many bridges, all in one corner | Spread crossings so both flanks and the centre can be used |
