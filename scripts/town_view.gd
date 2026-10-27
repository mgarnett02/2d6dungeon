extends Control
## Draws the town at dusk: sky, hills, houses with flickering windows and the dungeon gate.

const HOUSES := [
	# x (fraction of width), width, height, roof height
	[0.04, 0.09, 0.20, 0.10], [0.14, 0.07, 0.15, 0.08], [0.22, 0.11, 0.24, 0.12],
	[0.35, 0.08, 0.17, 0.09], [0.45, 0.12, 0.27, 0.11], [0.59, 0.07, 0.14, 0.07],
]

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var bands := 24
	for i in bands:
		var f := float(i) / (bands - 1)
		draw_rect(Rect2(0, h * i / bands, w, h / bands + 1.0), Color("1d2340").lerp(Color("c56a3a"), f * f))
	draw_circle(Vector2(w * 0.82, h * 0.22), h * 0.07, Color("f4e7c4"))
	draw_circle(Vector2(w * 0.82, h * 0.22), h * 0.11, Color(1, 0.95, 0.8, 0.12))
	for i in 30:
		var star := Vector2(fmod(i * 137.5, w), fmod(i * 59.3, h * 0.4))
		draw_circle(star, 1.2, Color(1, 1, 1, 0.3 + 0.3 * sin(_t * 2.0 + i)))

	# Hills
	var far := PackedVector2Array([Vector2(0, h * 0.62)])
	for k in 9:
		far.append(Vector2(w * k / 8.0, h * (0.5 + 0.08 * sin(k * 1.7))))
	far.append(Vector2(w, h * 0.62))
	far.append(Vector2(w, h))
	far.append(Vector2(0, h))
	draw_colored_polygon(far, Color("2b2638"))
	draw_rect(Rect2(0, h * 0.78, w, h * 0.22), Color("1e1a1a"))

	# Houses
	var ground := h * 0.8
	for i in HOUSES.size():
		var hs: Array = HOUSES[i]
		var x: float = hs[0] * w
		var hw: float = hs[1] * w
		var hh: float = hs[2] * h
		var rh: float = hs[3] * h
		draw_rect(Rect2(x, ground - hh, hw, hh), Color("2a2020"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - hw * 0.08, ground - hh), Vector2(x + hw / 2.0, ground - hh - rh), Vector2(x + hw * 1.08, ground - hh)]),
			Color("3a2424"))
		var flicker := 0.75 + 0.25 * sin(_t * 5.0 + i * 1.3)
		var win := Color(1.0, 0.75, 0.35, flicker)
		draw_rect(Rect2(x + hw * 0.2, ground - hh * 0.7, hw * 0.2, hh * 0.18), win)
		draw_rect(Rect2(x + hw * 0.6, ground - hh * 0.7, hw * 0.2, hh * 0.18), win)
		draw_rect(Rect2(x + hw * 0.4, ground - hh * 0.35, hw * 0.22, hh * 0.35), Color("120d0d"))

	# Dungeon gate
	var gx := w * 0.78
	var gw := w * 0.14
	var gh := h * 0.34
	draw_rect(Rect2(gx, ground - gh, gw, gh), Color("4a4448"))
	for row in 6:
		var y := ground - gh + row * gh / 6.0
		draw_line(Vector2(gx, y), Vector2(gx + gw, y), Color("3a3438"), 2.0)
	var mouth := PackedVector2Array()
	var cx := gx + gw / 2.0
	var r := gw * 0.3
	mouth.append(Vector2(cx - r, ground))
	for k in 13:
		var ang := PI + PI * k / 12.0
		mouth.append(Vector2(cx + cos(ang) * r, ground - gh * 0.45 + sin(ang) * r))
	mouth.append(Vector2(cx + r, ground))
	draw_colored_polygon(mouth, Color("080606"))
	for side: float in [-1.0, 1.0]:
		var tx := cx + side * gw * 0.42
		var fl := 0.8 + 0.2 * sin(_t * 11.0 + side)
		draw_line(Vector2(tx, ground - gh * 0.5), Vector2(tx, ground - gh * 0.3), Color("5a3a20"), 4.0)
		draw_circle(Vector2(tx, ground - gh * 0.53), 9.0 * fl, Color(1.0, 0.55, 0.15, 0.85))
		draw_circle(Vector2(tx, ground - gh * 0.53), 18.0 * fl, Color(1.0, 0.6, 0.2, 0.18))
