extends SceneTree
## screenshots of UI states the click / tutorial drivers don't reach, for docs/design (tools/design_shots.sh ui):
## kingdom-map level card, unit selected + move range, orders popup, ⓘ unit card, enemy threat zone, ⚙ pause menu,
## win + lose end cards (real TurnDriver.finish with a forced winner). Windowed only. Profile "design", never the player's save.
## run: godot --path . --resolution 1280x720 -s sim/design_driver.gd -- shots=<dir> shot_every=100000

var main: Main

func _init() -> void:
	Store.use_profile("design")
	var scn: PackedScene = load("res://main.tscn")
	main = scn.instantiate()
	main.flags["nointro"] = "1"
	main.flags["nozoom"] = "1"
	main.flags["lang"] = "vi" # tools/design_shots.sh passes lang=en for the English set (cmdline wins)
	root.add_child(main)
	_run.call_deferred()

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func snap(name: String) -> void:
	await wait(0.6)
	await main.shot(name)
	print("shot ", name)

func _find_map(n: Node) -> WorldMap:
	if n is WorldMap:
		return n
	for c: Node in n.get_children():
		var f := _find_map(c)
		if f:
			return f
	return null

func _start(id: String) -> GameScreen:
	Store.clear_game()
	var m: Dictionary = Content.level(id)
	main.play_mission(m)
	await wait(1.5)
	return main.game

func _unit(gs: GameScreen, side: String, type: String) -> Dictionary:
	for u: Dictionary in gs.s.units:
		if u.side == side and u.type == type:
			return u
	return { }

func _run() -> void:
	await wait(1.0)
	# kingdom map + level card
	main.show_levels()
	await wait(1.0)
	var wm := _find_map(main)
	if wm:
		wm.select(4)
		await snap("map_card")
	# board states on m07 (many unit types)
	var gs := await _start("m07")
	var hero := _unit(gs, "p", "hero")
	var hx: int = hero.x
	var hy: int = hero.y
	gs._on_tile(hx, hy)
	await snap("unit_selected")
	gs._on_tile(hx + 1, hy - 1)
	await snap("orders_popup")
	gs._clear_sel()
	gs.refresh()
	var cat := _unit(gs, "p", "catapult")
	var cid: int = cat.id
	gs._on_info_requested(cid)
	await snap("info_card")
	gs._on_info_requested(cid)
	var foe := _unit(gs, "e", "elephant")
	if not foe.is_empty():
		var fx: int = foe.x
		var fy: int = foe.y
		gs._on_tile(fx, fy)
		await snap("enemy_threat")
		gs._clear_sel()
		gs.refresh()
	gs.hud.show_menu(true)
	await snap("pause_menu")
	gs.hud.show_menu(false)
	await wait(0.3)
	# end cards through the real finish() path
	gs.s.winner = "p"
	gs.s.reason = "castlesLost"
	gs.turns.finish()
	await wait(1.4)
	await snap("end_win")
	gs = await _start("m07")
	gs.s.winner = "e"
	gs.s.reason = "heroKilled"
	gs.turns.finish()
	await wait(1.4)
	await snap("end_lose")
	quit()
