extends RefCounted
# gdlint: disable=max-line-length
## "Thử thách" kingdom map (scripts/ui/world_map.gd): one node per level, the march from the south-west border to the
## capital in the north-east (premise "Ngọn Lửa Lâu Đài"). Units: map viewbox VB (x right, y down). Kept out of the
## level DEFs on purpose (old `pos` / `region` keys were removed with the chapters). Test: every level placed, in VB,
## spaced, regions cover every level.

const VB := Vector2(140, 110)

## level id -> node position
const POS := {
	# Biên Giới (south-west)
	"t01": Vector2(10, 98),
	"t02": Vector2(20, 92),
	"t03": Vector2(13, 82),
	"m01": Vector2(24, 76),
	"m02": Vector2(34, 86),
	"m03": Vector2(32, 68),
	"m04": Vector2(42, 76),
	# Vùng Sông (south, down to the coast)
	"g01": Vector2(52, 70),
	"m05": Vector2(54, 90),
	"g02": Vector2(65, 94),
	"m06": Vector2(72, 82),
	"g03": Vector2(68, 68),
	"g04": Vector2(82, 70),
	"m07": Vector2(88, 84),
	"g05": Vector2(98, 74),
	"m08": Vector2(102, 88),
	"g06": Vector2(110, 98),
	"m09": Vector2(120, 88),
	"g07": Vector2(112, 78),
	"m10": Vector2(124, 70),
	# Vùng Núi (the middle, back west)
	"g08": Vector2(114, 58),
	"g09": Vector2(102, 60),
	"m11": Vector2(93, 50),
	"g10": Vector2(83, 57),
	"m12": Vector2(74, 48),
	"g11": Vector2(64, 38),
	"g12": Vector2(60, 54),
	"m13": Vector2(48, 58),
	"g13": Vector2(52, 45),
	# Pháo Đài (north-west mountains: the retreat)
	"m14": Vector2(41, 50),
	"g14": Vector2(29, 57),
	"g15": Vector2(25, 43),
	"m15": Vector2(18, 29),
	"g16": Vector2(31, 21),
	"m16": Vector2(45, 30),
	# Kinh Đô (north-east)
	"g17": Vector2(60, 22),
	"g18": Vector2(76, 15),
	"g19": Vector2(94, 22),
	"g20": Vector2(114, 16),
}

## region name, label spot, level ids (in march order). A region is retaken when all its levels are won.
const REGIONS := [
	{ "name": "Biên Giới", "at": Vector2(20, 106), "ids": ["t01", "t02", "t03", "m01", "m02", "m03", "m04"] },
	{
		"name": "Vùng Sông",
		"at": Vector2(84, 104),
		"ids": ["g01", "m05", "g02", "m06", "g03", "g04", "m07", "g05", "m08", "g06", "m09", "g07", "m10"],
	},
	{ "name": "Vùng Núi", "at": Vector2(86, 41), "ids": ["g08", "g09", "m11", "g10", "m12", "g11", "g12", "m13", "g13"] },
	{ "name": "Pháo Đài", "at": Vector2(14, 14), "ids": ["m14", "g14", "g15", "m15", "g16", "m16"] },
	{ "name": "Kinh Đô", "at": Vector2(100, 6), "ids": ["g17", "g18", "g19", "g20"] },
]

## coast: the sea is the area east of this line (top -> bottom), closed along the right / bottom edges
const COAST := [
	Vector2(132, 0),
	Vector2(128, 14),
	Vector2(134, 30),
	Vector2(130, 46),
	Vector2(133, 60),
	Vector2(131, 74),
	Vector2(128, 86),
	Vector2(124, 98),
	Vector2(116, 110),
]

## rivers: [width, points] smoothed through the points (Catmull-Rom)
const RIVERS := [
	[
		2.2,
		[
			Vector2(70, 2),
			Vector2(70, 14),
			Vector2(70, 30),
			Vector2(69, 42),
			Vector2(66, 58),
			Vector2(62, 64),
			Vector2(62, 74),
			Vector2(78, 77),
			Vector2(92, 92),
			Vector2(106, 104),
			Vector2(116, 110),
		],
	],
	[1.4, [Vector2(14, 64), Vector2(28, 62), Vector2(42, 64), Vector2(56, 64), Vector2(62, 64)]],
]

## lakes: [centre, rx, ry]
const LAKES := [[Vector2(60, 100), 5.0, 3.0], [Vector2(80, 44), 4.0, 2.6]]

## mountain peaks [x, y, size]
const PEAKS := [
	[8, 18, 6.0],
	[15, 10, 7.0],
	[24, 14, 5.0],
	[38, 12, 6.0],
	[10, 38, 5.0],
	[36, 38, 5.0],
	[48, 14, 4.5],
	[86, 50, 4.0],
	[99, 46, 4.5],
	[104, 54, 3.5],
	[58, 30, 4.0],
	[128, 40, 3.5],
]

## forest clumps [x, y]
const WOODS := [
	[44, 94],
	[6, 74],
	[28, 98],
	[96, 64],
	[106, 70],
	[78, 60],
	[90, 62],
	[54, 34],
	[40, 62],
	[22, 50],
	[86, 28],
	[120, 30],
	[104, 34],
	[16, 90],
]

## swamp / reed marks [x, y]
const REEDS := [[33, 61], [26, 60], [114, 92]]
