extends CanvasLayer
## In-game HUD, built entirely in code. Polls the Game for numbers each frame
## and reacts to its signals for the juicy moments.

const Icon := preload("res://ui/icon.gd")
const SettingsPanel := preload("res://ui/settings_panel.gd")

var game: Game

var root: Control
var _lives_label: Label
var _lives_icon: Control
var _gold_label: Label
var _gold_icon: Control
var _wave_label: Label
var _wave_btn: Button
var _preview: HBoxContainer
var _preview_box: VBoxContainer
var _speed_btn: Button
var _build_cards := {}
var _ability_paw: Button
var _ability_zoom: Button
var _paw_dial: Control
var _zoom_dial: Control
var _sel_panel: PanelContainer
var _sel_title: Label
var _sel_stars: HBoxContainer
var _sel_stats: Label
var _sel_extra: Label
var _sel_upgrade: Button
var _sel_target: Button
var _sel_sell: Button
var _boss_box: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _toasts: VBoxContainer
var _vignette: TextureRect
var _zoom_tint: TextureRect
var _modal: Control
var _hint: PanelContainer
var _hint_label: Label
var _tutorial_step := -1
var _shown_gold := -1
var _last_lives := -1
var _preview_wave := -1


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	_vignette = _make_vignette(GameData.C_RED)
	_zoom_tint = _make_vignette(GameData.C_PURPLE)
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_build_bar()
	_build_abilities()
	_build_selection_panel()
	_build_banner()
	_build_hint()

	game.gold_changed.connect(func(_g): _refresh_cards())
	game.lives_changed.connect(_on_lives_changed)
	game.selection_changed.connect(_on_selection_changed)
	game.build_mode_changed.connect(func(_t): _refresh_cards())
	game.wave_changed.connect(_on_wave_changed)
	game.overlay.coin_target = Vector2(200, 36)
	_refresh_cards()
	if not Save.settings.tutorial_done:
		_set_tutorial(0)
	banner(game.map.name.to_upper(), "Protect your cat. Don't let the dogs reach the tower!", GameData.C_CREAM, 2.6)


# ------------------------------------------------------------------ layout
func _anchored(c: Control, preset: Control.LayoutPreset, offset := Vector2.ZERO) -> Control:
	root.add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 12)
	c.position += offset
	return c


