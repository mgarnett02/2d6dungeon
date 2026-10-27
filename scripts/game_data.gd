extends RefCounted
## Static tables: weapons, manoeuvres, creatures and room flavour.
## These are original tables written in the spirit of 2D6 Dungeon.

const Dice = preload("res://scripts/dice.gd")

const EFFECT_TEXT := {
	"": "",
	"pierce": "ignores armour",
	"guard": "blocks 3 from the next hit",
	"stun": "enemy skips its next attack",
	"bleed": "2 damage for 3 turns",
	"drain": "heals you for half the damage",
}

## Each manoeuvre fires when the two attack dice show its pair (in either order).
const WEAPONS := {
	"Rusty Sword": {"price": 0, "moves": [
		{"name": "Slash", "pair": [5, 6], "bonus": 2, "effect": ""},
		{"name": "Hack", "pair": [4, 6], "bonus": 1, "effect": ""},
		{"name": "Thrust", "pair": [3, 4], "bonus": 1, "effect": "pierce"},
		{"name": "Parry", "pair": [1, 2], "bonus": 0, "effect": "guard"},
	]},
	"Hand Axe": {"price": 25, "moves": [
		{"name": "Cleave", "pair": [5, 6], "bonus": 3, "effect": ""},
		{"name": "Chop", "pair": [4, 5], "bonus": 1, "effect": ""},
		{"name": "Hew", "pair": [3, 6], "bonus": 1, "effect": "bleed"},
		{"name": "Hook", "pair": [2, 3], "bonus": 0, "effect": "stun"},
	]},
	"Spear": {"price": 30, "moves": [
		{"name": "Impale", "pair": [5, 6], "bonus": 2, "effect": "pierce"},
		{"name": "Lunge", "pair": [4, 5], "bonus": 1, "effect": "pierce"},
		{"name": "Jab", "pair": [3, 6], "bonus": 0, "effect": ""},
		{"name": "Sweep", "pair": [1, 4], "bonus": 0, "effect": "stun"},
		{"name": "Brace", "pair": [2, 3], "bonus": 0, "effect": "guard"},
	]},
	"Twin Daggers": {"price": 40, "moves": [
		{"name": "Flurry", "pair": [5, 6], "bonus": 2, "effect": "bleed"},
		{"name": "Cut", "pair": [4, 5], "bonus": 1, "effect": "bleed"},
		{"name": "Stab", "pair": [3, 6], "bonus": 1, "effect": "pierce"},
		{"name": "Gouge", "pair": [2, 4], "bonus": 0, "effect": "stun"},
		{"name": "Slip", "pair": [1, 2], "bonus": 0, "effect": "guard"},
	]},
	"Warhammer": {"price": 45, "moves": [
		{"name": "Smash", "pair": [5, 6], "bonus": 4, "effect": ""},
		{"name": "Crush", "pair": [4, 6], "bonus": 2, "effect": "pierce"},
		{"name": "Ring the Bell", "pair": [3, 5], "bonus": 0, "effect": "stun"},
		{"name": "Haft Block", "pair": [1, 2], "bonus": 0, "effect": "guard"},
	]},
}

## Manoeuvres learned from levelling up or the town trainer. They work with any weapon.
const LEARNABLE := [
	{"name": "Riposte", "pair": [2, 5], "bonus": 1, "effect": "guard"},
	{"name": "Feint", "pair": [1, 4], "bonus": 0, "effect": "stun"},
	{"name": "Rend", "pair": [2, 6], "bonus": 1, "effect": "bleed"},
	{"name": "Pommel Strike", "pair": [1, 5], "bonus": 0, "effect": "stun"},
	{"name": "Leech Cut", "pair": [1, 6], "bonus": 0, "effect": "drain"},
	{"name": "Overhead Blow", "pair": [3, 5], "bonus": 2, "effect": ""},
	{"name": "Low Cut", "pair": [2, 4], "bonus": 1, "effect": "bleed"},
	{"name": "Shoulder Charge", "pair": [1, 3], "bonus": 1, "effect": ""},
]

