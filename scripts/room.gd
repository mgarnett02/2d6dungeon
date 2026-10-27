extends RefCounted
## A single room or corridor on the dungeon map.

var id := 0
var rect := Rect2i()
## "entrance", "room" or "corridor".
var kind := "room"
var name := ""
## "empty", "creature", "trap", "loot", "shrine" or "hoard".
var content := "empty"
var resolved := false
var enemy: Dictionary = {}
var stairs := false
## The 2d6 roll that sized this room.
var dice: Array = [0, 0]
## Indices into Dungeon.doors.
var doors: Array = []


func center() -> Vector2:
	return Vector2(rect.position) + Vector2(rect.size) / 2.0


func blocks_passage() -> bool:
	return not resolved and (content == "creature" or content == "hoard")
