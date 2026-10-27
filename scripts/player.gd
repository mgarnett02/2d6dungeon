extends RefCounted
## The adventurer: health, shift points, gear and progression.

const Dice = preload("res://scripts/dice.gd")
const GameData = preload("res://scripts/game_data.gd")

const MAX_ARMOR := 4
const MAX_SHIFT := 6

var hp := 20
var max_hp := 20
var armor := 0
var shift := 3
var max_shift := 3
var gold := 10
var potions := 1
var xp := 0
var level := 1
var weapon_name := "Rusty Sword"
var learned: Array = []
var deepest := 1
var kills := 0


func moves() -> Array:
	var out: Array = []
	out.append_array(GameData.WEAPONS[weapon_name].moves)
	out.append_array(learned)
	return out


func xp_to_next() -> int:
	return level * 10


func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + amount)
	return hp - before


func drink_potion() -> int:
	if potions <= 0:
		return 0
	potions -= 1
	return heal(Dice.d6() + Dice.d6() + 2)


func knows(move_name: String) -> bool:
	for m in learned:
		if m.name == move_name:
			return true
	return false


## Learns a random manoeuvre from the pool. Returns it, or {} if none are left.
func learn_random() -> Dictionary:
	var options: Array = []
	for m in GameData.LEARNABLE:
		if not knows(m.name):
			options.append(m)
	if options.is_empty():
		return {}
	var m: Dictionary = Dice.pick(options).duplicate(true)
	learned.append(m)
	return m


## Adds experience and returns log lines for any level-ups.
func gain_xp(amount: int) -> Array:
	var msgs: Array = []
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		max_hp += 4
		hp = mini(max_hp, hp + 4)
		max_shift = mini(MAX_SHIFT, max_shift + 1)
		shift = max_shift
		msgs.append("[color=#e0b04f]Level up! You are now level %d (max HP %d, shift %d).[/color]" % [level, max_hp, max_shift])
		var m := learn_random()
		if not m.is_empty():
			msgs.append("You learn the [b]%s[/b] manoeuvre (%d-%d)." % [m.name, m.pair[0], m.pair[1]])
	return msgs
