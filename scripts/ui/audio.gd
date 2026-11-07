class_name Audio
extends Node
## synthesized SFX + medieval ambient music (D Dorian lute, drone, war drum; port of src/ui/audio.js).
## Every WebAudio recipe (oscillators with exp pitch ramps + vibrato, filtered noise, gain envelopes) is rendered
## offline by tools/bake_sfx.gd into assets/sfx/*.wav; at runtime each sound is loaded on its first play and kept.
## (Rendering at boot took 1.7 s, and the single-threaded web build ran it on the main thread = blank screen.)
## Regenerate after changing a recipe: godot --headless --path . -s tools/bake_sfx.gd  (then --import once).
## A missing file falls back to rendering that one sound on the spot.

const SR := 22050
const MASTER := 0.8
const SFX_GAIN := 0.7
const MUSIC_GAIN := 0.16
const POOL := 8
const MUSIC_POOL := 12 # drone rings 4 beats; 8 players would cut it mid-note
## ambient: D Dorian from D3, plucked lute + octave shimmer, root/fifth drone, war drum
const SCALE := [0, 2, 3, 5, 7, 9, 10]
const BASE := 146.83
const BEAT := 0.62
const DEGREES := 11 # melody range 0..10 = D3..G4 (1.5 octaves)
const RESOLVE := [0, 4, 7] # phrase ends on root / fifth / octave

