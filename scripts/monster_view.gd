extends Control
## Procedurally draws a creature portrait from a "look" dictionary
## (see GameData.CREATURES), with idle bobbing and a hit flash.

var look: Dictionary = {}
var _t := 0.0
var _flash := 0.0
var _shake := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_monster(p_look: Dictionary) -> void:
	look = p_look
	_flash = 0.0
	_shake = 0.0
	modulate = Color.WHITE
	queue_redraw()


func hit() -> void:
	_flash = 1.0
	_shake = 1.0


func defeat() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.8)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	queue_redraw()


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), color)


func _draw() -> void:
	var center := size / 2.0
	var m := minf(size.x, size.y)
	for i in 6:
		draw_circle(center, m * (0.5 - i * 0.07), Color(0.35, 0.12, 0.08, 0.12))
	if look.is_empty():
		return

	var s := m * 0.24 * float(look.get("size", 1.0))
	var c := center + Vector2(sin(_t * 47.0) * 8.0 * _shake, sin(_t * 2.2) * 3.0 + s * 0.35)
	var body := Color(str(look.get("color", "888888")))
	if _flash > 0.0:
		body = body.lerp(Color.WHITE, _flash)
	var dark := body.darkened(0.35)
	var eye := Color(str(look.get("eyes", "ffffff")))
	var hc := c + Vector2(0, -s * 0.95)
	var hr := s * 0.55

	_ellipse(c + Vector2(0, s * 1.15), Vector2(s * 1.1, s * 0.22), Color(0, 0, 0, 0.45))

	# Wings
	if look.get("wings", false):
		var flap := sin(_t * 9.0) * 0.4
		for side: float in [-1.0, 1.0]:
			_tri(c + Vector2(side * s * 0.3, -s * 0.4), c + Vector2(side * s * 2.0, -s * (1.0 + flap)),
				c + Vector2(side * s * 1.3, s * 0.4), dark)
			_tri(c + Vector2(side * s * 0.3, -s * 0.2), c + Vector2(side * s * 1.3, s * 0.4),
				c + Vector2(side * s * 0.7, s * 0.5), dark.darkened(0.2))

	# Legs
	var legs := int(look.get("legs", 2))
	if legs == 8:
		for k in 4:
			for side: float in [-1.0, 1.0]:
				var start := c + Vector2(side * s * 0.5, -s * 0.2 + k * s * 0.15)
				var knee := start + Vector2(side * s * (0.8 + k * 0.1), -s * 0.6 + k * s * 0.15 + sin(_t * 6.0 + k) * s * 0.05)
				var foot := knee + Vector2(side * s * 0.4, s * 1.1)
				draw_polyline(PackedVector2Array([start, knee, foot]), dark, maxf(2.0, s * 0.08), true)
	elif legs == 4:
		for x: float in [-0.6, -0.25, 0.25, 0.6]:
			draw_line(c + Vector2(x * s, s * 0.5), c + Vector2(x * s * 1.1, s * 1.1), dark, maxf(2.0, s * 0.1))
	elif legs == 2:
		for side: float in [-1.0, 1.0]:
			draw_rect(Rect2(c + Vector2(side * s * 0.45 - s * 0.15, s * 0.5), Vector2(s * 0.3, s * 0.6)), dark)

	# Tail
	if look.get("tail", false):
		var pts := PackedVector2Array()
		for k in 12:
			var f := k / 11.0
			pts.append(c + Vector2(s * (0.8 + f * 1.1), s * (0.4 - sin(f * PI + _t * 3.0) * 0.35)))
		draw_polyline(pts, dark, maxf(2.0, s * 0.06), true)

	# Body
	_ellipse(c, Vector2(s * 1.04, s * 0.9), dark)
	_ellipse(c, Vector2(s, s * 0.86), body)
	if look.get("bones", false):
		draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.7), dark, 3.0)
		for k in 3:
			draw_arc(c + Vector2(0, -s * 0.55 + k * s * 0.3), s * 0.55, PI * 0.15, PI * 0.85, 12, dark, 3.0)

	# Head
	if look.get("hood", false):
		var cloak := body.darkened(0.15)
		_tri(hc + Vector2(0, -hr * 2.0), hc + Vector2(hr * 1.4, hr * 1.1), hc + Vector2(-hr * 1.4, hr * 1.1), cloak)
		draw_circle(hc + Vector2(0, hr * 0.15), hr * 0.75, Color(0.05, 0.03, 0.05))
	else:
		if look.get("ears", false):
			for side: float in [-1.0, 1.0]:
				_tri(hc + Vector2(side * hr * 0.4, -hr * 0.6), hc + Vector2(side * hr * 1.2, -hr * 1.4),
					hc + Vector2(side * hr * 0.95, -hr * 0.1), dark)
		if look.get("horns", false):
			for side: float in [-1.0, 1.0]:
				_tri(hc + Vector2(side * hr * 0.5, -hr * 0.55), hc + Vector2(side * hr * 1.6, -hr * 1.5),
					hc + Vector2(side * hr * 0.9, -hr * 0.2), Color("e8dcc0"))
		draw_circle(hc, hr * 1.06, dark)
		draw_circle(hc, hr, body)
	if look.get("helm", false):
		draw_rect(Rect2(hc - Vector2(hr * 1.05, hr * 1.1), Vector2(hr * 2.1, hr * 1.9)), dark)
		draw_rect(Rect2(hc - Vector2(hr * 1.05, hr * 1.1), Vector2(hr * 2.1, hr * 0.3)), dark.lightened(0.2))
		draw_rect(Rect2(hc + Vector2(-hr * 0.7, -hr * 0.2), Vector2(hr * 1.4, hr * 0.22)), Color(0.03, 0.03, 0.05))

	# Eyes
	var glow := Color(eye.r, eye.g, eye.b, 0.3 + 0.15 * sin(_t * 3.0))
	for side: float in [-1.0, 1.0]:
		var e := hc + Vector2(side * hr * 0.38, -hr * 0.08)
		draw_circle(e, hr * 0.32, glow)
		draw_circle(e, hr * 0.17, eye)
		if not look.get("hood", false) and not look.get("helm", false):
			draw_circle(e + Vector2(0, hr * 0.03), hr * 0.07, Color(0.05, 0.02, 0.02))

	# Teeth
	if look.get("teeth", false):
		var mouth := Rect2(hc + Vector2(-hr * 0.5, hr * 0.32), Vector2(hr, hr * 0.3))
		draw_rect(mouth, Color(0.15, 0.03, 0.03))
		for k in 4:
			var x := mouth.position.x + (k + 0.5) * mouth.size.x / 4.0
			_tri(Vector2(x - hr * 0.1, mouth.position.y), Vector2(x + hr * 0.1, mouth.position.y),
				Vector2(x, mouth.position.y + hr * 0.18), Color("f2ead8"))
