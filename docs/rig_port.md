# Rig port guide (Phase B: one unit per agent)

Status 2026-11-06: all 11 types ported (hero + 10) (`scripts/ui/rig/specs/*.gd`). Known shared-runtime gaps: smear widens on dir=down; same-row `mid` layer can draw over attacker (boat repaints paddle); `back` ring of shaman over feet on dir=down; token frame −1 faces default before turn-to-target; target white flash weaker than demo.

Attack demos `docs/anim_demo/<unit>.spec.js` -> real-time skeletal rig on the 2D board. Reference port = commander (`hero_p` / `hero_e`): `scripts/ui/rig/specs/hero.gd`.
Never edit `docs/anim_demo/*` or `assets/units/styles/*`.

## Files
| what | where |
|---|---|
| exporter (spec.js -> JSON) | `tools/rig_export.mjs` |
| exported data | `assets/units/rig/<spec>.json` (all 12 already exported) |
| data + tracks + part SVG | `scripts/ui/rig/rig_data.gd` (`RigData`) |
| runtime: pose, springs, target physics, api | `scripts/ui/rig/rig.gd` (`Rig` = the JS `api`) |
| built-in VFX ports | `scripts/ui/rig/rig_fx.gd` (`RigFx.*`) |
| world -> board px mapping | `scripts/ui/rig/rig_cam.gd` (`RigCam` = the JS `cam`) |
| Canvas2D look-alike | `scripts/ui/rig/rig_ctx.gd` (`RigCtx` = the JS `ctx`) |
| per-unit functions | `scripts/ui/rig/specs/<unit>.gd` (extends `RigSpec`) |
| registry | `scripts/ui/rig/rigs.gd` (`Rigs.SPECS`) |
| game hook | `FX.rig_attack` (fx.gd), `Board._draw_units` / `_pose` (board.gd), `GameScreen.play` "hit" |

## Steps per unit
1. Re-export only if the spec changed: `node tools/rig_export.mjs <unit>` (or `--all`).
2. Check track parity (must be identical except half-rounding of negatives at the 4th decimal):
   `bash -c 'T=0,35,160,290,500,1000; diff <(node tools/rig_export.mjs --sample <unit> <attackId> $T) <(godot --headless --path . -s sim/probes/rig_parity.gd -- <unit> <attackId> $T 2>/dev/null | grep "^[0-9]")'`
3. Write `scripts/ui/rig/specs/<unit>.gd` (`extends RigSpec`), porting 1:1 from the JS:
   - `ev` -> `func events(r: Rig) -> Array` returning `[[t_ms, func(a: Rig) -> void: ...], ...]`
   - `springs.X.drive` -> `func drive(name, p, vx, ctx) -> float` (switch on `name`; `ctx.idle`, `ctx.clock`)
   - `idle` -> `func idle(p, b, clock)` (rest checks only; game shows the token between attacks)
   - `order(p, list)` -> `func order(p, list) -> Array` (only called when JSON `hooks.order` is true)
   - attack `draw(ctx, cam, api, layer, t)` -> `func draw(ctx: RigCtx, cam: RigCam, r: Rig, layer: String, t: float)`
   - module-level helper fx (`function fooFx(api){ return api.add({upd, draw}) }`) -> a static func or inner class in the same file; `r.add({ "upd": func(s, ms) -> bool: ..., "draw": func(ctx, cam, layer) -> void: ... })` or an object with `upd(s, ms) -> bool` + `draw(ctx, cam, layer)`.
   - channels listed in JSON `attacks[].sampled` (JS `track + wobble` combos) are exported as 5 ms linear samples: fine as is; override `channels(p, t, attack)` only if it must be exact.
   - numbers/colours/timings: read `data.consts` (every plain top-level JS const, evaluated, incl. `bake()` results; tracks as `{track: keys}`, sample with `RigData.sample(RigData.keys_of(c.X.track), t)`).
4. Register: one line in `Rigs.SPECS`: `"<type>": { "script": "res://scripts/ui/rig/specs/<unit>.gd", "p": "<unit>", "e": "<unit>" }` (same name both sides = enemy gets the team-colour swap `#c9503f->#4f74c9`, `#93362b->#32508f`).
5. Test (below). Units without an entry keep `FX.attack`; so does `Board3D`.

