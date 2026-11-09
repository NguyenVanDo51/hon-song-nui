# Shared rules for every unit's attack demo (svg-attack-anim skill)

## Shared hit effect (identical for every unit; only `dmg` differs)
Paste these two constants at the top of every `<type>.spec.js` and route EVERY damaging contact through them:
```js
// shared impact: same for all units (game-wide hit feel)
const HIT = { stop: 90, amp: 9, kx: 420, debris: 'spark', n: 8, sparkColor: '#ffe08a', cut: true, cutAng: -24 };
const HIT_SMALL = { small: true, stop: 45, amp: 4, kx: 0, debris: 'spark', n: 3, sparkColor: '#ffe08a', cut: false };
// main hit:   api.hit(Object.assign({}, HIT, { dmg: 42 }))     or  wave/projectile/tornado { hit: Object.assign({}, HIT, { dmg: 42 }) }
// multi-tick: Object.assign({}, HIT_SMALL, { dmg: 6 }) for the small ticks before the final HIT
```
The attack's own VFX (wind, fire, water, sound rings...) may differ per unit; the moment of impact on the target must look the same everywhere.

## Art style (redraw = same chibi family, rig-ready)
- viewBox="0 0 256 256" width/height 256; feet/base near y≈236–246; facing RIGHT; chibi (big head, small body), visual size like the current set.
- One outline group `<g stroke="#2b2220" stroke-width="7" stroke-linejoin="round" stroke-linecap="round">`; flat fills + one shade tone; no gradients/filters/text/raster.
- Palette: outline #2b2220, skin #f3cfa6 (blush #f09a88), dark cloth #5a4a3c / #3a2e28, metal #cdd4da / #aab3bd, gold #e2c36e, wood #a87a4c.
- Team colours (setting v2, 2026-11-09, docs/setting.md): ours (`_p`) blue #4f74c9 + shade #32508f + gold trim #e2c36e; enemy (`_e`, the Demon Lord) wine red #8c1f3a + night purple #3d1238 + violet trim #a77bd6. `_e` = `_p` with ONLY these three colours swapped (`TEAM_SWAP`, except the two commanders, which are different characters).
- Setting: generic fantasy (docs/setting.md) — one empire split in two; for normal units the enemy look is just the colour swap, so keep headgear neutral.
- Rig-ready: draw each part that will move (head, torso, each arm, weapon separate from the hand, legs, tail/cape/plume) as its own contiguous block of elements, in a clean draw order, so it can be cut into parts verbatim.

## Files (per unit type <type>)
- art (overwrite, keep the existing .import files): assets/units/styles/chibi/<type>_p.svg, <type>_e.svg
- demo: docs/anim_demo/<type>.html, spec: docs/anim_demo/<type>.spec.js, notes: docs/anim_demo/<type>.notes.html (Vietnamese, 2–4 lines)
- build: `python3 ~/.claude/skills/svg-attack-anim/scripts/build.py --spec docs/anim_demo/<type>.spec.js --full assets/units/styles/chibi/<type>_p.svg --out docs/anim_demo/<type>.html --target assets/units/styles/chibi/soldier_e.svg --tile assets/terrain/chibi/grass_a.svg --notes docs/anim_demo/<type>.notes.html`
- range = the unit's real attack range in scripts/core/rules.gd (melee 1; archer use 2; catapult use 3).
