extends SceneTree
## headless match review (README "Ghi trận / phân tích"): replay + analyze recorded matches (scripts/ui/match_rec.gd).
## <godot> --headless --path . -s sim/review.gd -- [what=latest|all-new|<file.replay>] [profile=default]
##     [lessons=res://docs/review/match_lessons.md | lessons=off] [lessons_bot] [scen=res://sim/scenarios] [noscen]
## Writes <id>.review.md / .json beside the replay, appends docs/review/match_lessons.md, prints the md. Wrapper:
## tools/review_match.sh.

const ReviewLib := preload("res://sim/review_lib.gd")
const ReviewOut := preload("res://sim/review_out.gd")

func _init() -> void:
	var args := { }
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var what := str(args.get("what", "latest"))
	var dir := MatchRec.dir_for(str(args.get("profile", "")))
	var lessons := str(args.get("lessons", "res://docs/review/match_lessons.md"))
	var files := pick(what, dir)
	if files.is_empty():
		print("review: nothing to analyze (%s in %s)" % [what, ProjectSettings.globalize_path(dir)])
		quit()
		return
	var lib := ReviewLib.new()
	lib.scen_dir = str(args.get("scen", lib.scen_dir))
	lib.write_scen = not args.has("noscen")
	var fails := 0
	for p: String in files:
		var rep := Replay.load_file(p)
		var head: Dictionary = rep.head
		if head.is_empty():
			print("review: %s is not a replay" % p)
			fails += 1
			continue
		var r := lib.review(rep)
		ReviewOut.write(r, p.trim_suffix(Replay.EXT))
		if lessons != "off" and (not head.get("bot", false) or args.has("lessons_bot")):
			ReviewOut.update_lessons(lessons, r) # `bot` flag runs (our side = AI) would skew the human patterns
		var rp: Dictionary = r.replay
		if not rp.verified:
			fails += 1
		print(ReviewOut.md(r))
		print("review: wrote %s.review.md / .json" % ProjectSettings.globalize_path(p.trim_suffix(Replay.EXT)))
	quit(1 if fails else 0)

## replay paths for what: latest | all-new (no .review.json yet) | a file path
static func pick(what: String, dir: String) -> Array:
	if what != "latest" and what != "all-new":
		return [what] if FileAccess.file_exists(what) else []
	var names := MatchRec.list(dir)
	if names.is_empty():
		return []
	if what == "latest":
		return [dir.path_join(names[-1])]
	var out := []
	for n: String in names:
		if not FileAccess.file_exists(dir.path_join(n.trim_suffix(Replay.EXT) + ".review.json")):
			out.append(dir.path_join(n))
	return out
