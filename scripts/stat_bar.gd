extends Control
## A captioned horizontal bar, or a row of pips when `pips` is true.

var fill := Color("b03a2e")
var pips := false
var _value := 0.0
var _max := 1.0
var _caption := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(value: float, max_value: float, caption := "") -> void:
	_value = value
	_max = maxf(1.0, max_value)
	_caption = caption
	queue_redraw()


func _draw() -> void:
	if pips:
		var count := int(_max)
		var r := size.y * 0.32
		for i in count:
			var c := Vector2(r + 3 + i * (r * 2 + 6), size.y / 2.0)
			draw_circle(c, r, Color(0, 0, 0, 0.45))
			if i < int(_value):
				draw_circle(c, r - 2.5, fill)
				draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.25, Color(1, 1, 1, 0.35))
			draw_arc(c, r, 0.0, TAU, 24, Color("c9a86a"), 1.5, true)
		return
	var bar := Rect2(Vector2(0, size.y * 0.15), Vector2(size.x, size.y * 0.7))
	draw_rect(bar, Color(0, 0, 0, 0.5))
	var ratio := clampf(_value / _max, 0.0, 1.0)
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y * 0.35)), Color(1, 1, 1, 0.12))
	draw_rect(bar, Color("c9a86a"), false, 1.5)
	if _caption != "":
		var font := get_theme_default_font()
		var fs := int(bar.size.y * 0.8)
		draw_string(font, Vector2(0, bar.position.y + bar.size.y / 2.0 + fs * 0.35), _caption,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
