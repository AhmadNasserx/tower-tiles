extends Node
## Title screen. A live demo battle plays in the background while you pick a
## map, spend fish in the Cat Tree, or tweak settings.

const SettingsPanel := preload("res://ui/settings_panel.gd")
const GAME_SCENE := preload("res://scenes/game.tscn")

var ui: Control
var _fish_label: Label
var _content: Control
var _menu_col: VBoxContainer
var _title_letters: Array[Label] = []
var _t := 0.0


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.selected_map = 0
	var demo: Game = GAME_SCENE.instantiate()
	demo.demo = true
	add_child(demo)
	Sfx.music("menu")

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UIKit.theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)

	# soft dark gradient on the left so the menu text pops
	var g := Gradient.new()
	g.set_color(0, Color(GameData.C_INK, 0.85))
	g.set_color(1, Color(GameData.C_INK, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	gt.width = 64
	gt.height = 8
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size.x = 640
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

	_build_title()
	_build_menu()
	_build_fish_counter()
	_build_footer()
	Save.fish_changed.connect(func(f): _set_fish(f, true))


func _build_title() -> void:
	var box := UIKit.vbox(0)
	box.position = Vector2(56, 40)
	ui.add_child(box)
	var row := UIKit.hbox(0)
	box.add_child(row)
	for ch in "TOWER TILES":
		var l := UIKit.label(ch, 76, GameData.C_CREAM, 16, true)
		row.add_child(l)
		_title_letters.append(l)
	var sub := UIKit.hbox(10)
	box.add_child(sub)
	sub.add_child(UIKit.icon("cat", GameData.C_ORANGE, 44))
	sub.add_child(UIKit.label("NINE LIVES DEFENSE", 30, GameData.C_ORANGE, 10, true))
	for i in _title_letters.size():
		UIKit.pop_in(_title_letters[i], 0.05 * i)


func _build_menu() -> void:
	_menu_col = UIKit.vbox(14)
	_menu_col.position = Vector2(64, 250)
	ui.add_child(_menu_col)
	var entries := [["Play", _show_maps], ["Cat Tree", _show_shop], ["Settings", _show_settings]]
	if not OS.has_feature("web"):
		entries.append(["Quit", func(): get_tree().quit()])
	var i := 0
	for e in entries:
		var b := UIKit.button(e[0], e[1], 28)
		b.custom_minimum_size = Vector2(280, 64)
		if i == 0:
			b.add_theme_stylebox_override("normal", UIKit.panel_style(GameData.C_ORANGE, GameData.C_INK, 16, 3))
			b.add_theme_stylebox_override("hover", UIKit.panel_style(GameData.C_ORANGE.lightened(0.2), GameData.C_INK, 16, 3))
		_menu_col.add_child(b)
		UIKit.pop_in(b, 0.4 + i * 0.08)
		i += 1


func _build_fish_counter() -> void:
	var p := PanelContainer.new()
	var h := UIKit.hbox(8)
	p.add_child(h)
	h.add_child(UIKit.icon("fish", GameData.C_BLUE, 36))
	_fish_label = UIKit.label(str(Save.fish), 28, GameData.C_CREAM, 0, true)
	h.add_child(_fish_label)
	p.tooltip_text = "Fish: earned by surviving waves. Spend them in the Cat Tree."
	ui.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)


func _set_fish(f: int, punch := false) -> void:
	_fish_label.text = str(f)
	if punch:
		_fish_label.pivot_offset = _fish_label.size * 0.5
		_fish_label.scale = Vector2(1.4, 1.4)
		_fish_label.create_tween().set_ignore_time_scale(true).tween_property(_fish_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _build_footer() -> void:
	var l := UIKit.label("Runs: %d   Dogs bonked: %d   ·   Made with Godot %s" % [Save.stats.runs, Save.stats.dogs_bonked, "%d.%d" % [Engine.get_version_info().major, Engine.get_version_info().minor]], 14, Color(1, 1, 1, 0.6), 4)
	ui.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)


func _process(delta: float) -> void:
	_t += delta
	for i in _title_letters.size():
		var l := _title_letters[i]
		l.position.y = sin(_t * 3.0 - i * 0.45) * 5.0
		l.rotation = sin(_t * 2.0 - i * 0.6) * 0.04
		l.pivot_offset = l.size * 0.5


# ------------------------------------------------------------------ panels
func _open_panel(min_width := 0.0) -> VBoxContainer:
	_close_panel()
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_content)
	UIKit.dim(_content, 0.5).gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_panel())
	var cc := UIKit.center_container(_content)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(GameData.C_INK, 0.96), GameData.C_ORANGE, 22, 4))
	panel.custom_minimum_size.x = min_width
	cc.add_child(panel)
	var v := UIKit.vbox(14)
	panel.add_child(v)
	UIKit.pop_in(panel)
	return v


