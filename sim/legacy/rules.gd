
extends RefCounted
## FROZEN copy of scripts/core/rules.gd as last verified against the JS original (2026-11-05, chapter-1 parity). Never edit: sim/trace.gd + the parity test run on it.

## def = defense bonus, cost = move cost (INF = impassable for normal walkers)
const TERRAIN := {
	".": { "def": 0, "cost": 1 },
	"f": { "def": 10, "cost": 2 },
	"h": { "def": 15, "cost": 2 },
	"m": { "def": 20, "cost": 3 },
	"~": { "def": 0, "cost": INF, "water": true },
	"=": { "def": 0, "cost": 1 },
	"r": { "def": 0, "cost": 1 }, # path: same as open field, drawn as a dirt track that links villages, castles, bridges
	"v": { "def": 15, "cost": 1, "building": "village" },
	"c": { "def": 20, "cost": 1, "building": "castle" },
}

## move classes: foot, heavy (no mountain), fly (all cost 1, no terrain def), water (river ok), mount (hill/mountain cost 1)
## flags: capV/capC capture village/castle, antiAir bonus, aura (+atk adjacent allies), magic (ignores terrain def),
##        raise (graves -> ghost), siege (no move+attack, no counter), noGrave, buyable=false
const UNITS := {
	"hero": { "cost": 400, "atk": 60, "def": 20, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "capV": true, "capC": true },
	"soldier": { "cost": 150, "atk": 50, "def": 10, "mv": 4, "rmin": 1, "rmax": 1, "move": "foot", "capV": true },
	"archer": { "cost": 250, "atk": 45, "def": 5, "mv": 4, "rmin": 1, "rmax": 2, "move": "foot", "antiAir": 20, "shot": "arrow" },
	"drum": { "cost": 300, "atk": 30, "def": 10, "mv": 5, "rmin": 1, "rmax": 1, "move": "foot", "aura": 10 },
	"shaman": { "cost": 400, "atk": 40, "def": 10, "mv": 4, "rmin": 1, "rmax": 2, "move": "foot", "magic": true, "raise": true, "shot": "orb" },
	"elephant": { "cost": 500, "atk": 65, "def": 25, "mv": 3, "rmin": 1, "rmax": 1, "move": "heavy", "heavy": true },
	"bird": { "cost": 600, "atk": 60, "def": 15, "mv": 7, "rmin": 1, "rmax": 1, "move": "fly" },
	"catapult": { "cost": 700, "atk": 70, "def": 5, "mv": 3, "rmin": 2, "rmax": 4, "move": "heavy", "siege": true, "shot": "rock" },
	"ghost": { "cost": 150, "atk": 40, "def": 5, "mv": 4, "rmin": 1, "rmax": 1, "move": "foot", "noGrave": true, "buyable": false },
}
const BUY_ORDER := ["soldier", "archer", "drum", "shaman", "elephant", "bird", "catapult"]

## hero stat overrides (merged over UNITS.hero). tBonus = extra def on terrain, guard = +def to adjacent allies
const HEROES := {
	"trungtrac": { "atk": 60, "def": 20, "mv": 5, "move": "mount", "tBonus": { "h": 10, "m": 10 } },
	"trungnhi": { "atk": 70, "def": 15, "mv": 6, "move": "foot" },
	"lechan": { "atk": 60, "def": 20, "mv": 5, "move": "water", "guard": 10 },
	"todinh": { "atk": 65, "def": 20, "mv": 5, "move": "water" },
	"huyenlenh": { "atk": 55, "def": 15, "mv": 5, "move": "water" },
	"douy": { "atk": 55, "def": 25, "mv": 4, "move": "foot", "tBonus": { "f": 15 } },
	"hieuuy": { "atk": 65, "def": 15, "mv": 6, "move": "foot" },
	# chapter 2–3 (aura = +10 atk to adjacent allies, rmax 2 = shoots like an archer)
	"thanhthien": { "atk": 60, "def": 20, "mv": 5, "move": "foot", "aura": 10 },
	"batnan": { "atk": 55, "def": 15, "mv": 5, "move": "mount", "rmin": 1, "rmax": 2, "antiAir": 20 },
	"phungthichinh": { "atk": 60, "def": 20, "mv": 5, "move": "foot", "tBonus": { "f": 10, "h": 10 } },
	"batrieu": { "atk": 72, "def": 22, "mv": 5, "move": "foot" },
	"trieuquocdat": { "atk": 60, "def": 20, "mv": 5, "move": "mount", "guard": 10 },
	"mavien": { "atk": 65, "def": 20, "mv": 5, "move": "water" }, # same commander profile as todinh (one enemy commander look)
	"luulong": { "atk": 62, "def": 18, "mv": 6, "move": "foot" },
	"doanchi": { "atk": 58, "def": 20, "mv": 5, "move": "water" },
	"lucdan": { "atk": 66, "def": 24, "mv": 5, "move": "foot", "guard": 10 },
}

const RULES := {
	"startGold": 300, "incomeVillage": 50, "incomeCastle": 100, "heal": 20, "graveRounds": 2,
	"xpLevels": [100, 250, 450], "killXp": 50, "rankBonus": 5, "minDmgFrac": 0.15, "unitCap": 15,
}
