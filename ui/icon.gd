extends Control
## Vector icons drawn in code (no emoji fonts needed, so they render the same
## everywhere, including browsers without emoji support).

var kind := "heart":
	set(v):
		kind = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var outline := true
var wobble := 0.0

const INK := Color("2a1f33")


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var u := s / 32.0 # design on a 32x32 grid
	match kind:
		"heart": _heart(c, u, color)
		"heart_empty": _heart(c, u, Color(color, 0.25))
		"coin": _coin(c, u)
		"fish": _fish(c, u, color)
		"paw": _paw(c, u, color)
		"yarn": _yarn(c, u, color)
		"hiss": _hiss(c, u, color)
		"laser": _laser(c, u, color)
		"bolt": _bolt(c, u, color)
		"eye": _eye(c, u, color)
		"star": _star(c, u * 15.0, u * 6.5, color)
		"star_empty": _star(c, u * 15.0, u * 6.5, Color("4a3b57"))
		"cat": _cat(c, u, color)
		"dog": _dog(c, u, color)
		"pause": _pause(c, u)
		"play": _play(c, u, color)
		"ff": _ff(c, u, color)
		"skull": _skull(c, u)
		"gear": _gear(c, u, color)
		"lock": _lock(c, u)


func _ring_poly(center: Vector2, r: float, n := 20) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(center + Vector2(cos(a), sin(a)) * r)
	return p


func _blob(center: Vector2, r: float, col: Color) -> void:
	if outline:
		draw_circle(center, r + 2.0, INK)
	draw_circle(center, r, col)


func _heart(c: Vector2, u: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y + 1.5) * u * 0.85)
	if outline:
		var o := PackedVector2Array()
		for p in pts:
			o.append(c + (p - c) * 1.16)
		draw_colored_polygon(o, INK)
	draw_colored_polygon(pts, col)
	draw_circle(c + Vector2(-6, -5) * u, 2.2 * u, Color(1, 1, 1, 0.55 * col.a))


func _coin(c: Vector2, u: float) -> void:
	_blob(c, 13 * u, GameData.C_GOLD)
	draw_circle(c, 9 * u, Color("f0b400"))
	draw_rect(Rect2(c + Vector2(-2, -6) * u, Vector2(4, 12) * u), GameData.C_GOLD)
	draw_circle(c + Vector2(-5, -5) * u, 2.5 * u, Color(1, 1, 0.85))


func _fish(c: Vector2, u: float, col: Color) -> void:
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		body.append(c + Vector2(cos(a) * 10 - 2, sin(a) * 6.5) * u)
	var tail := PackedVector2Array([c + Vector2(6, 0) * u, c + Vector2(14, -7) * u, c + Vector2(14, 7) * u])
	if outline:
		var bo := PackedVector2Array()
		for p in body:
			bo.append(c + (p - c) * 1.15)
		draw_colored_polygon(bo, INK)
		draw_colored_polygon(PackedVector2Array([c + Vector2(4, 0) * u, c + Vector2(16, -9) * u, c + Vector2(16, 9) * u]), INK)
	draw_colored_polygon(tail, col.darkened(0.15))
	draw_colored_polygon(body, col)
	draw_circle(c + Vector2(-7, -1.5) * u, 1.8 * u, INK)


func _paw(c: Vector2, u: float, col: Color) -> void:
	_blob(c + Vector2(0, 4) * u, 7.5 * u, col)
	for p in [Vector2(-9, -3), Vector2(-3.5, -9), Vector2(3.5, -9), Vector2(9, -3)]:
		_blob(c + p * u, 3.6 * u, col)


func _yarn(c: Vector2, u: float, col: Color) -> void:
	_blob(c, 12 * u, col)
	for i in 3:
		var a := -0.6 + i * 0.6
		draw_arc(c + Vector2(cos(a), sin(a)) * 4 * u, 9 * u, a + 1.0, a + 3.6, 12, col.darkened(0.3), 1.6 * u, true)
	draw_line(c + Vector2(8, 8) * u, c + Vector2(14, 13) * u, col.darkened(0.3), 2 * u, true)


func _hiss(c: Vector2, u: float, col: Color) -> void:
	for i in 3:
		var r := (5.0 + i * 5.0) * u
		if outline:
			draw_arc(c + Vector2(-8, 0) * u, r, -0.9, 0.9, 12, INK, 5.0 * u, true)
		draw_arc(c + Vector2(-8, 0) * u, r, -0.9, 0.9, 12, col, 2.6 * u, true)
	_blob(c + Vector2(-9, 0) * u, 3.5 * u, col)


func _laser(c: Vector2, u: float, col: Color) -> void:
	var a := c + Vector2(-12, 10) * u
	var b := c + Vector2(9, -9) * u
	if outline:
		draw_line(a, b, INK, 6 * u, true)
	draw_line(a, b, col, 3 * u, true)
	_blob(b, 5 * u, col)
	draw_circle(b, 2.2 * u, Color(1, 1, 1, 0.9))


func _bolt(c: Vector2, u: float, col: Color) -> void:
	var p := PackedVector2Array([Vector2(3, -15), Vector2(-9, 2), Vector2(-1, 2), Vector2(-4, 15), Vector2(9, -3), Vector2(1, -3), Vector2(5, -15)])
	for i in p.size():
		p[i] = c + p[i] * u
	if outline:
		var o := PackedVector2Array()
		for q in p:
			o.append(c + (q - c) * 1.18)
		draw_colored_polygon(o, INK)
	draw_colored_polygon(p, col)


