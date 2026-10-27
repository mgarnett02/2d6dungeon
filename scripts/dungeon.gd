extends RefCounted
## One dungeon level: rooms on a square grid, joined by doors.
## Rooms are created as doors are opened, sized by a 2d6 roll
## (first die = width, second die = height, a 1 makes a corridor).

const Dice = preload("res://scripts/dice.gd")
const GameData = preload("res://scripts/game_data.gd")
const Room = preload("res://scripts/room.gd")

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## A room rolled after this many rooms on a level may hold the stairs down on doubles.
const STAIRS_MIN_ROOMS := 5
## Past this many rooms, the next full room is guaranteed to hold the stairs.
const STAIRS_FORCE_ROOMS := 12

var depth := 1
var rooms: Array = []
## Each door: {a: room id, b: room id or -1 if unexplored, inside: cell in room a,
## dir: outward direction from room a, blocked: bool}.
var doors: Array = []
var stairs_room := -1
var _door_keys := {}


func _init(p_depth: int = 1) -> void:
	depth = p_depth
	var r = _add_room(Rect2i(-2, -2, 4, 4), "entrance")
	r.name = "Dungeon Entrance" if depth == 1 else "Stair Landing"
	r.resolved = true
	r.dice = [4, 4]
	for dir in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		_add_exit(r, dir)


func room_at(cell: Vector2i) -> int:
	for r in rooms:
		if r.rect.has_point(cell):
			return r.id
	return -1


func open_doors() -> int:
	var n := 0
	for d in doors:
		if d.b < 0 and not d.blocked:
			n += 1
	return n


## The point (in cell units) in the middle of a door's wall segment.
func door_point(idx: int) -> Vector2:
	var d: Dictionary = doors[idx]
	return Vector2(d.inside) + Vector2(0.5, 0.5) + Vector2(d.dir) * 0.5


## Direction of a door as seen from inside the given room.
func door_dir_from(idx: int, room_id: int) -> Vector2i:
	var d: Dictionary = doors[idx]
	return d.dir if d.a == room_id else -d.dir


func other_side(idx: int, room_id: int) -> int:
	var d: Dictionary = doors[idx]
	return d.b if d.a == room_id else d.a


func door_between(a: int, b: int) -> int:
	for idx in rooms[a].doors:
		var d: Dictionary = doors[idx]
		if (d.a == a and d.b == b) or (d.a == b and d.b == a):
			return idx
	return -1


## Shortest route through explored doors. Rooms with a living creature can be
## the destination but are never walked through.
func find_path(from: int, to: int) -> Array:
	var prev := {from: -1}
	var queue: Array = [from]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to:
			break
		if cur != from and rooms[cur].blocks_passage():
			continue
		for idx in rooms[cur].doors:
			var d: Dictionary = doors[idx]
			if d.b < 0:
				continue
			var nxt: int = other_side(idx, cur)
			if not prev.has(nxt):
				prev[nxt] = cur
				queue.append(nxt)
	if not prev.has(to):
		return []
	var path: Array = []
	var c: int = to
	while c != -1:
		path.push_front(c)
		c = prev[c]
	return path


## Opens an unexplored door: rolls 2d6 for the size of the room beyond and places it.
## Returns {ok, roll, room}. If nothing fits, the passage has collapsed (ok = false).
func explore(idx: int) -> Dictionary:
	var door: Dictionary = doors[idx]
	var roll: Array = [Dice.d6(), Dice.d6()]
	var dir: Vector2i = door.dir
	var outside: Vector2i = door.inside + dir
	var w: int = roll[0]
	var h: int = roll[1]
	if w == 1 or h == 1:
		# Corridors run away from the door you came through.
		var length := maxi(w, h)
		if dir.x != 0:
			w = length
			h = 1
		else:
			w = 1
			h = length
	var rect := _fit_room(outside, dir, w, h)
	if rect.size == Vector2i.ZERO:
		door.blocked = true
		if stairs_room < 0 and open_doors() == 0:
			_place_stairs(rooms[door.a])
		return {"ok": false, "roll": roll, "room": -1}

	var kind := "corridor" if (rect.size.x == 1 or rect.size.y == 1) else "room"
	var room = _add_room(rect, kind)
	room.dice = roll
	door.b = room.id
	room.doors.append(idx)
	# Any other unexplored door that opens into the new space now leads here.
	for j in doors.size():
		var other: Dictionary = doors[j]
		if j != idx and other.b < 0 and not other.blocked and rect.has_point(other.inside + other.dir):
			other.b = room.id
			room.doors.append(j)

	_roll_contents(room)

	var exits := 0
	var exit_roll := Dice.d6()
	if kind == "corridor":
		exits = 1 if exit_roll <= 3 else 2
	else:
		exits = 1 + int((exit_roll - 1) / 2.0)
	var tries := 0
	while exits > 0 and tries < 24:
		tries += 1
		if _add_exit(room, DIRS[Dice.rng.randi_range(0, 3)]):
			exits -= 1

	if stairs_room < 0 and kind == "room" and rooms.size() > STAIRS_MIN_ROOMS:
		if roll[0] == roll[1] or rooms.size() > STAIRS_FORCE_ROOMS:
			_place_stairs(room)
	if stairs_room < 0 and open_doors() == 0:
		_place_stairs(room)
	return {"ok": true, "roll": roll, "room": room.id}


