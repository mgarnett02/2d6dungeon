extends RefCounted
## Dice helpers shared by the whole game. Every random roll goes through here.

static var rng := RandomNumberGenerator.new()


static func d6() -> int:
	return rng.randi_range(1, 6)


static func roll2() -> Array:
	return [d6(), d6()]


static func pick(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]
