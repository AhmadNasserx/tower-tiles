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

	# soft warm shade on the left so the menu pops off the diorama
	var g := Gradient.new()
	g.set_color(0, Color(0.17, 0.1, 0.06, 0.6))
	g.set_color(1, Color(0.17, 0.1, 0.06, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	gt.width = 64
	gt.height = 8
	var shade := TextureRect.new()
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size.x = 560
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

	_build_title()
	_build_menu()
	_build_fish_counter()
	_build_footer()
	Save.fish_changed.connect(func(f): _set_fish(f, true))


func _build_title() -> void:
	var box := UIKit.vbox(-6)
	box.position = Vector2(48, 26)
	ui.add_child(box)
	var row := UIKit.hbox(0)
	box.add_child(row)
	for ch in "TOWER TILES":
		var l := UIKit.label(ch, 88 if ch != " " else 50, UIKit.CREAM, 18, true)
		l.label_settings.shadow_size = 1
		l.label_settings.shadow_offset = Vector2(0, 7)
		l.label_settings.shadow_color = Color(0.17, 0.1, 0.06, 0.7)
		row.add_child(l)
		_title_letters.append(l)
	var sub := UIKit.ribbon("NINE LIVES", 34, 330)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(sub)
	for i in _title_letters.size():
		UIKit.pop_in(_title_letters[i], 0.05 * i)
	UIKit.pop_in(sub, 0.6)


func _build_menu() -> void:
	_menu_col = UIKit.vbox(12)
	_menu_col.position = Vector2(60, 270)
	ui.add_child(_menu_col)
	var entries := [["Play", _show_maps, "green", "play"], ["Cat Tree", _show_shop, "yellow", "fish"], ["Settings", _show_settings, "yellow", "gear"]]
	if not OS.has_feature("web"):
		entries.append(["Quit", func(): get_tree().quit(), "red", ""])
	var i := 0
	for e in entries:
		var b := UIKit.button(e[0], e[1], 30 if i == 0 else 26, e[2], e[3])
		b.custom_minimum_size = Vector2(300, 74 if i == 0 else 62)
		_menu_col.add_child(b)
		UIKit.pop_in(b, 0.4 + i * 0.08)
		i += 1
	# your cat says hi
	var hero := UIKit.portrait("hero", 150)
	hero.position = Vector2(390, 300)
	ui.add_child(hero)
	UIKit.pop_in(hero, 0.8)


func _build_fish_counter() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.wood())
	var h := UIKit.hbox(8)
	p.add_child(h)
	h.add_child(UIKit.icon("fish", Color.WHITE, 40))
	_fish_label = UIKit.label(str(Save.fish), 30, UIKit.CREAM, 8, true)
	h.add_child(_fish_label)
	p.tooltip_text = "Fish: earned by surviving waves. Spend them in the Cat Tree."
	ui.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)


func _set_fish(f: int, punch := false) -> void:
	_fish_label.text = str(f)
	if punch:
		_fish_label.pivot_offset = _fish_label.size * 0.5
		_fish_label.scale = Vector2(1.4, 1.4)
		_fish_label.create_tween().set_ignore_time_scale(true).tween_property(_fish_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _build_footer() -> void:
	var v := Engine.get_version_info()
	var l := UIKit.label("Runs: %d   Critters bonked: %d   ·   Art: Kenney (CC0)   ·   Made with Godot %d.%d" % [Save.stats.runs, Save.stats.dogs_bonked, v.major, v.minor], 15, UIKit.CREAM, 6)
	ui.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)


func _process(delta: float) -> void:
	_t += delta
	for i in _title_letters.size():
		var l := _title_letters[i]
		l.position.y = sin(_t * 3.0 - i * 0.45) * 5.0
		l.rotation = sin(_t * 2.0 - i * 0.6) * 0.04
		l.pivot_offset = l.size * 0.5


# ------------------------------------------------------------------ panels
func _open_panel(title: String, sub := "", min_width := 0.0) -> VBoxContainer:
	_close_panel()
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_content)
	UIKit.dim(_content, 0.45).gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_panel())
	var cc := UIKit.center_container(_content)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer := UIKit.vbox(-18)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(outer)
	var rb := UIKit.ribbon(title, 40, maxf(min_width * 0.7, 400))
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rb.z_index = 1
	outer.add_child(rb)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.sbox("panel_brown.png", 22, Vector4(30, 34, 30, 26)))
	panel.custom_minimum_size.x = min_width
	outer.add_child(panel)
	var v := UIKit.vbox(14)
	panel.add_child(v)
	if sub != "":
		var s := UIKit.label(sub, 17, UIKit.INK_SOFT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	UIKit.pop_in(outer)
	return v


func _close_panel() -> void:
	if _content:
		_content.queue_free()
		_content = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _content:
		_close_panel()


func _show_maps() -> void:
	var v := _open_panel("CHOOSE A MAP", "Clear a map to unlock the next. Three stars = no lives lost.")
	var row := UIKit.hbox(14)
	v.add_child(row)
	for i in GameData.MAPS.size():
		row.add_child(_map_card(i))
	var back := UIKit.button("Back", _close_panel, 20, "yellow")
	back.custom_minimum_size.x = 160
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)


