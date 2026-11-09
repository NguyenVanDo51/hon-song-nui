extends SceneTree
## Giới thiệu page shots: title (round buttons fit), credits top + bottom, licences page.
##   godot --path . --resolution 1280x720 -s sim/probes/credits_shot.gd -- profile=test shots=<dir> [tag=x]

var main: Main

func _initialize() -> void:
	var scn: PackedScene = load("res://main.tscn")
	main = scn.instantiate()
	root.add_child(main)
	_run.call_deferred()

func _run() -> void:
	await create_timer(2.0).timeout
	var tag: String = main.flags.get("tag", "cr")
	await main.shot(tag + "_title")
	main.menus.show_credits()
	await create_timer(1.0).timeout
	await main.shot(tag + "_credits")
	var sc := main.menus.page as ScrollContainer
	sc.scroll_vertical = 100000
	await create_timer(0.3).timeout
	await main.shot(tag + "_credits_end")
	main.menus.show_licenses()
	await create_timer(1.5).timeout
	await main.shot(tag + "_licenses")
	sc = main.menus.page as ScrollContainer
	print("licenses page height ", sc.get_v_scroll_bar().max_value)
	quit()