func _eye(c: Vector2, u: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		p.append(c + Vector2(cos(a) * 14, sin(a) * 8 * absf(sin(a)) + sin(a) * 1.5) * u)
	if outline:
		var o := PackedVector2Array()
		for q in p:
			o.append(c + (q - c) * 1.15)
		draw_colored_polygon(o, INK)
	draw_colored_polygon(p, Color.WHITE)
	draw_circle(c, 6 * u, col)
	draw_rect(Rect2(c + Vector2(-1.3, -6) * u, Vector2(2.6, 12) * u), INK)


func _star(c: Vector2, r_out: float, r_in: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + PI * i / 5.0
		var r := r_out if i % 2 == 0 else r_in
		p.append(c + Vector2(cos(a), sin(a)) * r)
	if outline:
		var o := PackedVector2Array()
		for q in p:
			o.append(c + (q - c) * 1.18)
		draw_colored_polygon(o, INK)
	draw_colored_polygon(p, col)


func _cat(c: Vector2, u: float, col: Color) -> void:
	var ears := [
		PackedVector2Array([c + Vector2(-13, -2) * u, c + Vector2(-11, -15) * u, c + Vector2(-2, -9) * u]),
		PackedVector2Array([c + Vector2(13, -2) * u, c + Vector2(11, -15) * u, c + Vector2(2, -9) * u]),
	]
	if outline:
		for e in ears:
			var o := PackedVector2Array()
			var mid: Vector2 = (e[0] + e[1] + e[2]) / 3.0
			for q in e:
				o.append(mid + (q - mid) * 1.35)
			draw_colored_polygon(o, INK)
	for e in ears:
		draw_colored_polygon(e, col)
	_blob(c + Vector2(0, 2) * u, 12 * u, col)
	draw_circle(c + Vector2(-5, 0) * u, 2.2 * u, INK)
	draw_circle(c + Vector2(5, 0) * u, 2.2 * u, INK)
	draw_circle(c + Vector2(0, 5) * u, 1.6 * u, GameData.C_PINK)


func _dog(c: Vector2, u: float, col: Color) -> void:
	var ear_col := col.darkened(0.35)
	for sx in [-1, 1]:
		var e := PackedVector2Array([c + Vector2(9 * sx, -9) * u, c + Vector2(15 * sx, -4) * u, c + Vector2(13 * sx, 8) * u, c + Vector2(8 * sx, 2) * u])
		if outline:
			var o := PackedVector2Array()
			var mid := c + Vector2(11 * sx, 0) * u
			for q in e:
				o.append(mid + (q - mid) * 1.3)
			draw_colored_polygon(o, INK)
		draw_colored_polygon(e, ear_col)
	_blob(c, 11 * u, col)
	draw_circle(c + Vector2(0, 5) * u, 5.5 * u, col.lightened(0.35))
	draw_circle(c + Vector2(0, 3.5) * u, 2.3 * u, INK)
	draw_circle(c + Vector2(-4.5, -2.5) * u, 1.8 * u, INK)
	draw_circle(c + Vector2(4.5, -2.5) * u, 1.8 * u, INK)
	draw_line(c + Vector2(-7, -6.5) * u, c + Vector2(-2.5, -4.5) * u, INK, 1.6 * u, true)
	draw_line(c + Vector2(7, -6.5) * u, c + Vector2(2.5, -4.5) * u, INK, 1.6 * u, true)


func _pause(c: Vector2, u: float) -> void:
	for sx in [-1, 1]:
		var r := Rect2(c + Vector2(-2.5 + sx * 5.0, -9) * u, Vector2(5, 18) * u)
		draw_rect(r, color)


func _play(c: Vector2, u: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -10) * u, c + Vector2(10, 0) * u, c + Vector2(-7, 10) * u]), col)


func _ff(c: Vector2, u: float, col: Color) -> void:
	for ox in [-6, 4]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6 + ox, -9) * u, c + Vector2(4 + ox, 0) * u, c + Vector2(-6 + ox, 9) * u]), col)


func _skull(c: Vector2, u: float) -> void:
	_blob(c + Vector2(0, -2) * u, 11 * u, GameData.C_CREAM)
	draw_rect(Rect2(c + Vector2(-6, 5) * u, Vector2(12, 7) * u), GameData.C_CREAM)
	draw_circle(c + Vector2(-4.5, -2) * u, 3.2 * u, INK)
	draw_circle(c + Vector2(4.5, -2) * u, 3.2 * u, INK)


func _gear(c: Vector2, u: float, col: Color) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * 14 * u, col, 5 * u)
	draw_circle(c, 10 * u, col)
	draw_circle(c, 4 * u, INK)


func _lock(c: Vector2, u: float) -> void:
	draw_arc(c + Vector2(0, -4) * u, 7 * u, PI, TAU, 12, GameData.C_CREAM, 3.5 * u, true)
	draw_rect(Rect2(c + Vector2(-10, -3) * u, Vector2(20, 16) * u), GameData.C_CREAM)
	draw_circle(c + Vector2(0, 4) * u, 2.5 * u, INK)