func _make_vignette(col: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.set_color(1, Color(col, 0.75))
	g.set_offset(0, 0.55)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 128
	gt.height = 128
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	root.add_child(tr)
	return tr


func _stat_chip(icon_kind: String, color: Color) -> Array:
	var h := UIKit.hbox(6)
	var i := UIKit.icon(icon_kind, color, 30)
	h.add_child(i)
	var l := UIKit.label("0", 26, GameData.C_CREAM, 8, true)
	h.add_child(l)
	return [h, l, i]


func _build_top_left() -> void:
	var panel := PanelContainer.new()
	var row := UIKit.hbox(22)
	panel.add_child(row)
	var lives := _stat_chip("heart", GameData.C_RED)
	row.add_child(lives[0])
	_lives_label = lives[1]
	_lives_icon = lives[2]
	var gold := _stat_chip("coin", GameData.C_GOLD)
	row.add_child(gold[0])
	_gold_label = gold[1]
	_gold_icon = gold[2]
	_gold_label.custom_minimum_size.x = 70
	_wave_label = UIKit.label("Wave 0/20", 22, GameData.C_CREAM, 6, true)
	row.add_child(_wave_label)
	_anchored(panel, Control.PRESET_TOP_LEFT)


func _build_top_center() -> void:
	var box := UIKit.vbox(6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_wave_btn = UIKit.button("Start Wave", func(): game.start_wave(), 24)
	_wave_btn.custom_minimum_size = Vector2(250, 52)
	_wave_btn.add_theme_stylebox_override("normal", UIKit.panel_style(GameData.C_GREEN, GameData.C_INK, 14))
	_wave_btn.add_theme_stylebox_override("hover", UIKit.panel_style(GameData.C_GREEN.lightened(0.2), GameData.C_INK, 14))
	_wave_btn.tooltip_text = "Start the next wave now (Space). Calling early earns bonus gold!"
	box.add_child(_wave_btn)
	_wave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_preview_box = UIKit.vbox(2)
	var preview_panel := PanelContainer.new()
	preview_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(GameData.C_INK, 0.75), Color("4a3b57"), 12, 2))
	preview_panel.add_child(_preview_box)
	preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := UIKit.label("NEXT UP", 13, Color("b9adc0"), 0, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_box.add_child(title)
	_preview = UIKit.hbox(10)
	_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview_box.add_child(_preview)
	box.add_child(preview_panel)

	_boss_box = PanelContainer.new()
	_boss_box.add_theme_stylebox_override("panel", UIKit.panel_style(Color(GameData.C_INK, 0.85), GameData.C_RED, 12, 3))
	var bb := UIKit.vbox(4)
	_boss_box.add_child(bb)
	_boss_name = UIKit.label("BOSS", 18, GameData.C_RED, 0, true)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bb.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(380, 18)
	_boss_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("3a2b45")
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GameData.C_RED
	fill.set_corner_radius_all(8)
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	bb.add_child(_boss_bar)
	_boss_box.visible = false
	_boss_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_boss_box)

	_toasts = UIKit.vbox(4)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(_toasts)

	_anchored(box, Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.resized.connect(func(): box.position.x = (root.size.x - box.size.x) * 0.5)


func _build_top_right() -> void:
	var row := UIKit.hbox(8)
	_speed_btn = UIKit.button("1x", func(): game.cycle_speed(), 20)
	_speed_btn.custom_minimum_size = Vector2(70, 48)
	_speed_btn.tooltip_text = "Game speed (F)"
	row.add_child(_speed_btn)
	var pause := UIKit.button("", toggle_pause)
	pause.custom_minimum_size = Vector2(52, 48)
	pause.tooltip_text = "Pause (Esc)"
	var pi := UIKit.icon("pause", GameData.C_INK, 26)
	pi.set_anchors_preset(Control.PRESET_CENTER)
	pi.position -= Vector2(13, 13)
	pause.add_child(pi)
	row.add_child(pause)
	_anchored(row, Control.PRESET_TOP_RIGHT)


func _build_build_bar() -> void:
	var panel := PanelContainer.new()
	var row := UIKit.hbox(10)
	panel.add_child(row)
	for type in GameData.TURRET_ORDER:
		var d: Dictionary = GameData.TURRETS[type]
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 112)
		b.tooltip_text = "%s  [%s]\n%s" % [d.name, d.key, d.desc]
		b.pressed.connect(func(): game.set_build_type(type))
		var v := UIKit.vbox(0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var ic := UIKit.icon(d.icon, d.accent, 42)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var nm := UIKit.label(d.name, 14, GameData.C_INK, 0, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var cost_row := UIKit.hbox(3)
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_child(UIKit.icon("coin", GameData.C_GOLD, 18))
		var cl := UIKit.label(str(d.cost), 17, GameData.C_INK, 0, true)
		cost_row.add_child(cl)
		v.add_child(cost_row)
		var key := UIKit.label(d.key, 13, GameData.C_CREAM, 0, true)
		var kb := PanelContainer.new()
		kb.add_theme_stylebox_override("panel", UIKit.panel_style(GameData.C_INK, GameData.C_INK, 6, 0))
		kb.add_child(key)
		kb.position = Vector2(-6, -8)
		kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(kb)
		UIKit.juicy(b, 1.08)
		row.add_child(b)
		_build_cards[type] = {"button": b, "cost": cl}
	_anchored(panel, Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _ability_button(icon_kind: String, color: Color, key: String, tip: String, cb: Callable) -> Array:
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 84)
	b.tooltip_text = tip
	b.pressed.connect(cb)
	b.add_theme_stylebox_override("normal", UIKit.panel_style(color.lightened(0.55), GameData.C_INK, 42))
	b.add_theme_stylebox_override("hover", UIKit.panel_style(color.lightened(0.7), GameData.C_INK, 42))
	b.add_theme_stylebox_override("pressed", UIKit.panel_style(color.lightened(0.3), GameData.C_INK, 42))
	var ic := UIKit.icon(icon_kind, color, 50)
	ic.position = Vector2(17, 15)
	b.add_child(ic)
	var dial := preload("res://ui/cooldown_dial.gd").new()
	dial.set_anchors_preset(Control.PRESET_FULL_RECT)
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(dial)
	var k := UIKit.label(key, 16, GameData.C_CREAM, 6, true)
	k.position = Vector2(62, 58)
	b.add_child(k)
	UIKit.juicy(b, 1.1)
	return [b, dial]


func _build_abilities() -> void:
	var row := UIKit.hbox(12)
	var paw := _ability_button("paw", GameData.C_ORANGE, "Q", "GIANT PAW (Q)\nClick the road to squash dogs and stun survivors.", func(): game.begin_paw())
	_ability_paw = paw[0]
	_paw_dial = paw[1]
	row.add_child(_ability_paw)
	var zoom := _ability_button("bolt", GameData.C_PURPLE, "E", "ZOOMIES (E)\nAll kittens (and your cat) attack twice as fast for a few seconds.", func(): game.activate_zoomies())
	_ability_zoom = zoom[0]
	_zoom_dial = zoom[1]
	row.add_child(_ability_zoom)
	_anchored(row, Control.PRESET_BOTTOM_LEFT)


func _build_selection_panel() -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.custom_minimum_size = Vector2(300, 0)
	var v := UIKit.vbox(8)
	_sel_panel.add_child(v)
	_sel_title = UIKit.label("Kitty", 24, GameData.C_ORANGE, 0, true)
	v.add_child(_sel_title)
	_sel_stars = UIKit.hbox(2)
	v.add_child(_sel_stars)
	_sel_stats = UIKit.label("", 16)
	_sel_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sel_stats.custom_minimum_size.x = 270
	v.add_child(_sel_stats)
	_sel_extra = UIKit.label("", 14, Color("b9adc0"))
	v.add_child(_sel_extra)
	_sel_upgrade = UIKit.button("Upgrade", func(): game.upgrade_selected(), 18)
	v.add_child(_sel_upgrade)
	_sel_target = UIKit.button("Target: First", func(): game.cycle_target_mode(), 16)
	_sel_target.tooltip_text = "Which dog to attack first (T)"
	v.add_child(_sel_target)
	_sel_sell = UIKit.button("Sell", func(): game.sell_selected(), 16)
	_sel_sell.add_theme_stylebox_override("normal", UIKit.panel_style(Color("ffb3c6"), GameData.C_INK, 14))
	v.add_child(_sel_sell)
	_anchored(_sel_panel, Control.PRESET_CENTER_RIGHT)
	_sel_panel.visible = false


func _build_banner() -> void:
	_banner = UIKit.vbox(0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_title = UIKit.label("", 64, GameData.C_CREAM, 14, true)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = UIKit.label("", 22, GameData.C_CREAM, 8)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	root.add_child(_banner)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.modulate.a = 0.0


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", UIKit.panel_style(GameData.C_CREAM, GameData.C_ORANGE, 14, 4))
	_hint_label = UIKit.label("", 18, GameData.C_INK, 0, true)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = 320
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_child(_hint_label)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	root.add_child(_hint)


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if game == null:
		return
	var shown := int(round(game.display_gold))
	if shown != _shown_gold:
		_shown_gold = shown
		_gold_label.text = str(shown)
	_wave_label.text = "Wave %d/%d" % [game.wave, GameData.WAVES_TO_WIN] if not game.endless else "Wave %d  ENDLESS" % game.wave
	_speed_btn.text = "%dx" % int(Game.SPEEDS[game.speed_index])

	# wave button + preview
	var can_start := not game.in_wave and game.playing
	_wave_btn.visible = can_start
	_preview_box.get_parent().visible = can_start
	if can_start:
		if game.countdown > 0.0 and game.wave > 0:
			_wave_btn.text = "Next wave in %d  (+%d)" % [ceili(game.countdown), int(game.countdown * 1.5)]
		else:
			_wave_btn.text = "Start Wave %d" % (game.wave + 1)
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.03
		if not _wave_btn.is_hovered():
			_wave_btn.pivot_offset = _wave_btn.size * 0.5
			_wave_btn.scale = Vector2(pulse, pulse)
		if _preview_wave != game.wave:
			_preview_wave = game.wave
			_rebuild_preview()

	# boss bar
	var b: Enemy = game.boss
	_boss_box.visible = b != null and is_instance_valid(b) and b.alive
	if _boss_box.visible:
		_boss_name.text = b.def.name.to_upper()
		_boss_bar.max_value = b.max_hp
		_boss_bar.value = b.hp

	# abilities
	_paw_dial.fraction = clampf(game.paw_cd / game.paw_cooldown_total(), 0.0, 1.0)
	_paw_dial.seconds = game.paw_cd
	_paw_dial.active = game.mode == "paw"
	_zoom_dial.fraction = clampf(game.zoomies_cd / game.zoomies_cooldown_total(), 0.0, 1.0)
	_zoom_dial.seconds = game.zoomies_cd
	_zoom_dial.active = game.zoomies_time > 0.0
	_zoom_tint.modulate.a = lerpf(_zoom_tint.modulate.a, 0.35 if game.zoomies_time > 0.0 else 0.0, minf(1.0, delta * 8.0))

	# low lives heartbeat
	if game.lives <= 3 and game.playing:
		var beat := 1.0 + absf(sin(Time.get_ticks_msec() * 0.006)) * 0.25
		_lives_icon.pivot_offset = _lives_icon.size * 0.5
		_lives_icon.scale = Vector2(beat, beat)

	if _sel_panel.visible and game.selected and is_instance_valid(game.selected):
		_refresh_selection_buttons()
	if _tutorial_step == 0 and game.turrets.size() > 0:
		_set_tutorial(1)
	if _hint.visible:
		_hint.position.y += sin(Time.get_ticks_msec() * 0.005) * 0.3
	game.overlay.coin_target = _gold_icon.global_position + _gold_icon.size * 0.5


func _rebuild_preview() -> void:
	for c in _preview.get_children():
		c.queue_free()
	var summary := game.next_wave_preview()
	for type in summary:
		var d: Dictionary = GameData.ENEMIES[type]
		var chip := UIKit.hbox(2)
		var ic := UIKit.icon("dog", d.coat, 30)
		ic.tooltip_text = d.name
		chip.add_child(ic)
		chip.add_child(UIKit.label("x%d" % summary[type], 18, GameData.C_RED if d.get("boss", false) else GameData.C_CREAM, 6, true))
		chip.tooltip_text = d.name
		_preview.add_child(chip)


func is_mouse_over_ui() -> bool:
	if _modal:
		return true
	var h := root.get_viewport().gui_get_hovered_control()
	return h != null


# ------------------------------------------------------------------ build bar / selection
func _refresh_cards() -> void:
	for type in _build_cards:
		var card: Dictionary = _build_cards[type]
		var cost := game.price(GameData.TURRETS[type].cost)
		(card.cost as Label).text = str(cost)
		var b: Button = card.button
		var afford := game.gold >= cost
		b.modulate = Color(1, 1, 1) if afford else Color(0.75, 0.68, 0.75)
		var selected: bool = game.build_type == type
		var style := UIKit.panel_style(Color("ffe2b8") if selected else (GameData.C_CREAM if afford else Color("c8bccd")), GameData.C_ORANGE if selected else GameData.C_INK, 14, 4 if selected else 3)
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", UIKit.panel_style(Color("fff0d6"), GameData.C_ORANGE, 14, 3))
		if selected:
			b.pivot_offset = b.size * 0.5
			b.scale = Vector2(1.08, 1.08)
	if game.selected:
		_refresh_selection_buttons()


func _on_selection_changed(t: Turret) -> void:
	if t == null:
		if _sel_panel.visible:
			var tw := create_tween().set_ignore_time_scale(true)
			tw.tween_property(_sel_panel, "modulate:a", 0.0, 0.12)
			tw.tween_callback(func(): _sel_panel.visible = false if game.selected == null else true)
		return
	var was_hidden := not _sel_panel.visible
	_sel_panel.visible = true
	_sel_panel.modulate.a = 1.0
	_sel_title.text = t.def.name
	_sel_title.label_settings.font_color = t.def.accent.lightened(0.2)
	for c in _sel_stars.get_children():
		c.queue_free()
	for i in Turret.MAX_LEVEL + 1:
		_sel_stars.add_child(UIKit.icon("star" if i <= t.level else "star_empty", GameData.C_GOLD, 24))
	_sel_stats.text = t.describe_stats()
	if t.def.kind == "income":
		_sel_extra.text = "Snoozing. Pays out when a wave ends."
	else:
		_sel_extra.text = "Bonks: %d    Damage: %d" % [t.kills, int(t.damage_done)]
	_sel_target.visible = not (t.def.kind in ["income", "pulse"])
	_sel_target.text = "Target: %s  [T]" % GameData.TARGET_MODES[t.target_mode]
	_refresh_selection_buttons()
	if was_hidden:
		var x := _sel_panel.position.x
		_sel_panel.position.x += 340
		create_tween().set_ignore_time_scale(true).tween_property(_sel_panel, "position:x", x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_selection_buttons() -> void:
	var t: Turret = game.selected
	if t == null or not is_instance_valid(t):
		return
	if t.is_max():
		_sel_upgrade.text = "MAX LEVEL"
		_sel_upgrade.disabled = true
	else:
		var cost := t.upgrade_cost()
		_sel_upgrade.text = "Upgrade  %d  [U]" % cost
		_sel_upgrade.disabled = game.gold < cost
	_sel_sell.text = "Sell  +%d  [X]" % t.sell_value()
	if t.def.kind != "income":
		_sel_extra.text = "Bonks: %d    Damage: %d" % [t.kills, int(t.damage_done)]


# ------------------------------------------------------------------ reactions
func _on_lives_changed(lives: int, max_lives: int) -> void:
	_lives_label.text = "%d/%d" % [lives, max_lives]
	if _last_lives >= 0 and lives < _last_lives:
		_punch(_lives_icon, 1.6)
		_punch(_lives_label, 1.4)
	_last_lives = lives


func _on_wave_changed(w: int) -> void:
	_punch(_wave_label, 1.3)
	if w == 1 and _tutorial_step >= 0 and _tutorial_step < 2:
		_set_tutorial(2)


func _punch(c: Control, amount: float) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(amount, amount)
	c.create_tween().set_ignore_time_scale(true).tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func bump_gold() -> void:
	_punch(_gold_icon, 1.35)


func flash_damage() -> void:
	_vignette.modulate.a = 0.9
	create_tween().set_ignore_time_scale(true).tween_property(_vignette, "modulate:a", 0.0, 0.6)


func banner(title: String, sub: String, color: Color, hold := 1.6) -> void:
	_banner_title.text = title
	_banner_title.label_settings.font_color = color
	_banner_sub.text = sub
	if _banner_tween:
		_banner_tween.kill()
	_banner.reset_size()
	_banner.position = Vector2((root.size.x - _banner.size.x) * 0.5, root.size.y * 0.3 - _banner.size.y * 0.5)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.8, 1.8)
	_banner.modulate.a = 0.0
	_banner_tween = create_tween().set_ignore_time_scale(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.1)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.35)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2(0.85, 0.85), 0.35)


func toast(text: String, color := GameData.C_CREAM) -> void:
	var l := UIKit.label(text, 20, color, 7, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	if _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
	UIKit.pop_in(l)
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ tutorial
func _set_tutorial(step: int) -> void:
	_tutorial_step = step
	match step:
		0:
			_show_hint("Pick a kitten below (or press 1-5), then click a grass tile to place it near the road.", Control.PRESET_CENTER_BOTTOM, Vector2(0, -150))
		1:
			_show_hint("Nice! Press START WAVE when you're ready. Dogs follow the road to your cat's tower.", Control.PRESET_CENTER_TOP, Vector2(0, 150))
		2:
			_show_hint("Click a kitten to upgrade it.\nQ = Giant Paw, E = Zoomies. Right-drag or WASD to pan.", Control.PRESET_CENTER_BOTTOM, Vector2(0, -150))
			get_tree().create_timer(9.0).timeout.connect(func():
				_hint.visible = false
				_tutorial_step = 3
				Save.set_setting("tutorial_done", true))


func _show_hint(text: String, preset: Control.LayoutPreset, offset: Vector2) -> void:
	_hint_label.text = text
	_hint.visible = true
	_hint.reset_size()
	_hint.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 12)
	_hint.position += offset
	UIKit.pop_in(_hint)


# ------------------------------------------------------------------ modals
func _open_modal() -> VBoxContainer:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_modal)
	UIKit.dim(_modal, 0.6)
	var cc := UIKit.center_container(_modal)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(GameData.C_INK, 0.96), GameData.C_ORANGE, 22, 4))
	cc.add_child(panel)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	UIKit.pop_in(panel)
	return v


