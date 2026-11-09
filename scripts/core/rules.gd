class_name Rules
extends RefCounted
## game rules + stats only. Names, icons, colors live in content/theme.gd.

## AE2 rules (docs/review/rules_compare.html). def = defense bonus, cost = move cost (INF = impassable)
## water: every walker may wade at cost 3 with 0 def; the water class (boat) pays 1; fliers pay 1 everywhere.
## buildings (Game reads only these fields, never the letter): building (name, can be owned), income (gold / turn to
## the owner), cap (unit flag needed to capture), heals ("owner" | "any"), sells (owner buys units here; counts as a
## castle for the loss rule), razeTo (a raze unit wrecks it into), repairTo + repairBy (unit flag that repairs it)
const TERRAIN := {
	".": { "def": 5, "cost": 1 },
	"f": { "def": 10, "cost": 2 },
	"h": { "def": 10, "cost": 2 },
	"m": { "def": 15, "cost": 3 },
	"~": { "def": 0, "cost": 3, "water": true },
	"=": { "def": 5, "cost": 1 },
	"r": { "def": 0, "cost": 1 }, # path: drawn as a dirt track that links villages, castles, bridges
	"v": { "def": 15, "cost": 1, "building": "village", "income": 30, "cap": "capV", "heals": "owner", "razeTo": "x" },
	"c": { "def": 15, "cost": 1, "building": "castle", "income": 50, "cap": "capC", "heals": "owner", "sells": true },
	"x": { "def": 15, "cost": 1, "repairTo": "v", "repairBy": "capV" }, # ruined village: no owner / income / heal
	"t": { "def": 15, "cost": 1, "heals": "any" }, # shrine: heals any side's unit standing on it, no owner, no income
}

## atk..atkMax = AE2 table attack; a hit rolls atk..atkMax-1 (AE2 never rolls the max).
## move classes: foot, fly (all cost 1), water (river cost 1, land as foot).
## flags (all optional; a new type needs only cost/atk/atkMax/def/mv/rmin/rmax/move):
##   capV/capC capture village/castle (= the TERRAIN `cap` flag); antiAir +atk vs fliers; vsType {type: +atk};
##   aura N: after acting, allies within 2 get +N atk until our next turn; poison N: a hit leaves the target -N atk / -N def
##   until our next turn; waterAtk / waterDef: bonus standing in water; raise "type": graves -> that type;
##   siege (no move+attack; no counter comes from rmin ≥ 2, not this flag); raze (wreck an enemy / unowned building with `razeTo` in range); noGrave;
##   noCap (not counted toward unitCap); buyable=false; heavy (bigger hit fx / knockback / sound)
##   AI: aiWeight (buy weight, default AI.DEFAULT_WEIGHT); aiValue (worth when scoring trades, default cost)
## mv = steps a unit really walks = AE2 units.bin move − 1 (orig destination needs > 0 steps left; ae2cmp/combat.md)
const UNITS := {
	"hero": {
		"cost": 200,
		"atk": 55,
		"atkMax": 65,
		"def": 20,
		"mv": 4,
		"rmin": 1,
		"rmax": 1,
		"move": "foot",
		"capV": true,
		"capC": true,
		"heavy": true,
		"aiValue": 900,
	},
	"soldier": { "cost": 150, "atk": 50, "atkMax": 55, "def": 5, "mv": 4, "rmin": 1, "rmax": 1, "move": "foot", "capV": true, "aiWeight": 3 },
	"archer": {
		"cost": 250,
		"atk": 50,
		"atkMax": 55,
		"def": 5,
		"mv": 4,
		"rmin": 1,
		"rmax": 2,
		"move": "foot",
		"antiAir": 15,
		"shot": "arrow",
		"aiWeight": 2,
	},
	"boat": {
		"cost": 300,
		"atk": 50,
		"atkMax": 55,
		"def": 10,
		"mv": 4,
		"rmin": 1,
		"rmax": 1,
		"move": "water",
		"waterAtk": 10,
		"waterDef": 15,
		"aiWeight": 0.8,
	},
	"shaman": { "cost": 400, "atk": 40, "atkMax": 45, "def": 5, "mv": 4, "rmin": 1, "rmax": 1, "move": "foot", "raise": "ghost", "aiWeight": 0.6 },
	"drum": {
		"cost": 500,
		"atk": 35,
		"atkMax": 40,
		"def": 10,
		"mv": 4,
		"rmin": 1,
		"rmax": 1,
		"move": "foot",
		"aura": 10,
		"vsType": { "ghost": 15 },
		"aiWeight": 0.5,
	},
	"wolf": { "cost": 600, "atk": 60, "atkMax": 65, "def": 15, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "poison": 10, "aiWeight": 1.2 },
	"elephant": { "cost": 600, "atk": 60, "atkMax": 70, "def": 30, "mv": 4, "rmin": 1, "rmax": 1, "move": "foot", "heavy": true, "aiWeight": 1.4 },
	"catapult": {
		"cost": 700,
		"atk": 50,
		"atkMax": 70,
		"def": 10,
		"mv": 3,
		"rmin": 2,
		"rmax": 4,
		"move": "foot",
		"siege": true,
		"raze": true,
		"shot": "rock",
		"heavy": true,
		"aiWeight": 0.7,
	},
	"bird": { "cost": 1000, "atk": 70, "atkMax": 80, "def": 25, "mv": 6, "rmin": 1, "rmax": 1, "move": "fly", "heavy": true, "aiWeight": 1 },
	"ghost": {
		"cost": 150,
		"atk": 40,
		"atkMax": 50,
		"def": 2,
		"mv": 4,
		"rmin": 1,
		"rmax": 1,
		"move": "foot",
		"noGrave": true,
		"noCap": true,
		"buyable": false,
	},
}
const BUY_ORDER := ["soldier", "archer", "boat", "shaman", "drum", "wolf", "elephant", "catapult", "bird"]

