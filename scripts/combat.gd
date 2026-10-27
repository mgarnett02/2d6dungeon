extends RefCounted
## Turn-by-turn combat between the adventurer and one creature.
##
## Each round: roll two attack dice, optionally spend shift points to nudge a die
## by one pip, then attack. If the dice match a manoeuvre's pair it fires;
## doubles are a critical hit (double ones are a fumble); otherwise a basic
## strike deals the higher die minus armour. Then the creature rolls 2d6 and
## hits if the total reaches its target number.

const Dice = preload("res://scripts/dice.gd")

const GUARD_AMOUNT := 3
const BLEED_TURNS := 3
const BLEED_DAMAGE := 2
const FUMBLE_PENALTY := 3
const FLEE_TARGET := 8

var player
var enemy: Dictionary
var dice: Array = [0, 0]
var rolled := false
var round_num := 1
var guard := 0
var stunned := false
var bleed := 0
var exposed := false


func _init(p_player, p_enemy: Dictionary) -> void:
	player = p_player
	enemy = p_enemy


func roll() -> void:
	dice = [Dice.d6(), Dice.d6()]
	rolled = true


func is_double() -> bool:
	return rolled and dice[0] == dice[1]


func is_fumble() -> bool:
	return is_double() and dice[0] == 1


func can_shift(i: int, delta: int) -> bool:
	if not rolled or player.shift <= 0:
		return false
	var v: int = dice[i] + delta
	return v >= 1 and v <= 6


func shift_die(i: int, delta: int) -> bool:
	if not can_shift(i, delta):
		return false
	dice[i] += delta
	player.shift -= 1
	return true


func matches(move: Dictionary) -> bool:
	if not rolled or is_double():
		return false
	var p: Array = move.pair
	return (p[0] == dice[0] and p[1] == dice[1]) or (p[0] == dice[1] and p[1] == dice[0])


## Damage the given manoeuvre would deal right now. An empty move is the basic attack.
func damage_for(move: Dictionary) -> int:
	var total: int = dice[0] + dice[1]
	if move.is_empty():
		if is_fumble():
			return 0
		if is_double():
			return total + player.level
		return maxi(1, maxi(dice[0], dice[1]) - enemy.armor)
	var armor: int = 0 if move.effect == "pierce" else enemy.armor
	return maxi(1, total + move.bonus - armor)


func player_attack(move: Dictionary) -> Dictionary:
	var lines: Array = []
	var dmg := damage_for(move)
	if move.is_empty():
		if is_fumble():
			exposed = true
			lines.append("[color=#c0392b]Fumble![/color] Double ones - you stumble and leave yourself open.")
		elif is_double():
			lines.append("[color=#e0b04f]Critical hit![/color] Doubles! You deal %d damage." % dmg)
		else:
			lines.append("You make a basic strike for %d damage." % dmg)
	else:
		lines.append("You perform [b]%s[/b] for %d damage." % [move.name, dmg])
		match move.effect:
			"guard":
				guard = GUARD_AMOUNT
				lines.append("You raise your guard.")
			"stun":
				stunned = true
				lines.append("The %s is stunned!" % enemy.name)
			"bleed":
				bleed = BLEED_TURNS
				lines.append("The %s is bleeding." % enemy.name)
			"drain":
				var healed: int = player.heal(ceili(dmg / 2.0))
				lines.append("You drain %d health." % healed)
	enemy.hp = maxi(0, enemy.hp - dmg)
	if enemy.hp == 0:
		lines.append("[color=#e0b04f]The %s falls![/color]" % enemy.name)
	return {"lines": lines, "dmg": dmg}


## The creature's half of the round. Returns {lines, dice, dmg, enemy_dead}.
func enemy_turn() -> Dictionary:
	var lines: Array = []
	var result := {"lines": lines, "dice": [], "dmg": 0, "enemy_dead": false}
	if bleed > 0:
		bleed -= 1
		enemy.hp = maxi(0, enemy.hp - BLEED_DAMAGE)
		lines.append("The %s bleeds for %d damage." % [enemy.name, BLEED_DAMAGE])
		if enemy.hp == 0:
			lines.append("[color=#e0b04f]The %s collapses![/color]" % enemy.name)
			result.enemy_dead = true
			return result
	if stunned:
		stunned = false
		lines.append("The %s reels and cannot attack." % enemy.name)
		return result

	var ed: Array = [Dice.d6(), Dice.d6()]
	result.dice = ed
	var total: int = ed[0] + ed[1]
	var dmg := 0
	if ed[0] == 6 and ed[1] == 6:
		dmg = enemy.dmg * 2 + 2
		lines.append("[color=#c0392b]Double sixes! A devastating blow![/color]")
	elif total >= enemy.hit:
		dmg = enemy.dmg + int((total - enemy.hit) / 2.0)
	else:
		lines.append("The %s attacks (rolled %d, needs %d) and misses." % [enemy.name, total, enemy.hit])
		guard = 0
		exposed = false
		return result

	if exposed:
		dmg += FUMBLE_PENALTY
	dmg = maxi(1, dmg - player.armor)
	if guard > 0:
		var blocked := mini(guard, dmg)
		dmg -= blocked
		lines.append("Your guard absorbs %d damage." % blocked)
	player.hp = maxi(0, player.hp - dmg)
	result.dmg = dmg
	lines.append("The %s hits you (rolled %d) for [color=#c0392b]%d damage[/color]." % [enemy.name, total, dmg])
	guard = 0
	exposed = false
	return result


func end_round() -> void:
	rolled = false
	round_num += 1
