# Hướng dẫn + Nhiệm vụ + Popup cảnh diễn — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** step-locked tutorial levels t01/t02, quest list on chosen levels (panel A+B top-right, star penalty), unit-intro popup = animated mini scene instead of text card.

**Architecture:** pure core `scripts/core/quests.gd` (quest list per level, progress in `s.quests`, fed by Game events from the UI) → UI parts `quest_panel.gd` (HUD), `tutorial.gd` (overlay + input lock), `intro_stage.gd` (popup scene). Bot / AI untouched; `game.gd` untouched (1000-line cap).

**Tech Stack:** Godot 4.7 GDScript, headless tests `sim/tests.gd`, gdlint (`tools/lint.sh`).

**Spec:** `docs/superpowers/specs/2026-11-07-tutorial-quests-design.md` (read it; § numbers below refer to it).

## Global Constraints
- NO edits: `scripts/core/ai.gd`, `ai_plan.gd`, AI presets, `objectives.gd` ai hooks, `scripts/core/game.gd` (at 1000-line gdlint cap).
- `sim/golden.txt`: existing lines byte-identical. New t01/t02 lines may be appended (regen: `godot --headless --path . -s sim/trace.gd > sim/golden.txt`, then `git diff` must show only added lines).
- All Godot runs: `MAX_SEC=180 tools/run_guarded.sh <log> -- --headless --path . -s <script>`. Godot binary: `godot`.
- Gates per task: `tools/lint.sh` clean; `sim/tests.gd` exit 0; tasks touching UI also `sim/click_driver.gd -- mission=m02 fresh nointro` fails=0.
- Display text via `content/theme.gd` `text` (Vietnamese). Comments: 1 line, why-only.
- Strict typing repo-wide (read Dictionary fields into typed vars, see README "Kiểu chặt").
- Quests only when `ctx.kind == "campaign"`; skirmish / duel / hotseat: no `s.quests` entries, no penalty.
- Repo CLAUDE.md: any tech debt seen -> 1 line in `docs/TODO.md` § "Nợ kỹ thuật".

