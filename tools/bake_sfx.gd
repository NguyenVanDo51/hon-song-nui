extends SceneTree
## renders every Audio recipe (SFX + music notes) into assets/sfx/<key>.wav, 22.05 kHz 16-bit mono.
## run: godot --headless --path . -s tools/bake_sfx.gd     then once: godot --headless --path . --import
## Fixed noise seed, so re-baking unchanged recipes gives identical files.

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(Audio.DIR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var all := Audio.recipes()
	var keys := all.keys()
	keys.sort()
	var bytes := 0
	for key: String in keys:
		var pcm := Audio._render(all[key][0], all[key][1], rng)
		var path := Audio.file_of(key)
		var err := Audio.to_stream(pcm).save_to_wav(path)
		if err != OK:
			push_error("bake_sfx: %s -> error %d" % [key, err])
		if not FileAccess.file_exists(path + ".import"):
			# import as plain PCM (the default, QOA, is lossy); the importer keeps these params
			var f := FileAccess.open(path + ".import", FileAccess.WRITE)
			f.store_string("[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n[params]\n\ncompress/mode=0\n")
			f.close()
		bytes += pcm.size()
	print("bake_sfx: %d sounds, %.1f s of audio -> %s" % [keys.size(), bytes / 2.0 / Audio.SR, Audio.DIR])
	quit()