## recipe = list of ["tone"|"noise", params] (params as in audio.js: f f2 type dur vol at attack vib / dur vol at freq q type f2)
const SFX := {
	"select": [["tone", { "f": 880, "f2": 1320, "type": "triangle", "dur": 0.07, "vol": 0.12 }]],
	"move": [["noise", { "dur": 0.12, "vol": 0.12, "freq": 600, "f2": 300 }]],
	"slash": [
		["noise", { "dur": 0.18, "vol": 0.35, "freq": 3000, "f2": 800, "type": "bandpass", "q": 1.5 }],
		["tone", { "f": 220, "f2": 90, "type": "square", "dur": 0.12, "vol": 0.08, "at": 0.03 }],
	],
	"hit": [["noise", { "dur": 0.2, "vol": 0.45, "freq": 900, "f2": 200 }], ["tone", { "f": 140, "f2": 60, "dur": 0.18, "vol": 0.3 }]],
	"heavy": [["noise", { "dur": 0.45, "vol": 0.6, "freq": 500, "f2": 80 }], ["tone", { "f": 90, "f2": 35, "dur": 0.5, "vol": 0.5 }]],
	"arrow": [["noise", { "dur": 0.22, "vol": 0.18, "freq": 4000, "f2": 1500, "type": "bandpass", "q": 4 }]],
	"orb": [["tone", { "f": 300, "f2": 900, "type": "sine", "dur": 0.35, "vol": 0.18, "vib": 20 }]],
	"rock": [["tone", { "f": 200, "f2": 120, "type": "triangle", "dur": 0.3, "vol": 0.12 }]],
	"die": [
		["noise", { "dur": 0.5, "vol": 0.3, "freq": 700, "f2": 120 }],
		["tone", { "f": 330, "f2": 110, "type": "sawtooth", "dur": 0.4, "vol": 0.06 }],
	],
	"capture": [
		# short horn call D4 -> A4
		["tone", { "f": 293.7, "type": "sawtooth", "dur": 0.28, "vol": 0.08, "attack": 0.025 }],
		["tone", { "f": 293.7, "type": "triangle", "dur": 0.28, "vol": 0.2, "attack": 0.025 }],
		["tone", { "f": 440, "type": "sawtooth", "dur": 0.8, "vol": 0.08, "at": 0.22, "attack": 0.03, "vib": 2 }],
		["tone", { "f": 440, "type": "triangle", "dur": 0.8, "vol": 0.2, "at": 0.22, "attack": 0.03, "vib": 2 }],
	],
	"coin": [
		["tone", { "f": 988, "type": "square", "dur": 0.08, "vol": 0.07 }],
		["tone", { "f": 1319, "type": "square", "dur": 0.18, "vol": 0.07, "at": 0.07 }],
	],
	"rank": [
		["tone", { "f": 523, "type": "triangle", "dur": 0.25, "vol": 0.12 }],
		["tone", { "f": 659, "type": "triangle", "dur": 0.25, "vol": 0.12, "at": 0.08 }],
		["tone", { "f": 784, "type": "triangle", "dur": 0.25, "vol": 0.12, "at": 0.16 }],
		["tone", { "f": 1047, "type": "triangle", "dur": 0.25, "vol": 0.12, "at": 0.24 }],
	],
	"raise": [
		["tone", { "f": 600, "f2": 150, "type": "sine", "dur": 1.0, "vol": 0.18, "vib": 30 }],
		["noise", { "dur": 0.8, "vol": 0.08, "freq": 2000, "f2": 300, "type": "bandpass", "q": 3 }],
	],
	"heal": [["tone", { "f": 660, "f2": 990, "type": "sine", "dur": 0.3, "vol": 0.08 }]],
	"drum": [
		# Cleric of Light aura: holy chime A5 + E6 fifth, faint bell partial
		["tone", { "f": 880, "dur": 1.5, "vol": 0.16 }],
		["tone", { "f": 2429, "dur": 0.4, "vol": 0.025 }],
		["tone", { "f": 1318.5, "dur": 1.4, "vol": 0.1, "at": 0.09 }],
		["tone", { "f": 1760, "dur": 1.1, "vol": 0.04, "at": 0.18 }],
	],
	"spawn": [["noise", { "dur": 0.7, "vol": 0.2, "freq": 300, "f2": 1200, "type": "bandpass", "q": 1 }]],
	"win": [
		# horn fanfare D major: D4 F#4 A4 -> D5 held over A4
		["tone", { "f": 293.7, "type": "sawtooth", "dur": 0.3, "vol": 0.06, "attack": 0.02 }],
		["tone", { "f": 293.7, "type": "triangle", "dur": 0.3, "vol": 0.14, "attack": 0.02 }],
		["tone", { "f": 370, "type": "sawtooth", "dur": 0.3, "vol": 0.06, "at": 0.15, "attack": 0.02 }],
		["tone", { "f": 370, "type": "triangle", "dur": 0.3, "vol": 0.14, "at": 0.15, "attack": 0.02 }],
		["tone", { "f": 440, "type": "sawtooth", "dur": 0.3, "vol": 0.06, "at": 0.3, "attack": 0.02 }],
		["tone", { "f": 440, "type": "triangle", "dur": 0.3, "vol": 0.14, "at": 0.3, "attack": 0.02 }],
		["tone", { "f": 587.3, "type": "sawtooth", "dur": 1.3, "vol": 0.06, "at": 0.45, "attack": 0.03, "vib": 3 }],
		["tone", { "f": 587.3, "type": "triangle", "dur": 1.3, "vol": 0.16, "at": 0.45, "attack": 0.03, "vib": 3 }],
		["tone", { "f": 440, "type": "triangle", "dur": 1.3, "vol": 0.08, "at": 0.45, "attack": 0.03 }],
	],
	"lose": [
		# low horn falling A3 G3 F3 -> D3
		["tone", { "f": 220, "type": "sawtooth", "dur": 0.55, "vol": 0.06, "attack": 0.05 }],
		["tone", { "f": 220, "type": "triangle", "dur": 0.55, "vol": 0.16, "attack": 0.05 }],
		["tone", { "f": 196, "type": "sawtooth", "dur": 0.55, "vol": 0.06, "at": 0.35, "attack": 0.05 }],
		["tone", { "f": 196, "type": "triangle", "dur": 0.55, "vol": 0.16, "at": 0.35, "attack": 0.05 }],
		["tone", { "f": 174.6, "type": "sawtooth", "dur": 0.55, "vol": 0.06, "at": 0.7, "attack": 0.05 }],
		["tone", { "f": 174.6, "type": "triangle", "dur": 0.55, "vol": 0.16, "at": 0.7, "attack": 0.05 }],
		["tone", { "f": 146.8, "f2": 142, "type": "sawtooth", "dur": 1.4, "vol": 0.06, "at": 1.05, "attack": 0.06, "vib": 2 }],
		["tone", { "f": 146.8, "f2": 142, "type": "triangle", "dur": 1.4, "vol": 0.18, "at": 1.05, "attack": 0.06, "vib": 2 }],
	],
	"ui": [
		# wax-seal press: low thud + paper rustle
		["tone", { "f": 170, "f2": 70, "dur": 0.1, "vol": 0.07 }],
		["noise", { "dur": 0.05, "vol": 0.025, "freq": 2500, "f2": 900 }],
	],
	"page": [
		# paper flip: band-passed noise sweeping up, soft settle
		["noise", { "dur": 0.16, "vol": 0.25, "freq": 1200, "f2": 5000, "type": "bandpass", "q": 1.2 }],
		["noise", { "dur": 0.1, "vol": 0.06, "freq": 3000, "f2": 1200, "at": 0.12 }],
	],
}

