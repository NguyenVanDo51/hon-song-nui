class_name Rigs
extends RefCounted
## which unit types attack with a code rig on the 2D board. Each entry: the hand-ported spec script + the exported
## data per side. Same name for both sides = shared art, the enemy gets the team-colour swap.
## Every unit is pre-registered: a type whose spec script does not exist yet falls back to fx.attack.

const SPECS := {
	"hero": { "script": "res://scripts/ui/rig/specs/hero.gd", "p": "hero_p", "e": "hero_e" },
	"soldier": { "script": "res://scripts/ui/rig/specs/soldier.gd", "p": "soldier", "e": "soldier" },
	"archer": { "script": "res://scripts/ui/rig/specs/archer.gd", "p": "archer", "e": "archer" },
	"boat": { "script": "res://scripts/ui/rig/specs/boat.gd", "p": "boat", "e": "boat" },
	"shaman": { "script": "res://scripts/ui/rig/specs/shaman.gd", "p": "shaman", "e": "shaman" },
	"drum": { "script": "res://scripts/ui/rig/specs/drum.gd", "p": "drum", "e": "drum" },
	"wolf": { "script": "res://scripts/ui/rig/specs/wolf.gd", "p": "wolf", "e": "wolf" },
	"elephant": { "script": "res://scripts/ui/rig/specs/elephant.gd", "p": "elephant", "e": "elephant" },
	"catapult": { "script": "res://scripts/ui/rig/specs/catapult.gd", "p": "catapult", "e": "catapult" },
	"bird": { "script": "res://scripts/ui/rig/specs/bird.gd", "p": "bird", "e": "bird" },
	"ghost": { "script": "res://scripts/ui/rig/specs/ghost.gd", "p": "ghost", "e": "ghost" },
}
## counter-attacks play a little faster than the attack itself
const COUNTER_SPEED := 1.25
static var enabled := true
static var _scripts := {}

static func has(type: String, side: String) -> bool:
	if not enabled or Token.fig_style != "chibi" or not SPECS.has(type):
		return false
	var e: Dictionary = SPECS[type]
	return RigData.exists(e.get(side, e.p)) and ResourceLoader.exists(e.script)

## a fresh attack rig for this unit (null when it has none)
static func make(type: String, side: String) -> Rig:
	if not has(type, side):
		return null
	var e: Dictionary = SPECS[type]
	var name: String = e.get(side, e.p)
	var data := RigData.get_data(name)
	if data == null:
		return null
	if not _scripts.has(e.script):
		_scripts[e.script] = load(e.script)
	var r := Rig.new(data, _scripts[e.script].new())
	r.swap = side == "e" and name == e.p
	r.part_id = "rig|" + name
	r.a_type = type
	r.heavy = Rules.UNITS.get(type, {}).get("heavy", false)
	return r

static func types() -> Array:
	return SPECS.keys()