## Review Focus
1. Old save resumed mid-level (no `s.quests` key) → quests initialised fresh, no crash, no penalty surprise. Test in Task 1.
2. Heal happens during `Game.end_turn` of the enemy (start of our turn) → `heal_on` still credits side `p`. Test in Task 1.
3. Our unit kills an attacker by **counter-attack** on the enemy's turn → `kill_with` / `kill_type` credit `p`. Test in Task 1.
4. t02 soldier must not die before the heal steps finish (soft-lock). Fix by design: t02 has **no enemy units** (`units` only p, `gold.e 0`, `allowed.e []`, enemy castle only; `loss_reason` keeps a castle-holding side alive, game.gd:889). Test in Task 4: e has 0 units, e not lost after `Game.end_turn` ×2.
5. Tutorial lock never leaves zero legal clicks (every step's `point` is in its `allow`, and its quest is completable from the start position). Test in Task 4.

---

### Task 1: Core quests (data, progress, stars)

**Files:**
- Create: `scripts/core/quests.gd` (`class_name Quests`)
- Create: `sim/tests/quests.gd` (suite `quest_tests`), register in `sim/tests.gd`
- Modify: `content/guide.gd` (add `DEBUT`), `content/theme.gd` `text` (quest templates + `star_quests`), `scripts/core/stars.gd`, `scripts/ui/turn_driver.gd` `finish()` (use `Stars.final`)

**Interfaces (Produces):**
- Quest dict: `{ "do": String, "what": Variant (unit type | tile char | null), "n": int, "text": String (optional override) }`. State entry adds `"have": int, "done": bool`.
- `Quests.VERBS` registry like `Objectives.TYPES`: verbs `select move end_turn capture stand_on attack_with kill_with hit_type kill_type buy heal_on repair raze raise` (§6.1 table; `what` = our attacker for `attack_with`/`kill_with`, enemy target for `hit_type`/`kill_type`).
- `static func for_level(def: Dictionary) -> Array` = `def.quests` + DEBUT for each `def.newUnits` type (skip if `def.has("tutorial")`; skip duplicates; `attack_with` → `kill_type` when type not in p's start units nor `allowed.p`). Win line NOT included.
- `static func init_state(s: Dictionary, def: Dictionary) -> void` → `s.quests` (copies with `have 0, done false`).
- `static func observe(s: Dictionary, ev: Array) -> Array` → indexes newly done. Counts only side `"p"`. Kill credit = attacker of the last `hit` whose `id` == `die.id` (covers counters). `stand_on` = last tile of a `move` path of a `p` unit. `heal_on` = `heal` event, unit side from `Game.unit_by_id`, tile from event x/y.
- `static func note(s: Dictionary, verb: String, what: Variant) -> Array` → for UI-only verbs `select`, `buy`, `end_turn`.
- `static func text(q: Dictionary) -> String` (template `quest_<verb>` + names from theme).
- `static func done_count(s: Dictionary) -> int`, `static func total(s: Dictionary) -> int`.
- `static func feasible(def: Dictionary, q: Dictionary) -> String` ("" = ok, else reason).
- `Stars.final(s: Dictionary, def: Dictionary) -> int` = `count` minus 1 if won and any quest not done, min 1; 0 if not won. Missing `s.quests` = no penalty.
- `Stars.check` appends a 4th goal `{ key: "quests", penalty: true, ok: all done, have: d, need: t, text: "Nhiệm vụ d/t" }` only when `s.quests` non-empty; `count` ignores `penalty` goals; Task 3's end card renders it as a red minus row, star total = `Stars.final` (never 3 ✓ with 2 ★).
- No `STATE_V` bump: lazy init in `GameScreen.start` (Task 3) covers old saves.
- `Guide.DEBUT` (in `content/guide.gd`): `{ soldier: move, hero: move, archer/wolf/elephant/bird/boat/catapult/shaman/drum: attack_with <self> }`; `ghost` absent. No terrain entries (§6.2, user).

- [ ] **Step 1: Write failing tests** in `sim/tests/quests.gd` (use `blank()` / `mission()` from test_base):
  - `for_level`: m02 (`newUnits [archer]`, archer in `allowed.p`) contains `{do attack_with, what archer}`; m04-like def with `newUnits [elephant]` and no p elephant → `{do kill_type, what elephant}`; def with `tutorial` key → no DEBUT.
  - `observe`: p archer hits e soldier → `attack_with archer` done, returns `[i]`; same event for side e → not done.
  - counter kill (Review Focus 3): e soldier attacks p soldier with p hp high, e hp 1, `Game.fixed_roll` set → `kill_with` (null) done.
  - heal (Review Focus 2): p unit hp 50 on p village, `Game.end_turn` twice → events contain `heal`; `observe` → `heal_on v` done.
  - `note(s, "buy", "archer")` completes `buy archer`; `note(s,"buy","soldier")` does not.
  - `Stars.final`: won + 1 quest open + 3 base stars → 2; won + base 1 + open → 1; no `quests` key → equals `Stars.count`.
  - Old save (Review Focus 1): state without `quests` → `Quests.done_count(s) == 0`, `Quests.total(s) == 0`, no error.
- [ ] **Step 2:** run `MAX_SEC=180 tools/run_guarded.sh t.log -- --headless --path . -s sim/tests.gd` → new tests FAIL (Quests undefined).
- [ ] **Step 3:** implement `quests.gd`, `DEBUT`, theme templates (e.g. `quest_attack_with: "Đánh bằng {unit}"`, `quest_kill_type: "Hạ 1 {unit}"`, `quest_capture: "Chiếm 1 {tile}"`, `quest_buy: "Mua 1 {unit}"` / any: "Mua 1 quân", `quest_select: "Chọn {unit}"`, `quest_end_turn: "Hết lượt"`, `quest_stand_on: "Đứng vào {tile}"`, `quest_heal_on: "Hồi máu ở {tile}"`, `quest_repair: "Sửa làng hỏng"`, `quest_move: "Đi {unit}"`, `quest_kill_with`, `quest_hit_type: "Đánh {unit}"`, `quest_raze`, `quest_raise`), `Stars.final`; `turn_driver.finish` uses `Stars.final` for the recorded star count.
- [ ] **Step 4:** tests PASS; golden unchanged (`git diff sim/golden.txt` empty); lint clean.
- [ ] **Step 5:** commit `feat(quests): core quest list, progress from game events, star penalty`.

### Task 2: Unit intro popup = mini scene (independent of Task 1)

**Files:**
- Create: `scripts/ui/intro_stage.gd` (`class_name IntroStage extends Control`)
- Modify: `scripts/ui/game_cards.gd` `intro_card()` body (keep `intro_new_units` timing + `seen_units` logic)
- Probe: `sim/probes/intro_shot.gd` (renders the stage for every unit type at 3 timestamps → PNG contact sheet)

**Interfaces:**
- `IntroStage.setup(side: String, type: String, hero_key: Variant) -> void`; `IntroStage.play() -> void` (awaitable, ≤ ~4 s); signal `finished`.
- Card content (§8): eyebrow (existing `introUnit*`/`introHero*` text), name, stage (6 plains tiles, real terrain art), stat icon row `⚔ atk 🛡 def 👣 mv 🎯 range` (`Icons`), buttons `↻ Xem lại` (replays `play()`) + `Đã hiểu` (Space/Enter). Remove role / desc / traits / "Cách dùng" from the card.
- Script derived from `Rules.UNITS[type]` flags only, no per-name branches: move tiles = `mv` (clipped), `siege` → move, fade "next turn", then shoot; `rmax > 1` → yellow range frame `rmin..rmax`, ranged shot (`shot`), 🚫 where the counter would be; melee → small counter hit; damage number floats; `poison` → two red chips `⚔ −N 🛡 −N` on the target. Attack anim via existing rig runtime `scripts/ui/rig/` (see `docs/rig_port.md`); dummy target = enemy-side `soldier`. No aura / raise / water / flying / mountain tricks.

- [ ] **Step 1:** write probe `sim/probes/intro_shot.gd` (base: `sim/probes/probe_base.gd`, pattern: `units_shot.gd`/`rig_sheet.gd`) saving `shots/intro_<type>.png` for all 11 types; run → fails (no IntroStage).
- [ ] **Step 2:** implement `IntroStage` + new `intro_card` body.
- [ ] **Step 3:** run probe; open PNGs (Read tool) and check: unit visible, target visible, range frame on archer/catapult, poison chips on wolf, no text block. Fix until right.
- [ ] **Step 4:** tests + lint + `click_driver -- mission=m02 fresh` (intro ON: driver passes the card via its button) fails=0.
- [ ] **Step 5:** commit `feat(intro): new-unit popup plays a move + attack scene instead of a text card`.

### Task 3: Quest panel (HUD) + end card row (needs Task 1)

**Files:**
- Create: `scripts/ui/quest_panel.gd` (`class_name QuestPanel extends Control`)
- Modify: `scripts/ui/game_hud.gd` (drop `_goal` slip top-left — fix `place_hud` uses of `_hud_tl` width / `card_terrain` yield; mount panel under `hud_tr`; `place_hud` hides it whenever `btn_end` hides, and when a tile card takes the top-right corner), `scripts/ui/game_screen.gd` (`start`: `Quests.init_state` when campaign and `not s.has("quests")`; `commit` / `buy_unit` / select / end turn → `Quests.observe` / `note` → `hud.quests.celebrate(idx)`), `scripts/ui/turn_driver.gd` (feed AI-turn + end_turn events to `Quests.observe`), `scripts/ui/game_cards.gd` `show_end` (row `Nhiệm vụ d/t`, red when short)
- Probe: extend `sim/probes/hud_shot.gd` (1280x720, 1500x675, 960x720)

**Interfaces:**
- Consumes: Task 1 `Quests.*`, `s.quests`.
- End card: `HudWidgets.end_stars` takes star total from `Stars.final`; `penalty` goal row drawn red with "−1 ★" when not ok.
- `QuestPanel.bind(s: Dictionary, win_line: String) -> void`; `refresh() -> void`; `celebrate(indexes: Array) -> void` (✓ stamp centre 0→1.6→1, flies to panel, row strikes, advance; input not blocked > 0.8 s; sfx existing UI click); `set_covered(on: bool) -> void` (alpha 0.2 + `MOUSE_FILTER_IGNORE`).
- Collapsed: `📜 <first not-done quest | win line>  d/t`; tap → full list (✓ strike / ▢ / ★ bold win line), auto-collapse 4 s. Non-campaign: only win line.
- Covered test (B): panel rect intersects a unit tile, hovered tile, reach tiles or path → `set_covered(true)`.

- [ ] **Step 1:** probe shots: panel collapsed, expanded, covered (unit under it), at 3 sizes; run → fails.
- [ ] **Step 2:** implement; wire events.
- [ ] **Step 3:** view PNGs: panel top-right under ⏩⚙, never under the turn/gold slip; hidden with a unit selected; faded when covered.
- [ ] **Step 4:** tests + lint + click_driver fails=0.
- [ ] **Step 5:** commit `feat(hud): quest panel top-right (collapsed line, fades when covering the board), end card quest row`.

### Task 4: Level content — quests on m01–m04 / m10, levels t01 / t02 (needs Task 1)

**Files:**
- Create: `content/levels/t01.gd` (`order` 1), `content/levels/t02.gd` (`order` 2)
- Modify: `content/levels/m01.gd` (`newUnits` → `[]`, add `quests`), `m02.gd`, `m03.gd`, `m04.gd`, `m10.gd` (`quests`), `docs/content.md` (fields `quests`, `tutorial`, sims treat quests as done, pacing table +2 rows)
- Test: `sim/tests/quests.gd` (add `quest_content_tests`), `sim/golden.txt` (append only)

**Interfaces:**
- Hand quests (§6.4): m01 `move hero`, `capture v`, `attack_with soldier`, `kill_with null`; m02 `buy archer`, `capture c`; m03 `heal_on v` (or `c` if no village reachable early); m04 `buy drum`, `hit_type hero`; m10 `repair`.
- `"tutorial": [{ "q": int (index into def.quests), "point": [x, y] | "end_turn" | "buy:soldier", "allow": Array ([x, y] tiles and/or "end_turn" / "buy:<type>"), "say": String (optional, ≤ ~6 words except village line) }]`.
- t01 (≈9×7, rules of `docs/content.md` § Bố trí; hero only; 1–2 `guard` enemies low hp; empty village; forest tile near enemy; also a hill `h`; win `rout`; `newUnits ["hero"]`; `stars {turns: N}` passing `Stars.check_def`): quests `select hero`, `capture v`, `end_turn`, `stand_on f`, `attack_with hero`; steps §7 t01 1–5, village say `"Làng: vàng mỗi lượt, đứng trên thì hồi máu"`, step 1 say `"Chọn tướng"`.
- t02 (hero + 1 soldier hp ~40; p castle; p village near; e castle, **no enemy units** (Review Focus 4); win `castles`; `newUnits ["soldier"]`; `allowed.p ["soldier"]`; gold enough for 1 soldier): quests `buy soldier`, `stand_on v`, `end_turn`, `heal_on v`; steps §7 t02.

- [ ] **Step 1:** tests: every quest of every level `Quests.feasible == ""`; every `tutorial` step: `q` valid, `point` ∈ `allow`; t01/t02 `Stars.check_def == ""`; Review Focus 4 (t02: e has 0 units, `gold.e` 0, not lost after 2 end_turns); `Store.unlocked_index`-style check: with only `m05` marked done, t01, t02, m01..m05, m06 open. Run → FAIL.
- [ ] **Step 2:** write levels + quests.
- [ ] **Step 3:** tests PASS; regen golden → `git diff sim/golden.txt` only `+` lines for t01/t02.
- [ ] **Step 4:** commit `content: tutorial levels t01 t02, quests on m01–m04 m10`.

### Task 5: Tutorial runtime (needs Tasks 1, 3, 4)

**Files:**
- Create: `scripts/ui/tutorial.gd` (`class_name Tutorial extends Control`)
- Modify: `scripts/ui/game_screen.gd` (`_on_tile_clicked`, `_unhandled_input`, `buy_unit`, end-turn path: ask `Tutorial.allows(token)` first), `scripts/ui/game_hud.gd` (pause menu: tile `Bỏ qua hướng dẫn` only when `def.has("tutorial")` → `Store.record_result(ctx, "p", 1)` → `main.show_levels(...)`), `scripts/ui/info_panel.gd` if buy buttons need gating, `sim/click_driver.gd` (new scenario `mission=t01` walking the steps)

**Interfaces:**
- `Tutorial.bind(gs: GameScreen, steps: Array) -> void`; `active() -> bool`; `allows(token: Variant) -> bool` (token = `Vector2i` tile, `"end_turn"`, `"buy:<type>"`); `advance() -> void` (called after `Quests` progress; step done when `s.quests[step.q].done`).
- `s.tut_step: int` persisted in state (resume = same step). Lock runs every visit (also replays). Off when `main.flags` has `bot`.
- Overlay: full-screen dim with a round hole on `point` (tile rect via `board.tile_rect`, or the button rect), pulsing gold ring, bouncing 👆, paper bubble with `say`. Clicks outside `allow` swallowed silently (ring flashes). Space/Tab/E/H disabled while active.
- After last step: overlay gone, free play, panel stays.
- ⚙ (`hud.gear`) always clickable during steps (overlay holes it) → pause menu → `Bỏ qua hướng dẫn` reachable. Driver asserts menu opens mid-step.
- Step 1 shows only after the intro popups close (`gs._intro_on == false` / `cards.intro_closed`).

- [ ] **Step 1:** click_driver scenario `t01`: asserts click on a non-hero unit/tile at step 1 does nothing; hero click advances; village; end turn; forest; attack; then reaches free play. Run → fails.
- [ ] **Step 2:** implement `Tutorial` + gates + skip tile.
- [ ] **Step 3:** driver `mission=t01 fresh` + `mission=t02 fresh` fails=0; probe screenshot of step 1 and step 2 (hole on hero / village) → view PNGs.
- [ ] **Step 4:** tests + lint + `click_driver -- mission=m02 fresh nointro` fails=0.
- [ ] **Step 5:** commit `feat(tutorial): step-locked guide (dim + hole + hand + one line), skip in pause menu`.

### Final
- [ ] Whole-branch review; `docs/HANDOFF.md` 1 section; `docs/TODO.md` updates; screenshots for user in `docs/review/tutorial_result.html` (local, not artifact).
