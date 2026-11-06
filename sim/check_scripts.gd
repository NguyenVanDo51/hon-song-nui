extends SceneTree
## loads every script given (res:// paths) so Godot parses + type-checks them; warnings set to error in
## project.godot [debug] fail here. Used by tools/lint.sh. Exit 1 when any script fails.

func _init() -> void:
	var bad := 0
	var me: String = get_script().resource_path
	for f: String in OS.get_cmdline_user_args():
		if f == me:
			continue # reloading the running script crashes Godot ("Internal script error") and hangs
		if ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE) == null:
			bad += 1
	print("check_scripts: %d failed" % bad)
	quit(1 if bad > 0 else 0)
