extends "res://sim/tests/test_base.gd"
## audio tests (run by sim/tests.gd): every played sfx key has file(s), no orphan files, music loops

## every key code plays (audio.play / a.sound / fx._play / menus._sfx) + `page` for UI
const PLAYED := [
	"select",
	"move",
	"slash",
	"hit",
	"heavy",
	"arrow",
	"orb",
	"rock",
	"die",
	"capture",
	"coin",
	"rank",
	"raise",
	"heal",
	"drum",
	"spawn",
	"win",
	"lose",
	"ui",
	"page",
]

func audio_tests() -> void:
	run(
		"every played sfx key has a file or variants",
		func() -> void:
			for k: String in PLAYED:
				var files := Audio.files_of(k)
				check(not files.is_empty(), "no file: " + k)
				for f in files:
					check(load(f) is AudioStreamWAV, "not a wav stream: " + f),
	)
	run(
		"assets/sfx = exactly the played keys' files",
		func() -> void:
			var want := { }
			for k: String in PLAYED:
				for f in Audio.files_of(k):
					want[f] = true
			var n := 0
			for f: String in DirAccess.get_files_at(Audio.DIR):
				if f.ends_with(".wav"):
					n += 1
					check(want.has(Audio.DIR + "/" + f), "orphan: " + f)
			eq(n, want.size(), "wav count"),
	)
	run(
		"music: one looped mp3",
		func() -> void:
			var m: Variant = load(Audio.MUSIC)
			check(m is AudioStreamMP3, "music is mp3")
			if m is AudioStreamMP3:
				var mp: AudioStreamMP3 = m
				check(mp.loop, "music loops")
				check(mp.get_length() > 60.0, "full track, %.0f s" % mp.get_length()),
	)