## Creatures by tier. Tier = dungeon level; deeper levels reuse the last tier, made tougher.
## hit = the 2d6 total the creature needs to land a blow.
const CREATURES := [
	[
		{"name": "Giant Rat", "hp": 6, "armor": 0, "dmg": 2, "hit": 6, "xp": 3, "gold": 1,
			"desc": "Mangy, fast and hungry.",
			"look": {"color": "8a7563", "size": 0.7, "ears": true, "tail": true, "legs": 4, "eyes": "ff4444", "teeth": true}},
		{"name": "Goblin Cutthroat", "hp": 9, "armor": 0, "dmg": 3, "hit": 7, "xp": 4, "gold": 4,
			"desc": "A wiry goblin with a notched knife.",
			"look": {"color": "5f8a3c", "size": 0.8, "ears": true, "legs": 2, "eyes": "ffdd33", "teeth": true}},
		{"name": "Skeleton Guard", "hp": 10, "armor": 1, "dmg": 3, "hit": 8, "xp": 5, "gold": 2,
			"desc": "Old bones still keeping watch.",
			"look": {"color": "d9d2bf", "size": 0.9, "bones": true, "legs": 2, "eyes": "66ccff"}},
		{"name": "Cave Bat", "hp": 5, "armor": 0, "dmg": 2, "hit": 6, "xp": 2, "gold": 0,
			"desc": "It shrieks and dives at your face.",
			"look": {"color": "4a3b52", "size": 0.6, "wings": true, "ears": true, "legs": 0, "eyes": "ff5555", "teeth": true}},
	],
	[
		{"name": "Orc Brute", "hp": 15, "armor": 1, "dmg": 4, "hit": 7, "xp": 8, "gold": 8,
			"desc": "Muscle, tusks and a bad temper.",
			"look": {"color": "6b7d3a", "size": 1.05, "legs": 2, "eyes": "ff3300", "teeth": true, "ears": true}},
		{"name": "Ghoul", "hp": 13, "armor": 0, "dmg": 4, "hit": 7, "xp": 7, "gold": 3,
			"desc": "It smells of the grave.",
			"look": {"color": "7d8c84", "size": 0.9, "legs": 2, "eyes": "ccff66", "teeth": true}},
		{"name": "Giant Spider", "hp": 12, "armor": 1, "dmg": 3, "hit": 6, "xp": 7, "gold": 2,
			"desc": "Eight legs, eight eyes, one appetite.",
			"look": {"color": "2f2a2a", "size": 0.85, "legs": 8, "eyes": "ff2222", "teeth": true}},
		{"name": "Cultist", "hp": 12, "armor": 0, "dmg": 5, "hit": 8, "xp": 8, "gold": 10,
			"desc": "Chanting softly, dagger raised.",
			"look": {"color": "6a1f2b", "size": 0.9, "hood": true, "legs": 2, "eyes": "ffaa00"}},
	],
	[
		{"name": "Cave Troll", "hp": 24, "armor": 2, "dmg": 5, "hit": 7, "xp": 14, "gold": 10,
			"desc": "A hulking brute with stone-grey hide.",
			"look": {"color": "5d6e6a", "size": 1.25, "legs": 2, "eyes": "ffcc00", "teeth": true, "ears": true}},
		{"name": "Wraith", "hp": 17, "armor": 2, "dmg": 6, "hit": 8, "xp": 13, "gold": 6,
			"desc": "A cold shape that drinks the light.",
			"look": {"color": "8fa3b8", "size": 1.0, "hood": true, "legs": 0, "eyes": "aaffff"}},
		{"name": "Minotaur", "hp": 26, "armor": 2, "dmg": 6, "hit": 8, "xp": 16, "gold": 12,
			"desc": "It lowers its horns and snorts.",
			"look": {"color": "6e4630", "size": 1.2, "horns": true, "legs": 2, "eyes": "ff2200"}},
		{"name": "Death Knight", "hp": 21, "armor": 3, "dmg": 5, "hit": 7, "xp": 15, "gold": 15,
			"desc": "Black plate, and nothing inside but hate.",
			"look": {"color": "3d4250", "size": 1.1, "helm": true, "legs": 2, "eyes": "ff3333"}},
	],
]

const ROOM_NAMES := [
	"Damp Cell", "Collapsed Shrine", "Guard Post", "Fungal Grotto", "Old Armoury",
	"Bone Pit", "Flooded Hall", "Torture Chamber", "Crypt", "Ruined Library",
	"Kitchen", "Barracks", "Well Room", "Chapel", "Storeroom", "Echoing Vault",
	"Statue Hall", "Mushroom Garden", "Throne Room", "Cistern",
]

const CORRIDOR_NAMES := [
	"Narrow Passage", "Dripping Tunnel", "Crawlway", "Winding Corridor",
	"Rubble-strewn Hall", "Dark Stair", "Mossy Passage",
]

const TRAPS := ["spike pit", "swinging blade", "volley of darts", "falling stones", "gout of flame"]


static func pick(arr: Array):
	return Dice.pick(arr)


static func make_enemy(depth: int) -> Dictionary:
	var tier := clampi(depth, 1, CREATURES.size())
	var e: Dictionary = pick(CREATURES[tier - 1]).duplicate(true)
	var extra := depth - tier
	if extra > 0:
		e.name = "Dread " + e.name
		e.hp += extra * 5
		e.dmg += extra
		e.armor += int(extra / 2.0)
		e.xp += extra * 4
		e.gold += extra * 3
	e.max_hp = e.hp
	return e


static func moves_text(moves: Array) -> String:
	var lines := []
	for m in moves:
		var line: String = "%s (%d-%d) +%d" % [m.name, m.pair[0], m.pair[1], m.bonus]
		if m.effect != "":
			line += ", " + EFFECT_TEXT[m.effect]
		lines.append(line)
	return "\n".join(lines)