func _map_card(i: int) -> Control:
	var m: Dictionary = GameData.MAPS[i]
	var unlocked := Save.map_unlocked(i)
	var b := Button.new()
	b.custom_minimum_size = Vector2(250, 300)
	b.add_theme_stylebox_override("normal", UIKit.sbox("sq_grey.png", 20, Vector4(8, 8, 8, 8), Color(1.08, 1.06, 1.0)))
	b.add_theme_stylebox_override("hover", UIKit.sbox("sq_yellow.png", 20, Vector4(8, 8, 8, 8)))
	b.add_theme_stylebox_override("pressed", UIKit.sbox("sq_yellow_pressed.png", 20, Vector4(8, 8, 8, 8)))
	b.add_theme_stylebox_override("disabled", UIKit.sbox("sq_grey.png", 20, Vector4(8, 8, 8, 8), Color(0.7, 0.66, 0.66)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = not unlocked
	var v := UIKit.vbox(8)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 14
	v.offset_bottom = -20
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(_map_thumb(m, unlocked))
	var name_l := UIKit.label(m.name, 26, UIKit.INK if unlocked else UIKit.INK_SOFT, 0, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var desc := UIKit.label(m.desc if unlocked else "Clear %s to unlock." % GameData.MAPS[i - 1].name, 15, UIKit.INK_SOFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	var stars := UIKit.hbox(4)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	var got := int(Save.stars.get(m.id, 0))
	for s in 3:
		stars.add_child(UIKit.icon("star" if s < got else "star_empty", Color.WHITE, 32))
	v.add_child(stars)
	var info := UIKit.label("Difficulty %.1fx   ·   Best wave %d" % [m.difficulty, int(Save.best_wave.get(m.id, 0))], 14, UIKit.INK_SOFT)
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
	c.custom_minimum_size = Vector2(220, 124)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("6b4426")
	frame.set_corner_radius_all(8)
	c.draw.connect(func():
		var grid: Array = m.grid
		var rows := grid.size()
		var cols: int = grid[0].length()
		var cell := minf((c.size.x - 8) / cols, (c.size.y - 8) / rows)
		var off := (c.size - Vector2(cols, rows) * cell) * 0.5
		c.draw_style_box(frame, Rect2(off - Vector2(4, 4), Vector2(cols, rows) * cell + Vector2(8, 8)))
		for y in rows:
			for x in cols:
				var ch: String = grid[y][x]
				var col: Color = Color("8fd16a") if (x + y) % 2 == 0 else Color("83c45f")
				match ch:
					"#": col = Color("f2c98a")
					"S": col = Color("c0504d")
					"C": col = Color("a66cff")
					"T": col = Color("3f8f4a")
					"R": col = Color("9aa5b1")
				if not unlocked:
					col = Color(col.v * 0.55, col.v * 0.5, col.v * 0.45)
				c.draw_rect(Rect2(off + Vector2(x, y) * cell, Vector2(cell, cell)), col))
	if not unlocked:
		var lock := UIKit.icon("lock", Color.WHITE, 52)
		lock.position = Vector2(84, 36)
		c.add_child(lock)
	return c


func _show_shop() -> void:
	var v := _open_panel("THE CAT TREE", "", 780)
	var fish_row := UIKit.hbox(8)
	fish_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fish_row.add_child(UIKit.icon("fish", Color.WHITE, 36))
	fish_row.add_child(UIKit.label("%d fish" % Save.fish, 28, Color("2f7fc1"), 0, true))
	fish_row.add_child(UIKit.label("  ·  Permanent upgrades for every run", 16, UIKit.INK_SOFT))
	v.add_child(fish_row)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
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
		_show_shop(), 18, "red")
	refund.tooltip_text = "Get every fish back and re-spec."
	row.add_child(refund)
	row.add_child(UIKit.button("Back", _close_panel, 20, "yellow"))
	v.add_child(row)


func _meta_card(id: String) -> Control:
	var d: Dictionary = GameData.META[id]
	var lvl := Save.meta_level(id)
	var maxed: bool = lvl >= d.max
	var cost := 0 if maxed else GameData.meta_cost(id, lvl)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sbox("sq_grey.png", 20, Vector4(12, 8, 12, 14), Color(1.08, 1.06, 1.0) if not maxed else Color(1.15, 1.08, 0.8)))
	p.custom_minimum_size = Vector2(238, 0)
	var v := UIKit.vbox(2)
	p.add_child(v)
	var top := UIKit.hbox(8)
	v.add_child(top)
	top.add_child(UIKit.icon(d.icon, Color.WHITE, 38))
	var names := UIKit.vbox(-4)
	names.add_child(UIKit.label(d.name, 18, UIKit.INK, 0, true))
	names.add_child(UIKit.label(d.desc, 13, UIKit.INK_SOFT))
	top.add_child(names)
	var bottom := UIKit.hbox(6)
	v.add_child(bottom)
	var pips := UIKit.hbox(1)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.alignment = BoxContainer.ALIGNMENT_BEGIN
	for i in d.max:
		var st := UIKit.icon("star" if i < lvl else "star_empty", Color.WHITE, 18)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(st)
	bottom.add_child(pips)
	var b: Button
	if maxed:
		b = UIKit.button("MAX", func(): pass, 16, "grey")
		b.disabled = true
	else:
		b = UIKit.button("%d" % cost, func():
			if Save.buy_meta(id):
				Sfx.play("upgrade")
				Sfx.play("meow", 1.2, 0.1, -4.0)
				_show_shop()
			else:
				Sfx.play("error"), 16, "green", "fish")
		b.disabled = Save.fish < cost
		b.tooltip_text = "Buy for %d fish" % cost
	b.custom_minimum_size.x = 96
	bottom.add_child(b)
	return p


func _show_settings() -> void:
	var v := _open_panel("SETTINGS")
	var s := SettingsPanel.new()
	v.add_child(s)
	s.closed.connect(_close_panel)