func _close_panel() -> void:
	if _content:
		_content.queue_free()
		_content = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _content:
		_close_panel()


func _header(v: VBoxContainer, title: String, sub: String) -> void:
	var t := UIKit.label(title, 40, GameData.C_ORANGE, 0, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := UIKit.label(sub, 17, Color("b9adc0"))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)


func _show_maps() -> void:
	var v := _open_panel()
	_header(v, "Choose a Map", "Clear a map to unlock the next one. Three stars = no lives lost.")
	var row := UIKit.hbox(16)
	v.add_child(row)
	for i in GameData.MAPS.size():
		row.add_child(_map_card(i))
	var back := UIKit.button("Back", _close_panel, 18)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


func _map_card(i: int) -> Control:
	var m: Dictionary = GameData.MAPS[i]
	var unlocked := Save.map_unlocked(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 300)
	var border := GameData.C_GREEN if unlocked else Color("6b5d73")
	b.add_theme_stylebox_override("normal", UIKit.panel_style(Color("3a2b45"), border, 18, 3))
	b.add_theme_stylebox_override("hover", UIKit.panel_style(Color("4a3b57"), GameData.C_ORANGE, 18, 4))
	b.add_theme_stylebox_override("pressed", UIKit.panel_style(Color("2a1f33"), GameData.C_ORANGE, 18, 4))
	b.add_theme_stylebox_override("disabled", UIKit.panel_style(Color("2a1f33"), Color("4a3b57"), 18, 3))
	b.disabled = not unlocked
	var v := UIKit.vbox(8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 14
	v.offset_bottom = -14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(_map_thumb(m, unlocked))
	var name_l := UIKit.label(m.name, 24, GameData.C_CREAM if unlocked else Color("8a7d94"), 0, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var desc := UIKit.label(m.desc if unlocked else "Clear %s to unlock." % GameData.MAPS[i - 1].name, 15, Color("b9adc0"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	var stars := UIKit.hbox(4)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	var got := int(Save.stars.get(m.id, 0))
	for s in 3:
		stars.add_child(UIKit.icon("star" if s < got else "star_empty", GameData.C_GOLD, 30))
	v.add_child(stars)
	var info := UIKit.label("Difficulty %.1fx   Best wave %d" % [m.difficulty, int(Save.best_wave.get(m.id, 0))], 14, Color("b9adc0"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	b.pressed.connect(func():
		Game.selected_map = i
		Sfx.play("meow", 1.0, 0.05)
		Transition.change_scene("res://scenes/game.tscn"))
	UIKit.juicy(b, 1.04)
	return b


## A tiny drawn preview of the map grid.
func _map_thumb(m: Dictionary, unlocked: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(220, 120)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var grid: Array = m.grid
		var rows := grid.size()
		var cols: int = grid[0].length()
		var cell := minf(c.size.x / cols, c.size.y / rows)
		var off := (c.size - Vector2(cols, rows) * cell) * 0.5
		for y in rows:
			for x in cols:
				var ch: String = grid[y][x]
				var col: Color = m.grass[(x + y) % 2]
				match ch:
					"#": col = m.road
					"S": col = Color("c0504d")
					"C": col = GameData.C_PURPLE
					"T": col = Color("3f8f4a")
					"R": col = Color("9aa5b1")
				if not unlocked:
					col = Color(col.v * 0.4, col.v * 0.35, col.v * 0.45)
				c.draw_rect(Rect2(off + Vector2(x, y) * cell, Vector2(cell - 1, cell - 1)), col)
		if not unlocked:
			var lk := c.size * 0.5
			c.draw_circle(lk, 26, Color(GameData.C_INK, 0.8)))
	if not unlocked:
		var lock := UIKit.icon("lock", Color.WHITE, 36)
		lock.position = Vector2(92, 42)
		c.add_child(lock)
	return c


func _show_shop() -> void:
	var v := _open_panel(760)
	_header(v, "The Cat Tree", "Permanent upgrades for every run. Earn fish by surviving waves.")
	var fish_row := UIKit.hbox(8)
	fish_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fish_row.add_child(UIKit.icon("fish", GameData.C_BLUE, 30))
	var fl := UIKit.label("%d fish" % Save.fish, 24, GameData.C_BLUE, 0, true)
	fish_row.add_child(fl)
	v.add_child(fish_row)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var i := 0
	for id in GameData.META_ORDER:
		var card := _meta_card(id)
		grid.add_child(card)
		UIKit.pop_in(card, 0.05 + i * 0.03)
		i += 1
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var refund := UIKit.button("Refund all", func():
		Save.refund_meta()
		Sfx.play("sell")
		_show_shop(), 16)
	refund.tooltip_text = "Get every fish back and re-spec."
	row.add_child(refund)
	row.add_child(UIKit.button("Back", _close_panel, 18))
	v.add_child(row)


func _meta_card(id: String) -> Control:
	var d: Dictionary = GameData.META[id]
	var lvl := Save.meta_level(id)
	var maxed: bool = lvl >= d.max
	var cost := 0 if maxed else GameData.meta_cost(id, lvl)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style(Color("3a2b45"), GameData.C_GOLD if maxed else Color("4a3b57"), 14, 3))
	p.custom_minimum_size = Vector2(236, 0)
	var v := UIKit.vbox(6)
	p.add_child(v)
	var top := UIKit.hbox(8)
	v.add_child(top)
	var col: Color = {"heart": GameData.C_RED, "coin": GameData.C_GOLD, "paw": GameData.C_ORANGE, "cat": GameData.C_ORANGE,
		"bolt": GameData.C_PURPLE, "star": GameData.C_GOLD}.get(d.icon, GameData.C_CREAM)
	top.add_child(UIKit.icon(d.icon, col, 34))
	var names := UIKit.vbox(0)
	names.add_child(UIKit.label(d.name, 18, GameData.C_CREAM, 0, true))
	names.add_child(UIKit.label(d.desc, 13, Color("b9adc0")))
	top.add_child(names)
	var pips := UIKit.hbox(4)
	for i in d.max:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 8)
		pip.color = GameData.C_GOLD if i < lvl else Color("4a3b57")
		pips.add_child(pip)
	v.add_child(pips)
	var b: Button
	if maxed:
		b = UIKit.button("MAXED", func(): pass, 16)
		b.disabled = true
	else:
		b = UIKit.button("Buy  %d fish" % cost, func():
			if Save.buy_meta(id):
				Sfx.play("upgrade")
				Sfx.play("meow", 1.2, 0.1, -4.0)
				_show_shop()
			else:
				Sfx.play("error"), 16)
		b.disabled = Save.fish < cost
	v.add_child(b)
	return p


func _show_settings() -> void:
	var v := _open_panel()
	var s := SettingsPanel.new()
	v.add_child(s)
	s.closed.connect(_close_panel)
