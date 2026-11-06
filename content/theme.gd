extends RefCounted
# prose / map rows: one line each reads better
# gdlint: disable=max-line-length
## all names, icons, colors, UI wording. Swap this file to re-skin; scripts/core/rules.gd keeps the numbers.
## any unit / hero / terrain may set "img": "res://..." to replace the emoji / procedural drawing.
## "fig": a white silhouette (SVG) drawn as a standing piece on a small base, in the faction's "fig" colour.

## the one troop roster, used by both factions (same name + icon; only the faction colour differs)
const UNITS := {
	"hero": null,
	"soldier": {
		"name": "Bộ binh",
		"icon": "🗡️",
		"fig": "res://assets/units/soldier.svg",
		"desc": "Lính cầm giáo. Rẻ, chiếm được làng, sửa được làng hỏng.",
	},
	"archer": {
		"name": "Nỏ thủ",
		"icon": "🏹",
		"fig": "res://assets/units/archer.svg",
		"desc": "Bắn xa 1–2 ô; bắn từ 2 ô thì địch không đánh trả được. +15 công khi bắn rồng.",
	},
	"boat": {
		"name": "Thủy binh",
		"icon": "⛵",
		"fig": "res://assets/units/soldier.svg",
		"desc": "Quen sông nước: đi trên sông chỉ tốn 1 bước. Đứng dưới sông +10 công, +15 thủ.",
	},
	"shaman": {
		"name": "Thầy mo",
		"icon": "🌿",
		"fig": "res://assets/units/shaman.svg",
		"desc": "Gọi hồn lính ngã ngay cạnh thành âm binh đánh cho ta (cả lính địch ngã).",
	},
	"drum": {
		"name": "Trống đồng",
		"icon": "🥁",
		"fig": "res://assets/units/drum.svg",
		"desc": "Đánh trống xong (sau mọi lệnh): quân ta trong 2 ô +10 công tới lượt sau. +15 công khi đánh âm binh.",
	},
	"wolf": {
		"name": "Sói",
		"icon": "🐺",
		"fig": "res://assets/units/elephant.svg",
		"desc": "Sói rừng thuần làm quân. Chạy nhanh (6 bước). Cắn trúng thì địch bị thương: −10 công, −10 thủ tới lượt sau của ta.",
	},
	"elephant": { "name": "Voi chiến", "icon": "🐘", "fig": "res://assets/units/elephant.svg", "desc": "Thủ rất dày, đánh mạnh. Đắt." },
	"catapult": {
		"name": "Máy bắn đá",
		"icon": "🪨",
		"fig": "res://assets/units/catapult.svg",
		"desc": "Ném đá 2–4 ô. Đã đi thì không ném được lượt đó. Không đánh trả. Phá được làng địch hoặc làng chưa ai chiếm (thành làng hỏng).",
	},
	"bird": {
		"name": "Rồng",
		"icon": "🐉",
		"fig": "res://assets/units/bird.svg",
		"desc": "Bay: mọi ô (cả sông, núi) chỉ tốn 1 bước, đi 7. Mạnh nhất, đắt nhất. Nỏ thủ bắn rồng +15 công.",
	},
	"ghost": {
		"name": "Âm binh",
		"icon": "🩹",
		"fig": "res://assets/units/ghost.svg",
		"desc": "Hồn lính ngã được thầy mo gọi dậy. Không mua được, không tính vào giới hạn quân, không chiếm được làng.",
	},
}

## level titles (AE2 renames a unit every 2 levels, 4 tiers): index = min(level / 2, 3) -> 0-1, 2-3, 4-5, 6-9
const RANK_TITLES := ["", "lão luyện", "tinh nhuệ", "dũng mãnh"]

