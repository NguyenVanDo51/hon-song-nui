class_name Audio
extends Node
## synthesized SFX + pentatonic ambient music (port of src/ui/audio.js).
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
## ambient: Vietnamese pentatonic (do re fa sol la) from G3, monochord-like glides
const SCALE := [0, 2, 5, 7, 9]
const BASE := 196.0
const BEAT := 0.62

## recipe = list of ["tone"|"noise", params] (params as in audio.js: f f2 type dur vol at attack vib / dur vol at freq q type f2)
const SFX := {
	"select": [["tone", { "f": 880, "f2": 1320, "type": "triangle", "dur": 0.07, "vol": 0.12 }]],
	"move": [["noise", { "dur": 0.12, "vol": 0.12, "freq": 600, "f2": 300 }]],
	"slash": [["noise", { "dur": 0.18, "vol": 0.35, "freq": 3000, "f2": 800, "type": "bandpass", "q": 1.5 }],
		["tone", { "f": 220, "f2": 90, "type": "square", "dur": 0.12, "vol": 0.08, "at": 0.03 }]],
	"hit": [["noise", { "dur": 0.2, "vol": 0.45, "freq": 900, "f2": 200 }], ["tone", { "f": 140, "f2": 60, "dur": 0.18, "vol": 0.3 }]],
	"heavy": [["noise", { "dur": 0.45, "vol": 0.6, "freq": 500, "f2": 80 }], ["tone", { "f": 90, "f2": 35, "dur": 0.5, "vol": 0.5 }]],
	"arrow": [["noise", { "dur": 0.22, "vol": 0.18, "freq": 4000, "f2": 1500, "type": "bandpass", "q": 4 }]],
	"orb": [["tone", { "f": 300, "f2": 900, "type": "sine", "dur": 0.35, "vol": 0.18, "vib": 20 }]],
	"rock": [["tone", { "f": 200, "f2": 120, "type": "triangle", "dur": 0.3, "vol": 0.12 }]],
	"die": [["noise", { "dur": 0.5, "vol": 0.3, "freq": 700, "f2": 120 }], ["tone", { "f": 330, "f2": 110, "type": "sawtooth", "dur": 0.4, "vol": 0.06 }]],
	"capture": [["tone", { "f": 196, "dur": 1.6, "vol": 0.18, "vib": 2 }], ["tone", { "f": 294, "dur": 1.6, "vol": 0.18, "at": 0.02, "vib": 2 }],
		["tone", { "f": 392, "dur": 1.6, "vol": 0.18, "at": 0.04, "vib": 2 }], ["tone", { "f": 784, "type": "triangle", "dur": 0.9, "vol": 0.05 }]],
	"coin": [["tone", { "f": 988, "type": "square", "dur": 0.08, "vol": 0.07 }], ["tone", { "f": 1319, "type": "square", "dur": 0.18, "vol": 0.07, "at": 0.07 }]],
	"rank": [["tone", { "f": 523, "type": "triangle", "dur": 0.25, "vol": 0.12 }], ["tone", { "f": 659, "type": "triangle", "dur": 0.25, "vol": 0.12, "at": 0.08 }],
		["tone", { "f": 784, "type": "triangle", "dur": 0.25, "vol": 0.12, "at": 0.16 }], ["tone", { "f": 1047, "type": "triangle", "dur": 0.25, "vol": 0.12, "at": 0.24 }]],
	"raise": [["tone", { "f": 600, "f2": 150, "type": "sine", "dur": 1.0, "vol": 0.18, "vib": 30 }],
		["noise", { "dur": 0.8, "vol": 0.08, "freq": 2000, "f2": 300, "type": "bandpass", "q": 3 }]],
	"heal": [["tone", { "f": 660, "f2": 990, "type": "sine", "dur": 0.3, "vol": 0.08 }]],
	"drum": [["tone", { "f": 110, "f2": 55, "dur": 0.5, "vol": 0.6 }], ["noise", { "dur": 0.12, "vol": 0.2, "freq": 400 }],
		["tone", { "f": 110, "f2": 55, "dur": 0.5, "vol": 0.45, "at": 0.28 }]],
	"spawn": [["noise", { "dur": 0.7, "vol": 0.2, "freq": 300, "f2": 1200, "type": "bandpass", "q": 1 }]],
	"win": [["tone", { "f": 392, "type": "triangle", "dur": 0.7, "vol": 0.14, "vib": 3 }], ["tone", { "f": 440, "type": "triangle", "dur": 0.7, "vol": 0.14, "at": 0.14, "vib": 3 }],
		["tone", { "f": 523, "type": "triangle", "dur": 0.7, "vol": 0.14, "at": 0.28, "vib": 3 }], ["tone", { "f": 587, "type": "triangle", "dur": 0.7, "vol": 0.14, "at": 0.42, "vib": 3 }],
		["tone", { "f": 784, "type": "triangle", "dur": 0.7, "vol": 0.14, "at": 0.56, "vib": 3 }]],
	"lose": [["tone", { "f": 392, "dur": 0.9, "vol": 0.14, "vib": 4 }], ["tone", { "f": 349, "dur": 0.9, "vol": 0.14, "at": 0.22, "vib": 4 }],
		["tone", { "f": 294, "dur": 0.9, "vol": 0.14, "at": 0.44, "vib": 4 }], ["tone", { "f": 262, "dur": 0.9, "vol": 0.14, "at": 0.66, "vib": 4 }]],
	"ui": [["tone", { "f": 660, "type": "triangle", "dur": 0.05, "vol": 0.07 }]],
}

