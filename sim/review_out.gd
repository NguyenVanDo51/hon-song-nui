extends RefCounted
## match review output (report from sim/review_lib.gd): <id>.review.md (terse, for Claude), <id>.review.json (same data),
## docs/review/match_lessons.md (Vietnamese: one entry per match + recurring patterns, rebuilt from each entry's data line).

const ReviewLib := preload("res://sim/review_lib.gd")

const DATA := "<!-- data "
const DATA_END := " -->"
## tag -> Vietnamese label (lessons file)
const VN := {
	"hero_killable": "để tướng trong tầm địch giết được",
	"lone_unit_killed": "quân lẻ bị giết",
	"missed_sure_kill": "bỏ lỡ nước giết chắc",
	"castle_lost": "mất thành",
	"village_lost": "mất làng",
	"gold_unspent": "dư vàng khi có thành trống",
	"fed_promotion": "đánh làm địch lên cấp",
	"no_retreat": "máu thấp không rút về ô hồi máu",
	"missed_win": "bỏ lỡ nước thắng",
	"bot_blunder": "bot đi kém planner Khó v3",
	"bot_exploited": "bot bị khai thác (người đáp hay hơn mô hình đối thủ của bot)",
	"bot_lone_unit": "bot để quân lẻ trong tầm",
	"bot_lone_unit_punished": "bot để quân lẻ, bị giết",
	"bot_hero_exposed": "bot để tướng giết được",
	"bot_hero_exposed_punished": "bot để tướng hở, tướng chết",
	"bot_castle_open": "bot bỏ trống thành trong tầm chiếm",
	"bot_castle_open_punished": "bot bỏ trống thành, bị chiếm",
}

# ---------- per match ----------
static func md(r: Dictionary) -> String:
	var L := PackedStringArray()
	var res: Dictionary = r.result
	var rp: Dictionary = r.replay
	var tm: Dictionary = r.timing
	var ai: Dictionary = r.ai
	var humans: Array = r.humans
	L.append("# Review %s" % r.id)
	L.append(
		"- mode: %s · map %s · p=%s e=%s%s"
		% [r.kind, r.map, ai.get("p", "?"), ai.get("e", "?"), " · `bot` flag (human side = default AI)" if r.bot_flag else ""]
	)
	var won := "-"
	if res.winner != null:
		won = "human won" if humans.has(res.winner) else "human lost"
	var fin_txt := "%s won (%s), turn %s, %s" % [res.winner, res.reason, res.turns, won] if res.finished else "unfinished at turn %s" % res.turns
	L.append("- result: " + fin_txt)
	var div: Dictionary = rp.divergence
	var ver := "verified (%d steps, every hash ok)" % rp.steps
	if not div.is_empty():
		ver = "DIVERGED at record %s (t%s %s): %s -> analysis stops there" % [div.get("i"), div.get("turn"), div.get("side"), div.why]
	L.append("- replay: " + ver + (", %d bad lines" % rp.bad_lines if rp.bad_lines else ""))
	var tl: Array = r.timeline
	if tl.size() > 0:
		var last: Dictionary = tl[-1]
		var lg: Dictionary = last.gold
		var lc: Dictionary = last.castles
		var lu: Dictionary = last.units
		var ev: float = last.eval
		var ev_txt := "won" if ev >= ReviewLib.CLAMP else "lost" if ev <= -ReviewLib.CLAMP else "%+.0f" % ev
		L.append(
			"- eval (%s view, AIPlan.evaluate): end %s · units p%d e%d · castles p%d e%d · gold p%d e%d"
			% [r.persp, ev_txt, lu.p, lu.e, lc.p, lc.e, lg.p, lg.e]
		)
	L.append("- analysis: %.1f s (%d planner runs, %.1f s)" % [tm.sec, tm.planner_runs, tm.planner_sec])
	L.append("")
	L.append("## Turning points (eval swing, %s view)" % r.persp)
	var tps: Array = r.turning_points
	if tps.is_empty():
		L.append("- none")
	for tp: Dictionary in tps:
		var what: Array = tp.what
		var line := "- t%s %s (%s) %+.0f: %s" % [tp.turn, tp.side, tp.who, tp.delta, "; ".join(what)]
		var at: Array = tp.at
		if not at.is_empty():
			line += " · at (%d,%d)" % [at[0], at[1]]
		if tp.better != "":
			line += " · better: " + str(tp.better)
		L.append(line)
	L.append("")
	L.append("## Human mistakes (2-ply loss vs hard v3 from the same start)")
	var hm: Array = r.human_mistakes
	if hm.is_empty():
		L.append("- none found")
	for i in hm.size():
		var m: Dictionary = hm[i]
		var labels: Array = m.labels
		var tags := []
		for l: Dictionary in labels:
			tags.append("%s: %s" % [l.tag, l.note])
		L.append("%d. t%s %s loss %+.0f%s" % [i + 1, m.turn, m.side, m.loss, (" · " + "; ".join(tags)) if tags.size() else ""])
		L.append("   - played: %s" % _cut(str(m.played)))
		L.append("   - hard v3: %s" % _cut(str(m.better)))
	L.append("")
	L.append("## Bot weaknesses")
	var bw: Array = r.bot_weaknesses
	if bw.is_empty():
		L.append("- none found")
	for b: Dictionary in bw.slice(0, 12):
		var line := "- t%s %s (%s) %s" % [b.turn, b.side, b.level, b.tag]
		if b.has("gap"):
			line += " gap %.0f" % b.gap
		if b.has("at"):
			var at: Array = b.at
			line += " @(%d,%d)" % [at[0], at[1]]
		line += ": " + _cut(str(b.note))
		if b.has("reply"):
			line += " · human reply: " + _cut(str(b.reply))
		if b.has("better"):
			line += " · planner: " + _cut(str(b.better))
		L.append(line)
	if bw.size() > 12:
		L.append("- … %d more in the json" % (bw.size() - 12))
	var bt: Dictionary = r.bot_tags
	var ht: Dictionary = r.human_tags
	L.append("- tag counts: " + _counts(bt))
	L.append("- human tag counts: " + _counts(ht))
	L.append("")
	L.append("## Scenario files")
	var sc: Array = r.scenarios
	if sc.is_empty():
		L.append("- none")
	for p: String in sc:
		L.append("- " + p)
	return "\n".join(L) + "\n"