const THEME := {
	"title": "Công Thành Chiến",
	"tagline": "Hai Bà Trưng · chiến thuật theo lượt",
	"lede": "Năm 40, Hai Bà Trưng dựng cờ ở Hát Môn, đuổi quân Đông Hán khỏi Giao Chỉ. Hai năm sau, Mã Viện kéo đại quân sang. Hai chương, mười sáu trận.",
	"text": {
		"enemyTurn": "Lượt quân Hán",
		"skirmishTitle": "Đấu tự do · Đồng bằng sông Hồng",
		"skirmishBlurb": "Anh hùng đấu với Tướng giặc",
		"duelBlurb": "Hai người chung máy, hoặc đấu với máy",
		"duelTurn": "Lượt {turn} · {side}",
		"duelWin": "{side} thắng",
		"duelEnd_castlesLost": "{loser} mất hết thành, tướng cũng đã ngã.",
		"duelEnd_routed": "{loser} không còn quân, không còn thành.",
		"handoffTitle": "Lượt của {side}",
		"handoffSub": "Lượt {turn} · chạm để bắt đầu",
		"raiseVerb": "gọi hồn",
		"raiseButton": "🩹 Gọi hồn",
		"graveNote": "Lính ngã: thầy mo đứng cạnh gọi dậy được thành âm binh. Mất sau lượt kế của mỗi bên, hoặc khi có quân bước lên.",
		"graveName": "Lính ngã",
		"turnBanner": "Lượt {turn} · Quân ta",
		"captureCastle": "Chiếm thành!",
		"captureVillage": "Chiếm làng",
		"victory": "Đại thắng",
		"defeat": "Thất thủ",
		"introHeroP": "TƯỚNG TA",
		"introHeroE": "TƯỚNG ĐỊCH",
		"introUnitP": "QUÂN MỚI · PHE TA",
		"introUnitE": "QUÂN ĐỊCH MỚI",
		"hint_attack": "đánh mục tiêu viền vàng",
		"hint_capture": "chiếm",
		"hint_repair": "sửa",
		"hint_raze": "phá làng viền vàng",
		"razeText": "Phá làng!",
		"repairText": "Sửa xong làng",
		"hint_wait": "đi tới ô sáng rồi chờ",
		"buyTitle": "Mộ quân",
		"noEnemyHero": "quân địch",
		"tileVillage": "{capV} đứng vào làng rồi bấm Chiếm: +{income} vàng/lượt, hồi máu quân ta.",
		"tileRuin": "Làng bị {raze} phá. {capV} đứng vào rồi bấm Sửa làng; lượt sau mới chiếm được.",
		"tileCastle": "Chỉ {capC_l} chiếm được thành. Thành: +{income} vàng/lượt, mua lính, hồi máu. Có quân ta đứng trên thành vẫn mua được: lính mới phải bước ra ô khác.",
		"tileTemple": "Đền: không ai chiếm được. Quân phe nào đứng đây cũng hồi {heal} máu mỗi lượt, thủ +15.",
		"tileWater": "Mọi quân lội được nhưng tốn 3 bước và không được thủ. {water} chỉ tốn 1 bước, đứng dưới sông +10 công, +15 thủ.",
		"loseTip_heroFell": "Mẹo: giữ tướng sau hàng bộ binh; đứng trên đồi, làng, thành được thêm thủ.",
		"loseTip_castlesLost": "Mẹo: luôn để một quân đứng chặn trên thành khi địch có tướng ở gần.",
		"loseTip_routed": "Mẹo: chiếm làng sớm để có vàng mua quân; đừng đem lính lẻ ra đánh.",
		"loseTip_timeUp": "Mẹo: đi đường mòn cho nhanh, để bộ binh chặn đường đuổi phía sau.",
		"loseTip_heroKilled": "",
	},
	## win types: brief = goal line of the mission opening, bar = top bar. {eh} enemy commander, {hero} ours, {n} count, {turns} limit, {left} turns left
	"goals": {
		"castles": { "brief": "Chiếm hết thành của địch và hạ {eh} (hoặc diệt sạch quân lẫn thành).", "bar": "Chiếm {n} thành + hạ {eh}" },
		"rout": { "brief": "Diệt hết quân địch.", "bar": "Diệt hết địch (còn {n})" },
		"hero": { "brief": "Hạ {eh}.", "bar": "Hạ {eh}" },
		"survive": { "brief": "Giữ vững đến hết lượt {turns}.", "bar": "Giữ vững: còn {left} lượt" },
		"reach": { "brief": "Đưa {hero} tới ô cờ vàng{within}.", "bar": "Đưa {hero} tới cờ vàng{left_txt}" },
	},
	## end card line per winner side + engine reason
	"ends": {
		"p": {
			"routed": "Đã quét sạch quân địch.",
			"castlesLost": "Đã chiếm hết thành và hạ tướng địch.",
			"heroKilled": "{eh} đã bị hạ.",
			"survived": "Đã giữ vững đến cùng.",
			"reached": "{hero} đã tới nơi an toàn.",
		},
		"e": {
			"heroFell": "{hero} đã ngã.",
			"castlesLost": "Mất hết thành, tướng ta cũng đã ngã.",
			"heroKilled": "{hero} đã ngã, ta không còn thành nào.",
			"routed": "Quân ta đã tan.",
			"timeUp": "Không kịp tới nơi, giặc đã khép vòng vây.",
		},
	},
	"factions": {
		"p": {
			"name": "Quân Hai Bà Trưng",
			"short": "Quân ta",
			"duelShort": "Quân Hai Bà", # 1 vs 1 with two humans: no "ta" / "địch"
			"body": "#7a2219",
			"body2": "#a8372a",
			"ring": "#f0a07c",
			"glow": "#ff9a6b",
			"roof": "#c2412f",
			"fig": "#e0503f", # standing piece silhouette
		},
		"e": {
			"name": "Quân Đông Hán",
			"short": "Quân Hán",
			"duelShort": "Quân Hán",
			"body": "#1f2740",
			"body2": "#34406a",
			"ring": "#d8c27a",
			"glow": "#f0d890",
			"roof": "#3d4a78",
			"fig": "#5b7bd0",
		},
		"n": { "roof": "#7a6a55" },
	},
	"terrain": {
		".": { "name": "Đồng lúa", "paint": "field", "base": "#5a7a3a", "line": "#6d8f44" },
		"r": {
			"name": "Đường mòn",
			"paint": "road",
			"base": "#5a7a3a",
			"line": "#6d8f44",
			"dirt": "#a48a58",
			"dirt2": "#7c6740",
			"pebble": "#c2ab7a",
		},
		"f": { "name": "Rừng", "paint": "forest", "base": "#3d5a2a", "tree": "#22401b", "tree2": "#2f5523" },
		"h": { "name": "Đồi", "paint": "hill", "base": "#77733f", "hill": "#959150", "hill2": "#aaa65d" },
		"m": { "name": "Núi", "paint": "mountain", "base": "#625a4e", "rock": "#8a7f6e", "rock2": "#6f6556", "snow": "#e4ddcd" },
		"~": { "name": "Sông", "paint": "water", "base": "#24577a", "wave": "#4c8db0", "deep": "#1c4766" },
		"=": {
			"name": "Cầu tre",
			"paint": "bridge",
			"base": "#24577a",
			"wave": "#4c8db0",
			"deep": "#1c4766",
			"plank": "#8a6438",
			"plank2": "#5e4124",
		},
		"v": { "name": "Làng", "paint": "village", "base": "#5a7a3a", "line": "#6d8f44", "wall": "#dcc6a0" },
		"c": { "name": "Thành", "paint": "castle", "base": "#5d6a3c", "wall": "#b0a48c", "wall2": "#8c816c" },
		"x": { "name": "Làng hỏng", "paint": "village", "base": "#5a7a3a", "line": "#6d8f44", "wall": "#a89c88" },
		"t": { "name": "Đền", "paint": "village", "base": "#5a7a3a", "line": "#6d8f44", "wall": "#c9b48a" },
	},
	"units": {
		# both sides field the same troops (same name, same icon); only the faction colour tells them apart
		"p": UNITS,
		"e": UNITS,
	},
	"heroes": {
		# exactly two commanders for every campaign: same look + stats everywhere. Story names live in "people".
		"anhhung": {
			"side": "p",
			"name": "Anh hùng",
			"icon": "👑",
			"fig": "res://assets/units/hero_p.svg",
			"blurb": "Người cầm quân của ta trong mọi trận. Chiếm được cả làng lẫn thành. Ngã thì mua lại ở thành, giữ nguyên cấp; mỗi lần ngã giá mua lại +200.",
		},
		"tuonggiac": {
			"side": "e",
			"name": "Tướng giặc",
			"icon": "🪓",
			"fig": "res://assets/units/hero_e.svg",
			"blurb": "Kẻ cầm đầu quân giặc trong mọi trận. Cùng sức với tướng ta.",
		},
	},
	"people": {
		# story voices (dialogue only); side "e" = speaks for the enemy
		"trungtrac": { "name": "Trưng Trắc", "icon": "👑" },
		"todinh": { "name": "Tô Định", "icon": "🎖️", "side": "e" },
		"mavien": { "name": "Mã Viện", "icon": "🎖️", "side": "e" },
		"trungnhi": { "name": "Trưng Nhị", "icon": "⚔️" },
		"lechan": { "name": "Lê Chân", "icon": "⛵" },
		"thanhthien": { "name": "Thánh Thiên", "icon": "🔥" },
		"batnan": { "name": "Bát Nàn", "icon": "🦅" },
		"phungthichinh": { "name": "Phùng Thị Chính", "icon": "👶" },
		"huyenlenh": { "name": "Huyện lệnh", "icon": "🏮", "side": "e" },
		"douy": { "name": "Đô úy", "icon": "🪖", "side": "e" },
		"hieuuy": { "name": "Hiệu úy", "icon": "🐴", "side": "e" },
		"luulong": { "name": "Lưu Long", "icon": "🐉", "side": "e" },
		"doanchi": { "name": "Đoàn Chí", "icon": "⚓", "side": "e" },
		"bamanthien": { "name": "Bà Man Thiện", "icon": "👵" },
		"lactuong": { "name": "Lạc tướng", "icon": "🧔" },
		"danlang": { "name": "Dân làng", "icon": "👨" },
		"truyenthuyet": { "name": "Lời kể", "icon": "📖" },
		"thamtu": { "name": "Thám tử", "icon": "🕵️" },
		# mission opening (StoryOverlay): history line first, goal line last
		"sutich": { "name": "Sử tích", "icon": "📜" },
		"muctieu": { "name": "Mục tiêu", "icon": "🎯" },
	},
}
