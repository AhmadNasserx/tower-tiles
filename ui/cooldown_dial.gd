extends Control
## Radial cooldown overlay for ability buttons.

var fraction := 0.0
var seconds := 0.0
var active := false
var _font: Font = preload("res://assets/fonts/Asap-Black.ttf")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	if active:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_arc(c, r + 2.0, 0, TAU, 40, Color(1, 1, 1, 0.5 + pulse * 0.5), 4.0, true)
	if fraction <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var steps := 32
	for i in steps + 1:
		var a := -PI / 2 + TAU * fraction * float(i) / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(0.16, 0.12, 0.2, 0.7))
	var txt := str(ceili(seconds))
	var fs := 26
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, c + Vector2(-w * 0.5, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("2a1f33"))
	draw_string(_font, c + Vector2(-w * 0.5, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff4e0"))
