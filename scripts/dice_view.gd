extends Control
## A six-sided die drawn with pips. Call roll_to() to animate a roll.
## A value of 0 draws a blank face.

const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
}

var value := 0:
	set(v):
		value = clampi(v, 0, 6)
		queue_redraw()
var face_color := Color("f4ecd8"):
	set(v):
		face_color = v
		queue_redraw()
var pip_color := Color("2a1d14")
## Border glow; fully transparent means none.
var highlight := Color(0, 0, 0, 0):
	set(v):
		highlight = v
		queue_redraw()

var _rolling := 0.0
var _shown := 1
var _wobble := 0.0
var _box := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func roll_to(v: int, duration := 0.5) -> void:
	value = v
	_rolling = duration
	set_process(true)


func is_rolling() -> bool:
	return _rolling > 0.0


func _process(delta: float) -> void:
	_rolling -= delta
	if _rolling <= 0.0:
		_rolling = 0.0
		_wobble = 0.0
		set_process(false)
	else:
		_shown = randi_range(1, 6)
		_wobble = randf_range(-0.3, 0.3)
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var face := _shown if _rolling > 0.0 else value
	var half := Vector2(s, s) / 2.0
	draw_set_transform(size / 2.0, _wobble, Vector2.ONE)
	var r := Rect2(-half + Vector2(3, 3), Vector2(s, s) - Vector2(6, 6))
	var radius := int(s * 0.18)
	_box.set_corner_radius_all(radius)
	_box.border_width_left = 0
	_box.border_width_right = 0
	_box.border_width_top = 0
	_box.border_width_bottom = 0
	# shadow
	_box.bg_color = Color(0, 0, 0, 0.45)
	draw_style_box(_box, Rect2(r.position + Vector2(2, 4), r.size))
	# body with a highlight border
	_box.bg_color = face_color
	_box.set_border_width_all(maxi(2, int(s * 0.04)))
	_box.border_color = highlight if highlight.a > 0.0 else face_color.darkened(0.35)
	draw_style_box(_box, r)
	if face == 0:
		var font := get_theme_default_font()
		var fs := int(s * 0.45)
		draw_string(font, Vector2(r.position.x, fs * 0.35), "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, pip_color.lightened(0.4))
	else:
		for p in PIPS[face]:
			draw_circle(r.position + p * r.size, s * 0.08, pip_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