static func _cut(s: String, n := 220) -> String:
	return s if s.length() <= n else s.substr(0, n) + "…"

static func _counts(d: Dictionary) -> String:
	if d.is_empty():
		return "-"
	var keys := d.keys()
	keys.sort()
	var out := []
	for k: String in keys:
		out.append("%s %d" % [k, d[k]])
	return ", ".join(out)

## <base>.review.md + <base>.review.json beside the replay
static func write(r: Dictionary, base: String) -> void:
	_save(base + ".review.md", md(r))
	_save(base + ".review.json", JSON.stringify(r, "  ", false))

static func _save(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null or not f.store_string(text):
		push_warning("review: write %s failed" % path)

# ---------- lessons (docs/review/match_lessons.md) ----------
## one entry per match (data kept in the file), recurring patterns rebuilt over every entry
static func update_lessons(path: String, r: Dictionary) -> void:
	var entries := read_entries(path)
	var e := entry_of(r)
	entries = entries.filter(
		func(x: Dictionary) -> bool:
			return x.id != e.id,
	)
	entries.append(e)
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.id) > str(b.id),
	)
	_save(path, lessons_md(entries))

static func read_entries(path: String) -> Array:
	var out := []
	if not FileAccess.file_exists(path):
		return out
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with(DATA) and line.ends_with(DATA_END):
			var v: Variant = JSON.parse_string(line.substr(DATA.length(), line.length() - DATA.length() - DATA_END.length()))
			if v is Dictionary:
				out.append(Replay.ints(v))
	return out

