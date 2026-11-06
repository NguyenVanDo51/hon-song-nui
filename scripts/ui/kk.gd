class_name KK
extends RefCounted
## KayKit models (CC0, Kay Lousberg, www.kaylousberg.com): cached scenes, fit-to-tile props, animated characters
## (one shared Rig_Medium animation library), faction recolour (shaders/team_tint.gdshader).

const ROOT := "res://assets/kaykit/"
const TEAM_HUE := { "p": 0.0, "e": 0.6 } # red / blue cloth
const TINT := preload("res://shaders/team_tint.gdshader")
## looping clips (the rest play once)
const LOOPS := [
	"Idle_A",
	"Idle_B",
	"Walking_A",
	"Walking_B",
	"Walking_C",
	"Running_A",
	"Running_B",
	"Melee_2H_Idle",
	"Melee_Unarmed_Idle",
	"Ranged_Bow_Idle",
	"Ranged_Bow_Aiming_Idle",
	"Death_A_Pose",
	"Death_B_Pose",
]

static var _scenes := { }
static var _lib: AnimationLibrary
static var _tints := { } # "texture id|side" -> ShaderMaterial

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

## bounding box of every mesh under n, in n's space
static func aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != n and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

## a static model scaled so its footprint is `fit` tiles wide (its base stays at y = 0); max_h > 0 squashes it to that height
static func prop(path: String, fit: float, max_h := 0.0) -> Node3D:
	var n: Node3D = scene(ROOT + path).instantiate()
	var b := aabb(n)
	var s := fit / maxf(0.001, maxf(b.size.x, b.size.z))
	var sy := minf(s, max_h / maxf(0.001, b.end.y)) if max_h > 0.0 else s
	var holder := Node3D.new()
	holder.add_child(n)
	n.scale = Vector3(s, sy, s)
	n.position = Vector3(
		-(b.position.x + b.size.x / 2.0) * s,
		-b.position.y * sy if b.position.y > -0.05 else 0.0,
		-(b.position.z + b.size.z / 2.0) * s,
	)
	return holder

static func anims() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	for f: String in ["General", "MovementBasic", "CombatMelee", "CombatRanged"]:
		var inst: Node = scene(ROOT + "anims/Rig_Medium_%s.glb" % f).instantiate()
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		for nm: StringName in ap.get_animation_list():
			if _lib.has_animation(nm):
				continue
			var a: Animation = ap.get_animation(nm)
			a.loop_mode = Animation.LOOP_LINEAR if LOOPS.has(String(nm)) else Animation.LOOP_NONE
			_lib.add_animation(nm, a)
		inst.free()
	return _lib

## animated character: body + weapons on hand slots + AnimationPlayer with the shared library.
## Faces +X (the board's "forward"); tint = recolour cloth to the side's hue.
static func actor(char_file: String, weapons: Array, side: String, tint: bool) -> Node3D:
	var root := Node3D.new()
	var body: Node3D = scene(ROOT + "chars/" + char_file).instantiate()
	body.rotation.y = PI / 2.0 # KayKit characters face +Z
	root.add_child(body)
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	for w: Array in weapons:
		var ba := BoneAttachment3D.new()
		ba.bone_name = w[0]
		sk.add_child(ba)
		var wpath: String = w[1]
		var wi: Node3D = scene("res://" + wpath).instantiate()
		if w.size() > 2:
			wi.transform = w[2]
		ba.add_child(wi)
	var ap := AnimationPlayer.new()
	body.add_child(ap)
	ap.add_animation_library("", anims())
	var meshes: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
		if tint:
			_tint(mi, side)
	root.set_meta("ap", ap)
	root.set_meta("meshes", meshes)
	return root

static func _tint(mi: MeshInstance3D, side: String) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i)
		if not (m is BaseMaterial3D) or (m as BaseMaterial3D).albedo_texture == null:
			continue
		var tex: Texture2D = (m as BaseMaterial3D).albedo_texture
		var key := "%d|%s" % [tex.get_instance_id(), side]
		if not _tints.has(key):
			var sm := ShaderMaterial.new()
			sm.shader = TINT
			sm.set_shader_parameter("albedo_tex", tex)
			sm.set_shader_parameter("team_hue", TEAM_HUE[side])
			_tints[key] = sm
		var tm: Material = _tints[key]
		mi.set_surface_override_material(i, tm)
