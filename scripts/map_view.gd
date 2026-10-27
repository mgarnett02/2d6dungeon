extends Control
## Draws the current dungeon level as an inked map on graph paper and lets the
## player click glowing doors to explore or visited rooms to walk back to them.

signal door_clicked(door_idx: int)
signal room_clicked(room_id: int)

const PAPER := Color("e9dcc0")
const GRID := Color(0.42, 0.55, 0.62, 0.18)
const GRID_MAJOR := Color(0.42, 0.55, 0.62, 0.35)
const INK := Color("2a1d14")
const INK_SOFT := Color(0.16, 0.11, 0.08, 0.45)
const SHADOW := Color(0, 0, 0, 0.18)
const ROOM_FILL := Color("f7efdc")
const CORRIDOR_FILL := Color("e3d3b0")
const ENTRANCE_FILL := Color("d9e6d0")
const HERE := Color(1.0, 0.75, 0.3, 0.25)
const WOOD := Color("8b5a2b")
const GOLD := Color("e0a530")
const GOLD_DIM := Color("b8945a")
const BLOOD := Color("a8322a")

var dungeon = null
var current_room := 0
var interactive := true
## Player token position in cell units (tweened by the game).
var token_pos := Vector2.ZERO

var _cs := 24.0
var _origin := Vector2.ZERO
var _snap := true
var _hover_door := -1
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_dungeon(d) -> void:
	dungeon = d
	_snap = true
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if dungeon != null:
		_update_layout(delta)
	queue_redraw()


## Fits the explored area into the view, easing towards the new zoom as the map grows.
func _update_layout(delta: float) -> void:
	var b: Rect2i = dungeon.rooms[0].rect
	for r in dungeon.rooms:
		b = b.merge(r.rect)
	b = b.grow(3)
	var cs := clampf(minf(size.x / b.size.x, size.y / b.size.y), 10.0, 40.0)
	var origin := size / 2.0 - (Vector2(b.position) + Vector2(b.size) / 2.0) * cs
	if _snap:
		_cs = cs
		_origin = origin
		_snap = false
	else:
		var t := clampf(delta * 5.0, 0.0, 1.0)
		_cs = lerpf(_cs, cs, t)
		_origin = _origin.lerp(origin, t)


func _to_px(cell: Vector2) -> Vector2:
	return _origin + cell * _cs


func _gui_input(event: InputEvent) -> void:
	if dungeon == null:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_hover_door = _door_at(motion.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover_door >= 0 else Control.CURSOR_ARROW
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var d := _door_at(click.position)
		if d >= 0:
			door_clicked.emit(d)
			return
		var cell := ((click.position - _origin) / _cs).floor()
		var rid: int = dungeon.room_at(Vector2i(cell))
		if rid >= 0:
			room_clicked.emit(rid)


## Index of an unexplored door of the current room under the mouse, or -1.
func _door_at(pos: Vector2) -> int:
	if not interactive:
		return -1
	for idx in dungeon.rooms[current_room].doors:
		var d: Dictionary = dungeon.doors[idx]
		if d.b >= 0 or d.blocked:
			continue
		if _to_px(dungeon.door_point(idx)).distance_to(pos) < maxf(_cs * 0.6, 12.0):
			return idx
	return -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if dungeon == null:
		return
	_draw_grid()
	for r in dungeon.rooms:
		_draw_room(r)
	for i in dungeon.doors.size():
		_draw_door(i)
	_draw_token()
	_draw_captions()


func _draw_grid() -> void:
	var x0 := floori(-_origin.x / _cs)
	var x1 := ceili((size.x - _origin.x) / _cs)
	for x in range(x0, x1 + 1):
		var px := _origin.x + x * _cs
		draw_line(Vector2(px, 0), Vector2(px, size.y), GRID_MAJOR if x % 5 == 0 else GRID, 1.0)
	var y0 := floori(-_origin.y / _cs)
	var y1 := ceili((size.y - _origin.y) / _cs)
	for y in range(y0, y1 + 1):
		var py := _origin.y + y * _cs
		draw_line(Vector2(0, py), Vector2(size.x, py), GRID_MAJOR if y % 5 == 0 else GRID, 1.0)


func _draw_room(r) -> void:
	var rect: Rect2i = r.rect
	var pr := Rect2(_to_px(Vector2(rect.position)), Vector2(rect.size) * _cs)
	draw_rect(Rect2(pr.position + Vector2(3, 4), pr.size), SHADOW)
	var fill := ROOM_FILL
	if r.kind == "corridor":
		fill = CORRIDOR_FILL
	elif r.kind == "entrance":
		fill = ENTRANCE_FILL
	draw_rect(pr, fill)
	if r.id == current_room:
		draw_rect(pr, HERE)
	# Faint squares inside the room, like counting squares on graph paper.
	for x in range(1, rect.size.x):
		var px := pr.position.x + x * _cs
		draw_line(Vector2(px, pr.position.y), Vector2(px, pr.end.y), INK_SOFT * Color(1, 1, 1, 0.4), 1.0)
	for y in range(1, rect.size.y):
		var py := pr.position.y + y * _cs
		draw_line(Vector2(pr.position.x, py), Vector2(pr.end.x, py), INK_SOFT * Color(1, 1, 1, 0.4), 1.0)
	draw_rect(pr, INK, false, 3.0)

	if _cs >= 16.0 and r.kind == "room":
		draw_string(get_theme_default_font(), pr.position + Vector2(4, 13), "%dx%d" % [rect.size.x, rect.size.y],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK_SOFT)

	var s := minf(minf(pr.size.x, pr.size.y) * 0.75, _cs * 1.6)
	var c := pr.get_center()
	if r.kind == "entrance":
		_draw_icon("entrance", c, s)
	if r.stairs:
		_draw_icon("stairs", c if r.resolved else c + Vector2(s * 0.5, s * 0.3), s * (1.0 if r.resolved else 0.6))
	if not r.resolved:
		_draw_icon(r.content, c, s)


func _draw_door(i: int) -> void:
	var d: Dictionary = dungeon.doors[i]
	var center := _to_px(dungeon.door_point(i))
	var on_horizontal_wall: bool = d.dir.y != 0
	var length := _cs * 0.7
	var thick := maxf(_cs * 0.32, 5.0)
	var sz := Vector2(length, thick) if on_horizontal_wall else Vector2(thick, length)
	var rect := Rect2(center - sz / 2.0, sz)
	if d.blocked:
		draw_rect(rect, PAPER)
		var k := thick * 0.8
		draw_line(center - Vector2(k, k), center + Vector2(k, k), BLOOD, 2.5)
		draw_line(center + Vector2(-k, k), center + Vector2(k, -k), BLOOD, 2.5)
	elif d.b >= 0:
		draw_rect(rect, ROOM_FILL)
		draw_rect(rect.grow(-1.0), WOOD)
		draw_rect(rect, INK, false, 1.5)
	else:
		var mine: bool = d.a == current_room and interactive
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		if mine:
			draw_circle(center, _cs * 0.55 + pulse * 3.0, Color(1.0, 0.8, 0.3, 0.25))
		draw_rect(rect, GOLD.lerp(Color.WHITE, pulse * 0.4) if mine else GOLD_DIM)
		draw_rect(rect, INK, false, 1.5)
		if i == _hover_door:
			draw_rect(rect.grow(3.0), BLOOD, false, 2.0)


func _draw_token() -> void:
	var p := _to_px(token_pos)
	var r := clampf(_cs * 0.38, 6.0, 14.0)
	draw_circle(p + Vector2(2, 3), r, SHADOW)
	draw_circle(p, r, Color("b03a2e"))
	draw_arc(p, r, 0.0, TAU, 24, INK, 2.0, true)
	draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.5))