func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


func toggle_pause() -> void:
	if _modal and not get_tree().paused:
		return
	if get_tree().paused:
		if _modal and _modal.has_meta("pause"):
			_close_modal()
			get_tree().paused = false
		return
	if not game.playing:
		return
	get_tree().paused = true
	Sfx.play("click")
	_show_pause_menu()


func _show_pause_menu() -> void:
	var v := _open_modal()
	_modal.set_meta("pause", true)
	var t := UIKit.label("Paws-ed", 48, GameData.C_ORANGE, 0, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_center(UIKit.label("Lives lost: %d    Dogs bonked: %d" % [game.lives_lost, game.stats_kills], 18)))
	for entry in [["Resume", func(): toggle_pause()],
			["Settings", func(): _show_settings()],
			["Restart", func(): game.restart()],
			["Main Menu", func(): game.quit_to_menu()]]:
		var b := UIKit.button(entry[0], entry[1], 22)
		b.custom_minimum_size = Vector2(260, 52)
		v.add_child(b)
	v.add_child(_center(UIKit.label("Keys: 1-5 build · Q paw · E zoomies · Space wave · F speed\nU upgrade · X sell · T target · right-drag pan · wheel zoom", 14, Color("b9adc0"))))


func _show_settings() -> void:
	var v := _open_modal()
	_modal.set_meta("pause", true)
	var s := SettingsPanel.new()
	v.add_child(s)
	s.closed.connect(_show_pause_menu)


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func show_perks(options: Array) -> void:
	if options.is_empty():
		return
	get_tree().paused = true
	var v := _open_modal()
	var t := UIKit.label("Choose a Purr-k!", 44, GameData.C_ORANGE, 0, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_center(UIKit.label("Your cat found something shiny after wave %d." % game.wave, 18, Color("b9adc0"))))
	var row := UIKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	Sfx.play("perk")
	var i := 0
	for id in options:
		var d: Dictionary = GameData.PERKS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 270)
		b.add_theme_stylebox_override("normal", UIKit.panel_style(GameData.C_CREAM, d.color.darkened(0.2), 18, 4))
		b.add_theme_stylebox_override("hover", UIKit.panel_style(Color("fff8ec"), d.color, 18, 6))
		var cv := UIKit.vbox(10)
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.offset_left = 14
		cv.offset_right = -14
		cv.offset_top = 18
		cv.offset_bottom = -14
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cv)
		var ic := UIKit.icon(d.icon, d.color, 72)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var nm := UIKit.label(d.name, 22, GameData.C_INK, 0, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(nm)
		var ds := UIKit.label(d.desc, 16, Color("4a3b57"))
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(ds)
		var stack := game.perk(id)
		if stack > 0:
			var st := UIKit.label("Level %d → %d" % [stack, stack + 1], 15, d.color.darkened(0.3), 0, true)
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(st)
		b.pressed.connect(func():
			_close_modal()
			get_tree().paused = false
			game.take_perk(id)
			banner(d.name.to_upper(), d.desc, d.color, 1.2))
		UIKit.juicy(b, 1.05)
		row.add_child(b)
		UIKit.pop_in(b, 0.1 + i * 0.08)
		i += 1
	if game.rerolls > 0:
		var rr := UIKit.button("Reroll (%d left)" % game.rerolls, func():
			game.rerolls -= 1
			show_perks(game.roll_perks()), 18)
		rr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(rr)


func show_victory(stars: int, fish: int) -> void:
	get_tree().paused = true
	var v := _open_modal()
	var t := UIKit.label("VICTORY!", 64, GameData.C_GOLD, 0, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_center(UIKit.label("Your cat napped safely through all %d waves." % GameData.WAVES_TO_WIN, 20)))
	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in 3:
		var s := UIKit.icon("star" if i < stars else "star_empty", GameData.C_GOLD, 84)
		row.add_child(s)
		UIKit.pop_in(s, 0.3 + i * 0.35)
		if i < stars:
			get_tree().create_timer(0.3 + i * 0.35).timeout.connect(func(): Sfx.play("coin", 1.0 + i * 0.25, 0.0))
	var reasons := ["Survived!", "Lost 3 lives or fewer", "Kept all nine lives"]
	for i in 3:
		v.add_child(_center(UIKit.label(reasons[i], 16, GameData.C_GREEN if i < stars else Color("6b5d73"))))
	v.add_child(_fish_row(fish))
	var buttons := UIKit.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UIKit.button("Endless Mode", func():
		_close_modal()
		get_tree().paused = false
		game.continue_endless()
		banner("ENDLESS", "How long can your cat hold out?", GameData.C_PURPLE), 20))
	buttons.add_child(UIKit.button("Main Menu", func(): game.quit_to_menu(), 20))
	v.add_child(buttons)


func show_defeat(fish: int) -> void:
	var v := _open_modal()
	var t := UIKit.label("THE DOGS GOT IN!", 54, GameData.C_RED, 0, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var cat := UIKit.icon("cat", GameData.C_ORANGE, 90)
	cat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cat)
	v.add_child(_center(UIKit.label("Your cat made it to wave %d and bonked %d dogs." % [game.wave, game.stats_kills], 20)))
	v.add_child(_fish_row(fish))
	v.add_child(_center(UIKit.label("Spend fish in the Cat Tree to get stronger!", 16, Color("b9adc0"))))
	var buttons := UIKit.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UIKit.button("Try Again", func(): game.restart(), 22))
	buttons.add_child(UIKit.button("Cat Tree", func(): game.quit_to_menu(), 22))
	v.add_child(buttons)


func _fish_row(fish: int) -> HBoxContainer:
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UIKit.icon("fish", GameData.C_BLUE, 40))
	var l := UIKit.label("+0 fish", 30, GameData.C_BLUE, 0, true)
	h.add_child(l)
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float): l.text = "+%d fish" % int(v), 0.0, float(fish), 1.0)
	return h