func _add_room(rect: Rect2i, kind: String):
	var r = Room.new()
	r.id = rooms.size()
	r.rect = rect
	r.kind = kind
	rooms.append(r)
	return r


func _place_stairs(room) -> void:
	room.stairs = true
	stairs_room = room.id


func _fits(rect: Rect2i) -> bool:
	for r in rooms:
		if r.rect.intersects(rect):
			return false
	return true


## Finds a spot for a w x h room touching the door's outside cell, shrinking it until it fits.
func _fit_room(outside: Vector2i, dir: Vector2i, w: int, h: int) -> Rect2i:
	while true:
		var span := h if dir.x != 0 else w
		var offsets: Array = range(span)
		offsets.shuffle()
		for k in offsets:
			var pos := Vector2i.ZERO
			if dir.x != 0:
				pos.y = outside.y - k
				pos.x = outside.x if dir.x > 0 else outside.x - w + 1
			else:
				pos.x = outside.x - k
				pos.y = outside.y if dir.y > 0 else outside.y - h + 1
			var rect := Rect2i(pos, Vector2i(w, h))
			if _fits(rect):
				return rect
		if w == 1 and h == 1:
			break
		if w >= h:
			w -= 1
		else:
			h -= 1
	return Rect2i()


func _door_key(c1: Vector2i, c2: Vector2i) -> String:
	if c1.x < c2.x or (c1.x == c2.x and c1.y < c2.y):
		return "%s|%s" % [c1, c2]
	return "%s|%s" % [c2, c1]


## Adds a door on the given wall of a room. If another room is already on the
## other side, the door simply connects the two.
func _add_exit(room, dir: Vector2i) -> bool:
	var rect: Rect2i = room.rect
	var cell := Vector2i.ZERO
	if dir.x != 0:
		cell.x = rect.position.x + rect.size.x - 1 if dir.x > 0 else rect.position.x
		cell.y = rect.position.y + Dice.rng.randi_range(0, rect.size.y - 1)
	else:
		cell.y = rect.position.y + rect.size.y - 1 if dir.y > 0 else rect.position.y
		cell.x = rect.position.x + Dice.rng.randi_range(0, rect.size.x - 1)
	var outside := cell + dir
	var key := _door_key(cell, outside)
	if _door_keys.has(key):
		return false
	var other := room_at(outside)
	var idx := doors.size()
	doors.append({"a": room.id, "b": other, "inside": cell, "dir": dir, "blocked": false})
	_door_keys[key] = idx
	room.doors.append(idx)
	if other >= 0:
		rooms[other].doors.append(idx)
	return true


## Rolls 2d6 on the contents table for a freshly opened room.
func _roll_contents(room) -> void:
	var total := Dice.d6() + Dice.d6()
	if room.kind == "corridor":
		room.name = GameData.pick(GameData.CORRIDOR_NAMES)
		if total <= 3:
			room.content = "trap"
		elif total >= 11:
			room.content = "creature"
		else:
			room.content = "empty"
	else:
		room.name = GameData.pick(GameData.ROOM_NAMES)
		match total:
			2:
				room.content = "trap"
			3, 4, 9:
				room.content = "empty"
			5, 10:
				room.content = "loot"
			6, 7, 8:
				room.content = "creature"
			11:
				room.content = "shrine"
			12:
				room.content = "hoard"
	if room.content == "creature" or room.content == "hoard":
		room.enemy = GameData.make_enemy(depth)
	if room.content == "empty":
		room.resolved = true
