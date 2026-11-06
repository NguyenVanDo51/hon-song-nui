class_name Rules
extends RefCounted
## game rules + stats only. Names, icons, colors live in content/theme.gd.

## AE2 rules (docs/review/rules_compare.html). def = defense bonus, cost = move cost (INF = impassable)
## water: every walker may wade at cost 3 with 0 def; the water class (boat) pays 1; fliers pay 1 everywhere.
const TERRAIN := {
	".": { "def": 5, "cost": 1 },
	"f": { "def": 10, "cost": 2 },
	"h": { "def": 10, "cost": 2 },
	"m": { "def": 15, "cost": 3 },
	"~": { "def": 0, "cost": 3, "water": true },
	"=": { "def": 5, "cost": 1 },
	"r": { "def": 0, "cost": 1 }, # path: drawn as a dirt track that links villages, castles, bridges
	"v": { "def": 15, "cost": 1, "building": "village" },
	"c": { "def": 15, "cost": 1, "building": "castle" },
	"x": { "def": 15, "cost": 1, "ruin": true }, # ruined village: no owner / income / heal; a capV unit repairs it -> "v"
	"t": { "def": 15, "cost": 1, "temple": true }, # shrine: heals any side's unit standing on it, no owner, no income
}

## atk..atkMax = AE2 table attack; a hit rolls atk..atkMax-1 (AE2 never rolls the max). move classes: foot, fly (all cost 1), water (river cost 1, land as foot).
## flags: capV/capC capture village/castle; antiAir +atk vs fliers; vsGhost +atk vs ghosts; aura: after acting, allies
##        within 2 get +atk until our next turn; poison: a hit leaves the target -10 atk / -10 def until our next turn;
##        waterAtk / waterDef: bonus standing in water; raise (graves -> ghost); siege (no move+attack, no counter);
##        raze (wreck an enemy / unowned village in range -> "x"); noGrave; noCap (not counted toward unitCap); buyable=false
const UNITS := {
	"hero": { "cost": 200, "atk": 55, "atkMax": 65, "def": 20, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "capV": true, "capC": true },
	"soldier": { "cost": 150, "atk": 50, "atkMax": 55, "def": 5, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "capV": true },
	"archer": { "cost": 250, "atk": 50, "atkMax": 55, "def": 5, "mv": 5, "rmin": 1, "rmax": 2, "move": "foot", "antiAir": 15, "shot": "arrow" },
	"boat": { "cost": 300, "atk": 50, "atkMax": 55, "def": 10, "mv": 5, "rmin": 1, "rmax": 1, "move": "water", "waterAtk": 10, "waterDef": 15 },
	"shaman": { "cost": 400, "atk": 40, "atkMax": 45, "def": 5, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "raise": true },
	"drum": { "cost": 500, "atk": 35, "atkMax": 40, "def": 10, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "aura": 10, "vsGhost": 15 },
	"wolf": { "cost": 600, "atk": 60, "atkMax": 65, "def": 15, "mv": 6, "rmin": 1, "rmax": 1, "move": "foot", "poison": 10 },
	"elephant": { "cost": 600, "atk": 60, "atkMax": 70, "def": 30, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot" },
	"catapult": { "cost": 700, "atk": 50, "atkMax": 70, "def": 10, "mv": 4, "rmin": 2, "rmax": 4, "move": "foot", "siege": true, "raze": true, "shot": "rock" },
	"bird": { "cost": 1000, "atk": 70, "atkMax": 80, "def": 25, "mv": 7, "rmin": 1, "rmax": 1, "move": "fly" },
	"ghost": { "cost": 150, "atk": 40, "atkMax": 50, "def": 2, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "noGrave": true, "noCap": true, "buyable": false },
}
const BUY_ORDER := ["soldier", "archer", "boat", "shaman", "drum", "wolf", "elephant", "catapult", "bird"]

## the two commanders: same stats as UNITS.hero (AE2: every commander is equal). Only names / look / story differ.
const HEROES := {
	"anhhung": {}, # ours
	"tuonggiac": {}, # theirs
}

const RULES := {
	"startGold": 300, "incomeVillage": 30, "incomeCastle": 50, "heal": 20,
	# graves: ttl counts down at the start of every side's turn (AE2: 3) -> a grave lasts through the next turn of each side
	"graveRounds": 3,
	# xp: a hit gives dmg x victim quality; next level needs own quality x XP_SCALE (quality = atk + atkMax + def incl.
	# rank bonus), leftover carries,
	# at most 1 level per fight, max level 9, +2 atk / +2 def per level. Confirmed in the original AE2 bytecode
	# (docs/review/ae2_research.md).
	"xpScale": 200.0 / 3.0, "maxRank": 9, "rankBonus": 2,
	"unitCap": 100, # campaign default (AE2 RM MainDisplayable:3310); skirmish passes its own cap
	# hero rebuy: 200 + 200 per death so far, max 1000; the revived hero keeps its level / xp (AE2)
	"heroBase": 200, "heroStep": 200, "heroMax": 1000,
	# buyAE2: a bought unit acts the same turn; our castle may be bought on while one of our units stands there
	"buyAE2": true,
}