var muted: bool
var music_on: bool
const DIR := "res://assets/sfx"
var _streams := {} # "s:<sfx>" / "m:<note>" -> AudioStreamWAV, filled on first use
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _next_music := 0
var _clock := 0.0
var _next_beat := 0.1
var _step := 0
var _phrase := []

func _ready() -> void:
	muted = Store.get_v("mute", false)
	music_on = Store.get_v("music", true)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
		var m := AudioStreamPlayer.new()
		add_child(m)
		_music_players.append(m)
	_apply_volume()

func unlock() -> void:
	pass # browsers needed a user gesture; Godot does not

func play(name: String) -> void:
	if muted:
		return
	var st := _stream("s:" + name)
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
	var d := 2 + randi() % 4
	_phrase = []
	for i in 8:
		d += [-2, -1, 1, 2, 0][randi() % 5]
		d = clampi(d, 0, 9)
		_phrase.append(null if randf() < 0.25 else d)

func _music_step() -> void:
	if _step % 8 == 0:
		_new_phrase()
	var deg: Variant = _phrase[_step % 8]
	if deg != null:
		# glide from the neighbour note like a monochord pitch bend
		_play_note(("g%d" if randf() < 0.4 else "n%d") % deg)
		_play_note("o%d" % deg)
	if _step % 4 == 0:
		_play_note("bass")
	if _step % 8 == 6:
		_play_note("thump")
	_step += 1

func _play_note(key: String) -> void:
	if muted:
		return
	var st := _stream("m:" + key)
	if st == null:
		return
	var p := _music_players[_next_music]
	_next_music = (_next_music + 1) % POOL
	p.stream = st
	p.play()

static func note(deg: int) -> float:
	return BASE * pow(2.0, (SCALE[((deg % 5) + 5) % 5] + 12 * floori(deg / 5.0)) / 12.0)

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
			st = to_stream(_render(r[0], r[1], RandomNumberGenerator.new()))
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
	var out := {}
	for name: String in SFX:
		out["s:" + name] = [SFX[name], SFX_GAIN * MASTER]
	var g := MUSIC_GAIN * MASTER
	for d in 10:
		var f := note(d)
		var main := { "f": f, "type": "sine", "dur": BEAT * 1.8, "vol": 0.5, "attack": 0.04, "vib": 3 }
		out["m:n%d" % d] = [[["tone", main]], g]
		var gl := main.duplicate()
		gl.f = f * 0.94
		gl.f2 = f
		out["m:g%d" % d] = [[["tone", gl]], g]
		out["m:o%d" % d] = [[["tone", { "f": f * 2, "type": "sine", "dur": BEAT * 1.2, "vol": 0.08, "attack": 0.04 }]], g]
	out["m:bass"] = [[["tone", { "f": BASE / 2, "f2": BASE / 2.2, "type": "sine", "dur": 0.6, "vol": 0.4 }]], g]
	out["m:thump"] = [[["tone", { "f": 70, "f2": 45, "type": "sine", "dur": 0.4, "vol": 0.5 }]], g]
	return out

## mix every part of a recipe into one buffer, scaled by the bus gain; returns 16-bit PCM bytes
static func _render(parts: Array, gain: float, rng: RandomNumberGenerator) -> PackedByteArray:
	var total := 0
	for part: Array in parts:
		var p: Dictionary = part[1]
		total = maxi(total, int((float(p.get("at", 0.0)) + float(p.get("dur", 0.2)) + 0.05) * SR) + 1)
	var buf := PackedFloat32Array()
	buf.resize(total)
	buf.fill(0.0)
	for part: Array in parts:
		if part[0] == "tone":
			buf = _tone(buf, part[1], gain)
		else:
			buf = _noise(buf, part[1], gain, rng)
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
	var s0 := int(float(p.get("at", 0.0)) * SR)
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
	var s0 := int(float(p.get("at", 0.0)) * SR)
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