## the two commanders: same stats as UNITS.hero (AE2: every commander is equal). Only names / look / story differ.
const HEROES := {
	"anhhung": { }, # ours
	"tuonggiac": { }, # theirs
}

const RULES := {
	"startGold": 300,
	"heal": 20, # building income: TERRAIN
	# graves: ttl counts down at the start of every side's turn (AE2: 3) -> a grave lasts through the next turn of each side
	"graveRounds": 3,
	# xp: a hit gives dmg x victim quality; next level needs own quality x XP_SCALE (quality = atk + atkMax + def incl.
	# rank bonus), leftover carries,
	# at most 1 level per fight, max level 9, +2 atk / +2 def per level. Confirmed in the original AE2 bytecode
	# (docs/review/ae2_research.md).
	"xpScale": 200.0 / 3.0,
	"maxRank": 9,
	"rankBonus": 2,
	"unitCap": 100, # campaign default (AE2 RM MainDisplayable:3310); skirmish passes its own cap
	# hero rebuy: 200 + 200 per death so far, max 1000; the revived hero keeps its level / xp (AE2)
	"heroBase": 200,
	"heroStep": 200,
	"heroMax": 1000,
	# flat gold every side gets each turn on top of its buildings (AE2: none); per-game override only (s.rules, comeback research)
	"baseIncome": 0,
	# gold to the killer's side = bounty % of the victim's price per rank (veterans pay, recruits 0). AE2: none.
	# Per-game override only (s.rules, comeback research, docs/1v1.md "Lật kèo")
	"bounty": 0,
	# buyAE2: a bought unit acts the same turn; our castle may be bought on while one of our units stands there
	"buyAE2": true,
}

## RULES[key] unless this game overrides it (s.rules, set from def.rules); numeric rules only, missing = 0.
## Reads Game.RULES (tests may swap the tables)
static func of(s: Dictionary, key: String) -> int:
	var over: Dictionary = s.get("rules", { })
	var v: Variant = over[key] if over.has(key) else Game.RULES.get(key, 0)
	return type_convert(v, TYPE_INT)

## kill bounty (comeback research): bounty % x price x rank; commanders priced at heroBase, summons (not buyable) pay 0
static func bounty(s: Dictionary, u: Dictionary) -> int:
	var pct := of(s, "bounty")
	var rank: int = u.get("rank", 0)
	var base: Dictionary = Game.UNITS[u.type]
	if pct <= 0 or rank <= 0 or not base.get("buyable", true):
		return 0
	var price: int = of(s, "heroBase") if u.type == "hero" else base.cost
	@warning_ignore("integer_division")
	return price * pct * rank / 100