## JS -> GDScript api
| JS | GD |
|---|---|
| `api.hit(Object.assign({}, HIT, {dmg}))` | `a.hit(Rig.with(Rig.HIT, { "dmg": d }))` (`Rig.HIT_SMALL` for ticks) |
| `api.wave({...})`, `projectile`, `tornado`, `ring`, `shockwave(x, y, o)` | same names, Dictionary args, same keys (`"hit"`, `"onArrive"`, `"drawShape"` = Callables) |
| `api.gleam(pt, ms)`, `dust/leaves/sparks(x, y, n, ...)`, `burst`, `cut`, `number` | same |
| `api.shake(amp, ms)`, `stop(ms)`, `flash(color, ms)` | same (`flash("#f4fcff", 50)`) |
| `api.point(name)` -> `{x, y}` | `a.point(name)` -> `Vector2` (world). Board px exactly as drawn: `a.point_px(name)` |
| `api.hero()`, `api.target()` | Dictionaries, same keys (`target().front` = real `T_FRONT`) |
| `api.t`, `api.clock`, `api.pose` | `a.t`, `a.clock`, `a.pose` |
| sound (new) | `a.sound("slash" / "arrow" / "rock" / "orb" / "hit" / "heavy")` at the swing / release; hits play their own |
| `ctx.setTransform(cam.translate(x, y).rotate(deg).scale(s))` | `ctx.set_xf(cam.frame(x, y).rotated_local(deg_to_rad(deg)).scaled_local(Vector2(s, s)))` |
| `ctx.setTransform(cam)` + world coords | `ctx.set_world()` (per-point weight) or `ctx.set_world(0.0)` hero-attached / `ctx.set_world(1.0)` target-attached |
| `ctx.setTransform(cam.translate(p.x, p.y))` for a character point | `ctx.set_xf(Transform2D(Vector2(cam.ca, 0), Vector2(0, cam.ca), a.point_px(name)))` |
| `beginPath moveTo lineTo quadraticCurveTo bezierCurveTo arc ellipse closePath rect` | `begin_path move_to line_to quad_to bezier_to arc ellipse close_path rect` (+ `circle`) |
| `ctx.fillStyle = c; ctx.fill()` / `strokeStyle, lineWidth; stroke()` | `ctx.fill(c)` / `ctx.stroke(c, width)` (c = Color or "#hex") |
| `ctx.globalAlpha = a` | `ctx.alpha = a` (reset to 1 after) |
| `fillText` | `ctx.text(x, y, s, size, fill, ink, outline, scale)` (never mirrored; keep `size` fixed, animate `scale`) |
| `drawImage(svg)` (ghost afterimage) | `Token.raster("res://assets/units/styles/chibi/<unit>_<side>.svg", px)` + `ci.draw_texture_rect` under `ctx.ci` |

## Coordinate mapping (RigCam)
- Spec world unchanged: hero tile x 0..256, ground y = `feet`, target tile at `TX = 256 * real distance` (Euclidean tiles: archer diagonal = 362), `T_FRONT = TX + targetFront`. Hit tests (`x >= front`) stay in world units -> spec timings identical to the demo at the demo range.
- Board px from two upright frames, blended per point by weight w:
  - H (w = 0): origin attacker feet, x = facing f, scale `ca` = attacker token px per art unit (`T * 0.74|0.66 * 1.12 / 256`, same as `Token._standee` -> token <-> rig swap is seamless).
  - G (w = 1): origin target feet, x = real attack direction u, scale `cd` = target token scale.
  - y always screen-vertical: art, tornado, numbers, gravity stay upright. Horizontal attacks: H, G parallel (only the token-vs-tile gap differs).
  - default w for bare world x: ramp from `cx + 64` to `xt - 64` (hero front -> target front). Particles keep the w they spawned with. Wave / projectile: own w 0 at launch -> 1 at impact (start exactly at the drawn point, end exactly on the target token). Directional shapes use `cam.aimed(at, dir, k)` (wave crescent turns to the real direction).
