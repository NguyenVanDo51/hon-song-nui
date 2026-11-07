extends RefCounted
## level recipes for sim/levelgen.gd (keys: .claude/skills/level-maker/SKILL.md). One entry per generated level, id gNN.
## `order` slots between the hand-made levels (m01 = 10 … m16 = 160); pacing table: docs/content.md.

const RECIPES := [
	{
		"id": "g00",
		"title": "Mẫu",
		"order": 5,
		"tier": "mid",
		"ai": "normal",
		"w": 15,
		"h": 10,
		"castles": { "p": 1, "e": 1 },
		"villages": 6,
		"river": "v",
		"bridges": 2,
		"rough": 0.3,
		"temples": 1,
		"sym": true,
		"win": { "type": "castles" },
		"allowed": { "p": ["soldier", "archer"], "e": ["soldier", "archer"] },
		"gold": { "p": 300, "e": 300 },
		"start": { "p": ["hero", "soldier"], "e": ["hero", "soldier"] },
		"waves": [],
		"night": false,
		"unitCap": 15,
		"stars": { "turns": 12 },
		"newUnits": [],
	},
]
