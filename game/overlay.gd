class_name Overlay
extends Control
## Draws every health bar, damage number and flying coin in a single canvas
## item. Far cheaper than hundreds of Label3D/Sprite3D nodes on the web.

signal coin_arrived(amount: int)

const MAX_TEXTS := 70

var game: Game
var camera: Camera3D
var font: Font
var coin_target := Vector2(80, 40)
var show_bars := true

var _texts: Array = [] # {pos, text, color, t, life, size, vx}
var _coins: Array = [] # {from, ctrl, t, dur, amount}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func damage_number(pos: Vector3, amount: float, crit: bool) -> void:
	if amount < 0.5:
		return
	var txt := str(int(round(amount)))
	if crit:
		text_3d(pos, txt + "!", GameData.C_GOLD, 1.45)
	else:
		text_3d(pos, txt, Color(1, 1, 1), 0.8 + clampf(amount / 300.0, 0.0, 0.6))


func text_3d(pos: Vector3, text: String, color: Color, size := 1.0, life := 0.8) -> void:
	if _texts.size() >= MAX_TEXTS:
		_texts.pop_front()
	_texts.append({"pos": pos, "text": text, "color": color, "t": 0.0, "life": life * (1.2 if size > 1.3 else 1.0),
		"size": size, "vx": randf_range(-30.0, 30.0)})


## Launch a coin from a 3D position that flies into the gold counter.
func fly_coins(pos: Vector3, amount: int, count := 1) -> void:
	if camera == null or camera.is_position_behind(pos):
		coin_arrived.emit(amount)
		return
	var from := camera.unproject_position(pos)
	var per := amount / count
	var rem := amount - per * count
	for i in count:
		var ctrl := from + Vector2(randf_range(-90, 90), randf_range(-140, -40))
		_coins.append({"from": from, "ctrl": ctrl, "t": -i * 0.05, "dur": randf_range(0.55, 0.8), "amount": per + (rem if i == 0 else 0)})


func _process(delta: float) -> void:
	for i in range(_texts.size() - 1, -1, -1):
		var tx: Dictionary = _texts[i]
		tx.t += delta
		if tx.t >= tx.life:
			_texts.remove_at(i)
	for i in range(_coins.size() - 1, -1, -1):
		var c: Dictionary = _coins[i]
		c.t += delta / c.dur
		if c.t >= 1.0:
			coin_arrived.emit(c.amount)
			_coins.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if camera == null or game == null:
		return
	if show_bars:
		_draw_bars()
	_draw_texts()
	_draw_coins()


func _draw_bars() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for e: Enemy in game.enemies:
		if not e.alive or e.is_boss:
			continue
		if e.hp >= e.max_hp and now - e.last_hit_time > 1.0:
			continue
		var wp := e.global_position + Vector3(0, 1.15 * e.size + 0.35, 0)
		if camera.is_position_behind(wp):
			continue
		var p := camera.unproject_position(wp)
		var w := 34.0 * clampf(e.size * 1.4, 0.8, 1.6)
		var h := 6.0
		var r := Rect2(p - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
		draw_rect(r.grow(2.0), GameData.C_INK)
		draw_rect(r, Color(0.25, 0.2, 0.3))
		var frac := clampf(e.hp / e.max_hp, 0.0, 1.0)
		var shown := clampf(e.hp_display, frac, 1.0)
		draw_rect(Rect2(r.position, Vector2(w * shown, h)), Color(1, 1, 1, 0.85))
		var col := GameData.C_GREEN.lerp(GameData.C_RED, 1.0 - frac)
		draw_rect(Rect2(r.position, Vector2(w * frac, h)), col)
		if e.slow_time > 0.0:
			draw_rect(Rect2(r.position + Vector2(0, h + 2), Vector2(w * clampf(e.slow_time / 2.0, 0, 1), 2)), Color("7fd8ff"))
		if e.armor > 0.0:
			draw_circle(r.position + Vector2(-6, h * 0.5), 5.0, Color("d8dee9"))


func _draw_texts() -> void:
	for tx in _texts:
		if camera.is_position_behind(tx.pos):
			continue
		var p := camera.unproject_position(tx.pos)
		var k: float = tx.t / tx.life
		# pop in, float up, fade out
		var pop := 1.0 + 0.6 * exp(-tx.t * 14.0) * (1.0 if tx.size > 1.2 else 0.5)
		var s: float = tx.size * pop
		p += Vector2(tx.vx * k, -55.0 * k - 8.0)
		var a := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
		var fs := 22
		var txt: String = tx.text
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(p, 0.0, Vector2(s, s))
		var col: Color = tx.color
		col.a *= a
		draw_string_outline(font, Vector2(-tw * 0.5, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(GameData.C_INK, a))
		draw_string(font, Vector2(-tw * 0.5, 8), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_coins() -> void:
	for c in _coins:
		var t: float = clampf(c.t, 0.0, 1.0)
		if c.t < 0.0:
			continue
		var e := t * t * (3.0 - 2.0 * t)
		var a: Vector2 = c.from.lerp(c.ctrl, e)
		var b: Vector2 = c.ctrl.lerp(coin_target, e)
		var p := a.lerp(b, e)
		var r := 9.0 * (1.0 - 0.3 * e)
		var squash := absf(cos(c.t * 18.0))
		draw_set_transform(p, 0.0, Vector2(maxf(0.25, squash), 1.0))
		draw_circle(Vector2.ZERO, r + 2.0, GameData.C_INK)
		draw_circle(Vector2.ZERO, r, GameData.C_GOLD)
		draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.35, Color(1, 1, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
