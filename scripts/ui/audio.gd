class_name Audio
extends Node
## SFX = wav files in assets/sfx, made by tools/sfx/synth.mjs (style C "nhạc cụ gõ": mallets in D + one shared room).
## s_<key>.wav, or s_<key>_<n>.wav variants -> one picked at random per play. s_select.wav = the old synth, kept (user).
## Music = one calm looped track for menus + matches (CC BY 4.0 -> credited in credits.gd, "Giới thiệu" page).

const DIR := "res://assets/sfx"
const MUSIC := "res://assets/music/lord_of_the_land.mp3"
## files are loudness-normalised per kind (synth.mjs targets); these set the in-game mix
const SFX_DB := -10.0 # ≈ old synth level (hit −25 vs −27 dBFS short-term)
const MUSIC_DB := -10.0 # music loud parts ≈ 8 dB under a hit
## per-key offset on top of SFX_DB: s_select.wav is the old synth file (−40 dBFS), +10 keeps its old in-game level
const GAIN := { "select": 10.0 }
const MAX_VARIANTS := 9
const POOL := 8
## debug flag sfxlog: print "SFXLOG <frame> <sfx>" per play (tools/record_sfx_scene.sh -> docs/design scene markers)
static var log_sfx := false

var muted: bool
var music_on: bool
var _variants := { } # sfx key -> Array[AudioStream], filled on first play
var _sfx_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next_sfx := 0
var _rng := RandomNumberGenerator.new() # own stream: never touches the global RNG

func _ready() -> void:
	_rng.randomize()
	muted = Store.get_v("mute", false)
	music_on = Store.get_v("music", true)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC) # loop=true in the .import
	add_child(_music)
	_apply_volume()
	if music_on:
		_music.play()

func unlock() -> void:
	pass # browsers needed a user gesture; Godot does not

func play(sfx: String) -> void:
	if log_sfx:
		print("SFXLOG %d %s" % [Engine.get_process_frames(), sfx])
	if muted:
		return
	var list := _streams(sfx)
	if list.is_empty():
		return
	var p := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % POOL
	p.stream = list[_rng.randi() % list.size()]
	var gain: float = GAIN.get(sfx, 0.0)
	p.volume_db = SFX_DB + gain
	p.play()

func set_muted(m: bool) -> void:
	muted = m
	Store.set_v("mute", m)
	_apply_volume()

func set_music(on: bool) -> void:
	music_on = on
	Store.set_v("music", on)
	if on:
		_music.play()
	else:
		_music.stop()

func _apply_volume() -> void:
	for p in _sfx_players:
		p.volume_db = -80.0 if muted else SFX_DB # play() re-applies SFX_DB + GAIN per sound
	_music.volume_db = -80.0 if muted else MUSIC_DB

func _streams(key: String) -> Array:
	if not _variants.has(key):
		var list := []
		for path in files_of(key):
			list.append(load(path))
		if list.is_empty():
			push_warning("audio: no file for sfx '%s' in %s" % [key, DIR])
		_variants[key] = list
	return _variants[key]

## res:// paths of a sound: s_<key>.wav, else s_<key>_1.wav, _2 ... (stops at the first gap)
static func files_of(key: String) -> PackedStringArray:
	var one := "%s/s_%s.wav" % [DIR, key]
	if ResourceLoader.exists(one):
		return PackedStringArray([one])
	var out := PackedStringArray()
	for n in range(1, MAX_VARIANTS + 1):
		var p := "%s/s_%s_%d.wav" % [DIR, key, n]
		if not ResourceLoader.exists(p):
			break
		out.append(p)
	return out
