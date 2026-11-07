extends "res://sim/tests/test_base.gd"
## audio tests (run by sim/tests.gd): pure static Audio functions + baked files

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
		"note() = D Dorian from D3",
		func() -> void:
			# D3 E3 F3 G3 A3 B3 C4 D4 (equal temperament, A4 = 440 Hz); deg -1 = C3
			var hz := [146.83, 164.81, 174.61, 196.0, 220.0, 246.94, 261.63, 293.66]
			for d in hz.size():
				var want: float = hz[d]
				check(absf(Audio.note(d) - want) < 0.05, "deg %d: %f vs %f" % [d, Audio.note(d), want])
			check(absf(Audio.note(-1) - 130.81) < 0.05, "deg -1 = C3"),
	)
	run(
		"recipes() has every played SFX key",
		func() -> void:
			var r := Audio.recipes()
			for k: String in PLAYED:
				check(r.has("s:" + k), "missing s:" + k),
	)
	run(
		"phrase: in range, mostly stepwise, resolves to root/fifth; every scheduled key has a recipe",
		func() -> void:
			var r := Audio.recipes()
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for n in 300:
				var ph := Audio.phrase(rng)
				eq(ph.size(), 8, "phrase length")
				check(ph[0] != null, "starts on a note")
				check(Audio.RESOLVE.has(ph[6]), "step 6 resolves: %s" % [ph])
				eq(ph[7], null, "step 7 rests")
				var prev: int = ph[0]
				var pi := 0
				for i in range(1, 7):
					if ph[i] == null:
						continue
					var d: int = ph[i]
					check(d >= 0 and d < Audio.DEGREES, "in range: %s" % [ph])
					check(absi(d - prev) <= 2 * (i - pi) + (1 if i == 6 else 0), "stepwise (<= 2 per beat): %s" % [ph])
					prev = d
					pi = i
				for step in 8:
					for key: String in Audio.step_keys(step, ph, rng):
						check(r.has("m:" + key), "missing m:" + key),
	)
	run(
		"assets/sfx = exactly the baked recipes",
		func() -> void:
			var r := Audio.recipes()
			var files := { }
			for f: String in DirAccess.get_files_at(Audio.DIR):
				if f.ends_with(".wav"):
					files[Audio.DIR + "/" + f] = true
			for k: String in r:
				check(files.has(Audio.file_of(k)), "not baked: " + k)
			eq(files.size(), r.size(), "wav count (orphans?)"),
	)