- Character: drawn upright, mirrored when f = -1 (target left; pure up/down keeps the unit's current facing). Root `x`/`y` channels move it along u (lunge / leap goes at the real target).
- Target = the normal board token; the rig's target physics (`tgt.ox` knock along u, lift, squash, spin, flash) reach it via `FX.rig_target_pose` -> `Board._pose`.

## Layers / z-order
- character + smear: in `Board._draw_units` y-order, replacing the attacker's token (hp bar, stars kept).
- `back`: just before the target token; `mid`: just after it (tornado halves wrap the target); `front`: fx over-layer (above all units). Flash: full board, top layer. All under the night overlay, like every other unit/FX.

## Damage rule (game)
- Exactly ONE non-small HIT per attack (SHARED.md `HIT`). That hit shows the REAL `amount` (gold on kill), plays hit/heavy, calls `on_hit` (hp bar drops). `HIT_SMALL` ticks: no number. Spec `dmg` values are ignored.
- Every damage path must go through `a.hit` (wave/projectile `"hit"`, tornado tick/final, target landing). If the attack never reaches a HIT, `FX.rig_attack` applies the damage at the end — the smoke probe flags that (`HIT at -1 ms`).
- Counter-attack = the defender's own rig at `Rigs.COUNTER_SPEED` (1.25x). Die event plays after, as before.
- Time: `FX.speed` (x1/x2/x3, enemy fast-forward x4) scales everything incl. hit-stop; read live each frame.

## Test
1. Parity: step 2 above.
2. Contact sheet on the real board (windowed) vs the demo sheet at the same times:
   - `godot --path . --resolution 1280x720 -s sim/probes/rig_sheet.gd -- mission=m02 fresh nointro nobattle profile=test out=/tmp/x/<unit>_board.png unit=<type> side=p dir=right dist=<range> times=-1,0,t2,t3,t4,t5`
   - `python3 ~/.claude/skills/svg-attack-anim/scripts/snap.py sheet docs/anim_demo/<unit>.html /tmp/x/<unit>_demo.png "<attackId>:0,t2,t3,t4,t5"`
   - `-1` = plain token frame: must match frame `0` (seamless swap). Also run `dir=left|up|down` (+ `ur`/`dl`, `dist=2` for ranged), `side=e` (colour swap).
3. Real exchange (zoom, hp drop, counter): `godot --path . --resolution 1280x720 -s sim/probes/rig_live.gd -- mission=m02 fresh nointro nobattle profile=test out=/tmp/x/live.png att=<type> def=<type> every=280 n=16` (`mission=m05` = night).
4. Smoke, every registered rig x 2 sides x 6 directions: `MAX_SEC=300 tools/run_guarded.sh /tmp/rig_smoke.log -- --headless --path . -s sim/probes/rig_smoke.gd -- mission=m02 fresh nointro nobattle profile=test speed=3` -> `RIG SMOKE DONE ... fails=0`, `grep -c "SCRIPT ERROR" /tmp/rig_smoke.log.err` = 0.
5. Regression: `sim/tests.gd`, click driver, windowed bot (README). `norig` flag = old FX.attack everywhere (A/B check).

## Pitfalls
- `ease()` is a GDScript built-in: unqualified `ease(...)` inside RigData silently calls it. Use `RigData.ease_i` / `ease_by_name`.
- `var x := dict.y` / `arr[i] * k` -> "Cannot infer the type" parse error. Type it: `var x: float = ...`.
- JSON numbers are floats: cast `int(...)` for loop counts / `%d`.
- Degrees vs radians: `ctx.arc/ellipse` radians (like canvas); JS `.rotate(deg)` -> `rotated_local(deg_to_rad(deg))`; `rotate(q.rot * 57.3)` = `rotated_local(q.rot)`.
- Multiline lambdas inside `[...]`: keep the body indented deeper than the line that opens it; closing `]` at the end of the last statement (see hero.gd).
- Attack `draw` must stay stateless (pure function of `t`): `Rig.seek` (sheets) never calls it while stepping. One-shot state -> `a.add(...)`.
- Fills: RigCtx triangulates and falls back to a fan for self-intersecting outlines (Godot's `draw_colored_polygon` would drop them and print errors). Swept bands -> quads like `Rig._strip`.
- Text: never animate font size (glyph cache per size never frees); fixed size + `scale`.
- One full-screen `flash` per attack max; `shake` amp is world units (scaled to the board).
- No OS / desktop-only APIs (web build). New data files must match `include_filter` in `export_presets.cfg` (`assets/units/rig/*.json` already added).
- Ghost spec reads `__SVG.full` through `new Image()`: the exporter stubs it; the port draws the full token SVG via `Token.raster`.