const DIR := "res://assets/sfx"

var muted: bool
var music_on: bool
var _streams := { } # "s:<sfx>" / "m:<note>" -> AudioStreamWAV, filled on first use
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _next_sfx := 0
var _next_music := 0
var _clock := 0.0
var _next_beat := 0.1
var _step := 0
var _phrase := []

func _ready() -> void:
	muted = Store.get_v("mute", false)
	music_on = Store.get_v("music", true)
	_rng.randomize()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	for i in MUSIC_POOL:
		var m := AudioStreamPlayer.new()
		add_child(m)
		_music_players.append(m)
	_apply_volume()

func unlock() -> void:
	pass # browsers needed a user gesture; Godot does not

func play(sfx: String) -> void:
	if muted:
		return
	var st := _stream("s:" + sfx)
	if st == null:
		return
	var p := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % POOL
	p.stream = st
	p.play()

func set_muted(m: bool) -> void:
	muted = m
	Store.set_v("mute", m)
	_apply_volume()

func set_music(on: bool) -> void:
	music_on = on
	Store.set_v("music", on)
	if on:
		_clock = 0.0
		_next_beat = 0.1
		_step = 0
	else:
		for p in _music_players:
			p.stop()

func _apply_volume() -> void:
	for p in _sfx_players + _music_players:
		p.volume_db = -80.0 if muted else 0.0

# ---------- music ----------
func _process(dt: float) -> void:
	if not music_on:
		return
	_clock += dt
	if _clock - _next_beat > 1.0: # long hitch: resync instead of a burst of notes
		_next_beat = _clock
	while _clock >= _next_beat:
		_music_step()
		_next_beat += BEAT

func _new_phrase() -> void:
	_phrase = phrase(_rng)

## 8 steps (degree or null = rest): mostly stepwise from root/3rd/5th, step 6 resolves to the nearest RESOLVE, step 7 breathes
static func phrase(rng: RandomNumberGenerator) -> Array:
	var d: int = [0, 2, 4][rng.randi() % 3]
	var out := []
	for i in 6:
		d += [-1, -1, 1, 1, -2, 2, 0][rng.randi() % 7]
		d = clampi(d, 0, DEGREES - 1)
		if i > 0 and rng.randf() < 0.25:
			out.append(null)
		else:
			out.append(d)
	var best: int = RESOLVE[0]
	for r: int in RESOLVE:
		if absi(r - d) < absi(best - d):
			best = r
	out.append(best)
	out.append(null)
	return out

func _music_step() -> void:
	if _step % 8 == 0:
		_new_phrase()
	for key: String in step_keys(_step, _phrase, _rng):
		_play_note(key)
	_step += 1

## music notes for one beat: lute n<deg> + shimmer o<deg>, drone root (beat 0) / fifth (beat 4), drum on 0 and 6, rare roll on 7
static func step_keys(step: int, phr: Array, rng: RandomNumberGenerator) -> Array[String]:
	var s := step % 8
	var out: Array[String] = []
	var deg: Variant = phr[s]
	if deg != null:
		out.append("n%d" % deg)
		out.append("o%d" % deg)
	if s == 0:
		out.append("bass")
	elif s == 4:
		out.append("fifth")
	if s == 0 or s == 6:
		out.append("thump")
	elif s == 7 and rng.randf() < 0.3:
		out.append("roll")
	return out