func _draw_captions() -> void:
	var font := get_theme_default_font()
	draw_string(font, Vector2(14, 30), "Dungeon Level %d" % dungeon.depth, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	draw_string(font, Vector2(14, 50), "%d rooms mapped" % dungeon.rooms.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK_SOFT)
	if interactive:
		draw_string(font, Vector2(14, size.y - 14), "Click a glowing door to explore. Click a visited room to walk there.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK_SOFT)


func _draw_icon(what: String, c: Vector2, s: float) -> void:
	var bone := Color("f2ead8")
	match what:
		"creature", "hoard":
			draw_circle(c + Vector2(0, -s * 0.1), s * 0.32, bone)
			draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.08), Vector2(s * 0.36, s * 0.2)), bone)
			draw_arc(c + Vector2(0, -s * 0.1), s * 0.32, 0.0, TAU, 24, INK, 1.5, true)
			draw_circle(c + Vector2(-s * 0.12, -s * 0.12), s * 0.08, INK)
			draw_circle(c + Vector2(s * 0.12, -s * 0.12), s * 0.08, INK)
			for k in 3:
				var x := c.x - s * 0.09 + k * s * 0.09
				draw_line(Vector2(x, c.y + s * 0.1), Vector2(x, c.y + s * 0.28), INK, 1.5)
			if what == "hoard":
				_draw_icon("loot", c + Vector2(s * 0.35, s * 0.3), s * 0.5)
		"trap":
			for k in 3:
				var x := c.x - s * 0.3 + k * s * 0.3
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - s * 0.12, c.y + s * 0.25), Vector2(x, c.y - s * 0.3), Vector2(x + s * 0.12, c.y + s * 0.25)]), Color("6d6d6d"))
		"loot":
			var box := Rect2(c - Vector2(s * 0.3, s * 0.15), Vector2(s * 0.6, s * 0.38))
			draw_rect(box, WOOD)
			draw_rect(Rect2(box.position - Vector2(0, s * 0.12), Vector2(box.size.x, s * 0.14)), WOOD.darkened(0.2))
			draw_rect(Rect2(Vector2(c.x - s * 0.05, box.position.y - s * 0.12), Vector2(s * 0.1, box.size.y + s * 0.12)), GOLD)
			draw_rect(box, INK, false, 1.5)
		"shrine":
			var pts := PackedVector2Array()
			for k in 10:
				var ang := -PI / 2.0 + k * PI / 5.0
				var rad := s * (0.36 if k % 2 == 0 else 0.15)
				pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
			draw_colored_polygon(pts, Color("4fa3e0"))
		"stairs":
			var w := s * 0.6
			draw_rect(Rect2(c - Vector2(w, w) / 2.0, Vector2(w, w)), INK.lightened(0.15))
			for k in 4:
				var y := c.y - w / 2.0 + (k + 0.5) * w / 4.0
				var inset := k * w / 10.0
				draw_line(Vector2(c.x - w / 2.0 + inset, y), Vector2(c.x + w / 2.0 - inset, y), PAPER, 2.0)
		"entrance":
			var w := s * 0.5
			draw_rect(Rect2(c + Vector2(-w / 2.0, -w * 0.1), Vector2(w, w * 0.55)), Color("6b8f5e"))
			draw_arc(c + Vector2(0, -w * 0.1), w / 2.0, PI, TAU, 16, Color("6b8f5e"), w * 0.2)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -w * 0.45), c + Vector2(w * 0.22, -w * 0.15), c + Vector2(-w * 0.22, -w * 0.15)]), PAPER)