static func entry_of(r: Dictionary) -> Dictionary:
	var res: Dictionary = r.result
	var ai: Dictionary = r.ai
	var humans: Array = r.humans
	var bots := []
	for sd: String in ["p", "e"]:
		if not humans.has(sd):
			bots.append("%s=%s" % [sd, ai.get(sd, "?")])
	var bot_notes := []
	var bw: Array = r.bot_weaknesses
	for b: Dictionary in bw:
		if b.tag == "bot_exploited" or b.tag == "bot_blunder" or b.get("punished", false):
			bot_notes.append(_safe("t%s %s: %s" % [b.turn, b.tag, _cut(str(b.note), 120)]))
		if bot_notes.size() >= 3:
			break
	var human_notes := []
	var hm: Array = r.human_mistakes
	for m: Dictionary in hm.slice(0, 3):
		var tags := []
		var labels: Array = m.labels
		for l: Dictionary in labels:
			tags.append(l.tag)
		human_notes.append(_safe("t%s loss %+.0f %s" % [m.turn, m.loss, ",".join(tags)]))
	var won := ""
	if res.winner != null:
		won = "người thắng" if humans.has(res.winner) else "người thua"
	return {
		"id": r.id,
		"date": r.date,
		"kind": r.kind,
		"map": r.map,
		"bots": " ".join(bots) if bots.size() else "2 người",
		"winner": str(res.winner) if res.winner != null else "-",
		"result": (won if res.finished else "chưa xong") + ("" if _verified(r) else ", replay lệch"),
		"turns": res.turns,
		"human_tags": r.human_tags,
		"bot_tags": r.bot_tags,
		"bot_notes": bot_notes,
		"human_notes": human_notes,
	}

static func _verified(r: Dictionary) -> bool:
	var rp: Dictionary = r.replay
	var ok: bool = rp.verified
	return ok

static func _safe(s: String) -> String:
	return s.replace("-->", "->").replace("\n", " ")

static func lessons_md(entries: Array) -> String:
	var L := PackedStringArray()
	L.append("# Bài học từ các trận đã ghi")
	L.append("")
	L.append("Tự sinh bởi `tools/review_match.sh` (`sim/review.gd`), README \"Ghi trận / phân tích\". Không sửa tay: mỗi lần chạy")
	L.append("dựng lại cả file từ dòng `<!-- data ... -->` của từng trận (phân tích lại 1 trận = thay mục cũ). Ván cờ `bot` không vào đây.")
	L.append("Chi tiết trận: `<id>.review.md` cạnh file `.replay`.")
	L.append("")
	L.append("## Mẫu lặp lại (%d trận)" % entries.size())
	for who: String in ["human_tags", "bot_tags"]:
		var n_match := { }
		var n_all := { }
		for e: Dictionary in entries:
			var tags: Dictionary = e.get(who, { })
			for k: String in tags:
				var c: int = tags[k]
				var nm: int = n_match.get(k, 0)
				var na: int = n_all.get(k, 0)
				n_match[k] = nm + 1
				n_all[k] = na + c
		var keys := n_match.keys()
		keys.sort_custom(
			func(a: String, b: String) -> bool:
				return n_match[a] > n_match[b] or (n_match[a] == n_match[b] and n_all[a] > n_all[b]),
		)
		var head := "- Người chơi:" if who == "human_tags" else "- Bot:"
		if keys.is_empty():
			L.append(head + " chưa có")
			continue
		L.append(head)
		for k: String in keys.slice(0, 8):
			var nm: int = n_match[k]
			L.append("  - %s (`%s`): %d trận, %d lần%s" % [VN.get(k, k), k, nm, n_all[k], " — lặp lại" if nm >= 2 else ""])
	L.append("")
	L.append("## Các trận (mới nhất trước)")
	for e: Dictionary in entries:
		L.append("")
		L.append("### %s · %s · %s · %s · thắng: %s (%s, %s lượt)" % [e.date, e.kind, e.map, e.bots, e.winner, e.result, e.turns])
		var bn: Array = e.bot_notes
		var hn: Array = e.human_notes
		L.append("- Bot yếu: " + ("; ".join(bn) if bn.size() else "không thấy"))
		L.append("- Người chơi: " + ("; ".join(hn) if hn.size() else "không thấy lỗi lớn"))
		L.append(DATA + JSON.stringify(e, "", true) + DATA_END)
	return "\n".join(L) + "\n"