func _play_note(key: String) -> void:
	if muted:
		return
	var st := _stream("m:" + key)
	if st == null:
		return
	var p := _music_players[_next_music]
	_next_music = (_next_music + 1) % MUSIC_POOL
	p.stream = st
	p.play()

static func note(deg: int) -> float:
	var n := SCALE.size()
	var semi: int = SCALE[((deg % n) + n) % n]
	return BASE * pow(2.0, (semi + 12 * floori(float(deg) / n)) / 12.0)

# ---------- baked streams ----------
static func file_of(key: String) -> String:
	return "%s/%s.wav" % [DIR, key.replace(":", "_")]

func _stream(key: String) -> AudioStream:
	var st: Variant = _streams.get(key)
	if st == null:
		var path := file_of(key)
		if ResourceLoader.exists(path):
			st = load(path)
		else:
			var r: Variant = recipes().get(key)
			if r == null:
				return null
			push_warning("audio: %s not baked, rendering it now (run tools/bake_sfx.gd)" % path)
			var rd: Array = r
			var rparts: Array = rd[0]
			var rgain: float = rd[1]
			st = to_stream(_render(rparts, rgain, RandomNumberGenerator.new()))
		_streams[key] = st
	return st

static func to_stream(pcm: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = pcm
	return w

## every sound: key -> [recipe parts, bus gain]. "s:<name>" = SFX (Audio.play names), "m:<note>" = music
static func recipes() -> Dictionary:
	var out := { }
	for sfx: String in SFX:
		out["s:" + sfx] = [SFX[sfx], SFX_GAIN * MASTER]
	var g := MUSIC_GAIN * MASTER
	for d in DEGREES:
		var f := note(d)
		# pluck: triangle body + short 2nd-harmonic twang, no glide, no vibrato
		var pluck := [
			["tone", { "f": f, "type": "triangle", "dur": BEAT * 1.6, "vol": 0.45, "attack": 0.004 }],
			["tone", { "f": f * 2, "type": "sine", "dur": 0.25, "vol": 0.12, "attack": 0.002 }],
		]
		out["m:n%d" % d] = [pluck, g]
		out["m:o%d" % d] = [[["tone", { "f": f * 2, "type": "sine", "dur": BEAT * 1.2, "vol": 0.05, "attack": 0.08 }]], g]
	var drone := { "type": "triangle", "dur": BEAT * 3.8, "vol": 0.22, "attack": 0.25 }
	out["m:bass"] = [[["tone", drone.merged({ "f": BASE / 2 })]], g]
	out["m:fifth"] = [[["tone", drone.merged({ "f": BASE * 0.75 })]], g]
	out["m:thump"] = [[["tone", { "f": 95, "f2": 48, "dur": 0.4, "vol": 0.55 }], ["noise", { "dur": 0.06, "vol": 0.12, "freq": 300 }]], g]
	var roll := []
	for i in 4:
		roll.append(["tone", { "f": 90, "f2": 55, "dur": 0.16, "vol": 0.12 + 0.05 * i, "at": BEAT / 4.0 * i }])
	out["m:roll"] = [roll, g]
	return out

## mix every part of a recipe into one buffer, scaled by the bus gain; returns 16-bit PCM bytes
static func _render(parts: Array, gain: float, rng: RandomNumberGenerator) -> PackedByteArray:
	var total := 0
	for part: Array in parts:
		var p: Dictionary = part[1]
		var at: float = p.get("at", 0.0)
		var dur: float = p.get("dur", 0.2)
		total = maxi(total, int((at + dur + 0.05) * SR) + 1)
	var buf := PackedFloat32Array()
	buf.resize(total)
	buf.fill(0.0)
	for part: Array in parts:
		var pd: Dictionary = part[1]
		if part[0] == "tone":
			buf = _tone(buf, pd, gain)
		else:
			buf = _noise(buf, pd, gain, rng)
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var soft := peak > 1.0
	var out := PackedByteArray()
	out.resize(total * 2)
	for i in total:
		var v: float = buf[i]
		if soft:
			v = tanh(v)
		out.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return out

## oscillator: exp pitch ramp f -> f2 over dur, optional 5.5 Hz vibrato of `vib` Hz,
## gain 0 -> vol linear over `attack`, then exponential to 0.0001 at dur (stops at dur + 0.05)
static func _tone(buf: PackedFloat32Array, p: Dictionary, gain: float) -> PackedFloat32Array:
	var f: float = p.get("f", 440.0)
	var f2: float = p.get("f2", f)
	var type: String = p.get("type", "sine")
	var dur: float = p.get("dur", 0.2)
	var vol: float = p.get("vol", 0.3)
	var attack: float = p.get("attack", 0.005)
	var vib: float = p.get("vib", 0.0)
	var wave := 0 if type == "sine" else 1 if type == "triangle" else 2 if type == "square" else 3
	var at: float = p.get("at", 0.0)
	var s0 := int(at * SR)
	var n := mini(int((dur + 0.05) * SR), buf.size() - s0)
	var nd := maxi(1, int(dur * SR))
	var na := maxi(1, int(attack * SR))
	var fr := pow(f2 / f, 1.0 / nd)
	var decay := pow(0.0001 / vol, 1.0 / maxi(1, nd - na))
	var vstep := TAU * 5.5 / SR
	var freq := f
	var ph := 0.0
	var g := 0.0
	for i in n:
		var fq := freq
		if vib > 0.0:
			fq += vib * sin(vstep * i)
		ph += fq / SR
		ph -= floorf(ph)
		var w: float
		if wave == 0:
			w = sin(TAU * ph)
		elif wave == 1:
			w = 1.0 - 4.0 * absf(ph - 0.5)
		elif wave == 2:
			w = 1.0 if ph < 0.5 else -1.0
		else:
			w = 2.0 * ph - 1.0
		if i < na:
			g = vol * i / na
		elif i == na:
			g = vol
		else:
			g *= decay
		buf[s0 + i] += w * g * gain
		if i < nd:
			freq *= fr
	return buf

## white noise through an RBJ biquad (lowpass Q in dB like WebAudio, bandpass Q linear), cutoff exp ramp freq -> f2,
## gain vol -> 0.0001 exponential over dur
static func _noise(buf: PackedFloat32Array, p: Dictionary, gain: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur: float = p.get("dur", 0.2)
	var vol: float = p.get("vol", 0.3)
	var cut: float = p.get("freq", 1200.0)
	var f2: float = p.get("f2", cut)
	var band: bool = p.get("type", "lowpass") == "bandpass"
	var q: float = p.get("q", 0.8)
	var ql := q if band else pow(10.0, q / 20.0)
	var at: float = p.get("at", 0.0)
	var s0 := int(at * SR)
	var n := mini(int((dur + 0.05) * SR), buf.size() - s0)
	var nd := maxi(1, int(dur * SR))
	var fr := pow(f2 / cut, 1.0 / nd)
	var decay := pow(0.0001 / vol, 1.0 / nd)
	var g := vol
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		if i % 32 == 0:
			var w0 := TAU * minf(cut, SR * 0.45) / SR
			var cw := cos(w0)
			var alpha := sin(w0) / (2.0 * ql)
			var a0 := 1.0 + alpha
			if band:
				b0 = alpha / a0
				b1 = 0.0
				b2 = -alpha / a0
			else:
				b0 = (1.0 - cw) / 2.0 / a0
				b1 = (1.0 - cw) / a0
				b2 = b0
			a1 = -2.0 * cw / a0
			a2 = (1.0 - alpha) / a0
		var x := rng.randf() * 2.0 - 1.0
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[s0 + i] += y * g * gain
		if i < nd:
			g *= decay
			cut *= fr
	return buf
