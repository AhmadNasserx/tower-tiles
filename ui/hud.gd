extends CanvasLayer
## In-game HUD in the storybook style: wooden plates, parchment cards, chunky
## buttons and 3D portraits. Polls the Game for numbers each frame and reacts
## to its signals for the juicy moments.

const SettingsPanel := preload("res://ui/settings_panel.gd")
const Dial := preload("res://ui/cooldown_dial.gd")

var game: Game

var root: Control
var _lives_label: Label
var _lives_icon: Control
var _gold_label: Label
var _gold_icon: Control
var _wave_label: Label
var _wave_btn: Button
var _preview: HBoxContainer
var _preview_panel: PanelContainer
var _speed_btn: Button
var _build_cards := {}
var _paw_dial: Control
var _zoom_dial: Control
var _sel_panel: PanelContainer
var _sel_portrait: TextureRect
var _sel_title: Label
var _sel_stars: HBoxContainer
var _sel_stats: Label
var _sel_extra: Label
var _sel_upgrade: Button
var _sel_target: Button
var _sel_sell: Button
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: TextureProgressBar
var _banner: VBoxContainer
var _banner_ribbon: PanelContainer
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

	_vignette = _make_vignette(Color("e8484f"))
	_zoom_tint = _make_vignette(Color("a66cff"))
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
	_refresh_cards()
	if not Save.settings.tutorial_done:
		_set_tutorial(0)
	banner(game.map.name, "Keep your cat safe. Don't let the pack reach the tower!", 2.6)


# ------------------------------------------------------------------ layout
func _anchored(c: Control, preset: Control.LayoutPreset, offset := Vector2.ZERO) -> Control:
	root.add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 10)
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


func _stat(icon_kind: String) -> Array:
	var h := UIKit.hbox(6)
	var i := UIKit.icon(icon_kind, Color.WHITE, 36)
	h.add_child(i)
	var l := UIKit.label("0", 28, UIKit.CREAM, 8, true)
	h.add_child(l)
	return [h, l, i]


func _build_top_left() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.wood())
	var row := UIKit.hbox(18)
	panel.add_child(row)
	var lives := _stat("heart")
	row.add_child(lives[0])
	_lives_label = lives[1]
	_lives_icon = lives[2]
	var gold := _stat("coin")
	row.add_child(gold[0])
	_gold_label = gold[1]
	_gold_icon = gold[2]
	_gold_label.custom_minimum_size.x = 64
	_anchored(panel, Control.PRESET_TOP_LEFT)
	_wave_label = UIKit.label("WAVE 0/20", 22, UIKit.CREAM, 8, true)
	_anchored(_wave_label, Control.PRESET_TOP_LEFT, Vector2(14, 66))


func _build_top_center() -> void:
	var box := UIKit.vbox(4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_btn = UIKit.button("START WAVE 1", func(): game.start_wave(), 24, "green", "play")
	_wave_btn.custom_minimum_size = Vector2(270, 56)
	_wave_btn.tooltip_text = "Start the next wave now (Space).\nCalling it early earns bonus gold!"
	_wave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_wave_btn)

	_preview_panel = PanelContainer.new()
	_preview_panel.add_theme_stylebox_override("panel", UIKit.sbox("panel_brown.png", 22, Vector4(16, 8, 16, 10)))
	_preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pv := UIKit.vbox(0)
	_preview_panel.add_child(pv)
	var title := UIKit.label("NEXT UP", 14, UIKit.INK_SOFT, 0, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(title)
	_preview = UIKit.hbox(8)
	_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(_preview)
	box.add_child(_preview_panel)

	_boss_box = UIKit.vbox(0)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon := UIKit.ribbon("BOSS", 26, 400)
	_boss_name = ribbon.get_child(0)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_box.add_child(ribbon)
	_boss_bar = TextureProgressBar.new()
	_boss_bar.texture_under = UIKit.tex("progress_transparent.png")
	_boss_bar.texture_progress = UIKit.tex("progress_red.png")
	_boss_bar.nine_patch_stretch = true
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		_boss_bar.set("stretch_margin_left" if side == SIDE_LEFT else "stretch_margin_right", 14)
	_boss_bar.stretch_margin_top = 14
	_boss_bar.stretch_margin_bottom = 14
	_boss_bar.custom_minimum_size = Vector2(340, 26)
	_boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_box.add_child(_boss_bar)
	box.add_child(_boss_box)

	_toasts = UIKit.vbox(2)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_toasts)

	_anchored(box, Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.resized.connect(func(): box.position.x = (root.size.x - box.size.x) * 0.5)


func _square_button(icon_kind: String, cb: Callable, tip: String) -> Button:
	var b := Button.new()
	UIKit.style_button(b, "yellow", true)
	b.custom_minimum_size = Vector2(58, 58)
	b.icon = UIKit._scaled_icon(icon_kind, 30)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.pressed.connect(cb)
	UIKit.juicy(b, 1.1)
	return b


func _build_top_right() -> void:
	var row := UIKit.hbox(6)
	_speed_btn = Button.new()
	UIKit.style_button(_speed_btn, "yellow", true)
	_speed_btn.custom_minimum_size = Vector2(76, 58)
	_speed_btn.add_theme_font_size_override("font_size", 24)
	_speed_btn.tooltip_text = "Game speed (F)"
	_speed_btn.pressed.connect(func(): game.cycle_speed())
	UIKit.juicy(_speed_btn, 1.1)
	row.add_child(_speed_btn)
	row.add_child(_square_button("pause", toggle_pause, "Pause (Esc)"))
	_anchored(row, Control.PRESET_TOP_RIGHT)


func _build_build_bar() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.wood())
	var row := UIKit.hbox(8)
	panel.add_child(row)
	for type in GameData.TURRET_ORDER:
		var d: Dictionary = GameData.TURRETS[type]
		var b := Button.new()
		b.custom_minimum_size = Vector2(108, 126)
		b.tooltip_text = "%s  [%s]\n%s" % [d.name, d.key, d.desc]
		b.pressed.connect(func(): game.set_build_type(type))
		var v := UIKit.vbox(-4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_top = 4
		v.offset_bottom = -8
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var pic := UIKit.portrait("kitten:" + type, 72)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pic)
		var nm := UIKit.label(d.name, 14, UIKit.INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var cost_row := UIKit.hbox(3)
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_child(UIKit.icon("coin", Color.WHITE, 20))
		var cl := UIKit.label(str(d.cost), 19, UIKit.INK, 0, true)
		cost_row.add_child(cl)
		v.add_child(cost_row)
		var key := UIKit.label(d.key, 15, UIKit.CREAM, 5, true)
		key.position = Vector2(8, 4)
		b.add_child(key)
		UIKit.juicy(b, 1.07)
		row.add_child(b)
		_build_cards[type] = {"button": b, "cost": cl}
	_anchored(panel, Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _ability_button(icon_kind: String, key: String, tip: String, cb: Callable) -> Array:
	var b := Button.new()
	b.custom_minimum_size = Vector2(88, 88)
	b.tooltip_text = tip
	b.pressed.connect(cb)
	var normal := UIKit.sbox("round_brown.png", 0, Vector4(0, 0, 0, 0))
	for k in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(k, normal)
	b.add_theme_stylebox_override("hover", UIKit.sbox("round_brown.png", 0, Vector4(0, 0, 0, 0), Color(1.1, 1.1, 1.1)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := UIKit.icon(icon_kind, Color.WHITE, 50)
	ic.position = Vector2(19, 18)
	b.add_child(ic)
	var dial := Dial.new()
	dial.set_anchors_preset(Control.PRESET_FULL_RECT)
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(dial)
	var k := UIKit.label(key, 18, UIKit.CREAM, 7, true)
	k.position = Vector2(66, 60)
	b.add_child(k)
	UIKit.juicy(b, 1.1)
	return [b, dial]


func _build_abilities() -> void:
	var row := UIKit.hbox(10)
	var paw := _ability_button("paw", "Q", "GIANT PAW  [Q]\nClick the road to squash critters and stun the survivors.", func(): game.begin_paw())
	_paw_dial = paw[1]
	row.add_child(paw[0])
	var zoom := _ability_button("bolt", "E", "ZOOMIES  [E]\nEvery kitten (and your cat) attacks twice as fast for a few seconds.", func(): game.activate_zoomies())
	_zoom_dial = zoom[1]
	row.add_child(zoom[0])
	_anchored(row, Control.PRESET_BOTTOM_LEFT)


func _build_selection_panel() -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.custom_minimum_size = Vector2(290, 0)
	var v := UIKit.vbox(6)
	_sel_panel.add_child(v)
	var head := UIKit.hbox(8)
	v.add_child(head)
	_sel_portrait = TextureRect.new()
	_sel_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sel_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sel_portrait.custom_minimum_size = Vector2(76, 76)
	head.add_child(_sel_portrait)
	var names := UIKit.vbox(0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	_sel_title = UIKit.label("Kitty", 26, UIKit.INK, 0, true)
	names.add_child(_sel_title)
	_sel_stars = UIKit.hbox(2)
	names.add_child(_sel_stars)
	_sel_stats = UIKit.label("", 16, UIKit.INK)
	_sel_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sel_stats.custom_minimum_size.x = 250
	v.add_child(_sel_stats)
	_sel_extra = UIKit.label("", 14, UIKit.INK_SOFT)
	v.add_child(_sel_extra)
	_sel_upgrade = UIKit.button("Upgrade", func(): game.upgrade_selected(), 20, "green", "up")
	v.add_child(_sel_upgrade)
	_sel_target = UIKit.button("Target: First", func(): game.cycle_target_mode(), 17, "grey", "target")
	_sel_target.tooltip_text = "Which critter to attack first (T)"
	v.add_child(_sel_target)
	_sel_sell = UIKit.button("Sell", func(): game.sell_selected(), 17, "red", "sell")
	v.add_child(_sel_sell)
	_anchored(_sel_panel, Control.PRESET_CENTER_RIGHT)
	_sel_panel.visible = false


func _build_banner() -> void:
	_banner = UIKit.vbox(0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_ribbon = UIKit.ribbon("", 46, 520) as PanelContainer
	_banner_ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_title = _banner_ribbon.get_child(0)
	_banner.add_child(_banner_ribbon)
	_banner_sub = UIKit.label("", 22, UIKit.CREAM, 8, true)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	root.add_child(_banner)
	_banner.modulate.a = 0.0


func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint_label = UIKit.label("", 18, UIKit.INK)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size.x = 340
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var h := UIKit.hbox(10)
	h.add_child(UIKit.portrait("hero", 56))
	h.add_child(_hint_label)
	_hint.add_child(h)
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
	_wave_label.text = ("WAVE %d/%d" % [game.wave, GameData.WAVES_TO_WIN]) if not game.endless else ("WAVE %d  ENDLESS" % game.wave)
	_speed_btn.text = "%dx" % int(Game.SPEEDS[game.speed_index])

	var can_start := not game.in_wave and game.playing
	_wave_btn.visible = can_start
	_preview_panel.visible = can_start
	if can_start:
		if game.countdown > 0.0 and game.wave > 0:
			_wave_btn.text = "GO NOW  +%d" % int(game.countdown * 1.5)
			_wave_btn.tooltip_text = "Next wave in %d s. Start it now for bonus gold!" % ceili(game.countdown)
		else:
			_wave_btn.text = "START WAVE %d" % (game.wave + 1)
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.035
		if not _wave_btn.is_hovered():
			_wave_btn.pivot_offset = _wave_btn.size * 0.5
			_wave_btn.scale = Vector2(pulse, pulse)
		if _preview_wave != game.wave:
			_preview_wave = game.wave
			_rebuild_preview()

	var b: Enemy = game.boss
	_boss_box.visible = b != null and is_instance_valid(b) and b.alive
	if _boss_box.visible:
		_boss_name.text = b.def.name.to_upper()
		_boss_bar.max_value = b.max_hp
		_boss_bar.value = b.hp

	_paw_dial.fraction = clampf(game.paw_cd / game.paw_cooldown_total(), 0.0, 1.0)
	_paw_dial.seconds = game.paw_cd
	_paw_dial.active = game.mode == "paw"
	_zoom_dial.fraction = clampf(game.zoomies_cd / game.zoomies_cooldown_total(), 0.0, 1.0)
	_zoom_dial.seconds = game.zoomies_cd
	_zoom_dial.active = game.zoomies_time > 0.0
	_zoom_tint.modulate.a = lerpf(_zoom_tint.modulate.a, 0.3 if game.zoomies_time > 0.0 else 0.0, minf(1.0, delta * 8.0))

	if game.lives <= 3 and game.playing:
		var beat := 1.0 + absf(sin(Time.get_ticks_msec() * 0.006)) * 0.25
		_lives_icon.pivot_offset = _lives_icon.size * 0.5
		_lives_icon.scale = Vector2(beat, beat)

	if _sel_panel.visible and game.selected and is_instance_valid(game.selected):
		_refresh_selection_buttons()
	if _tutorial_step == 0 and game.turrets.size() > 0:
		_set_tutorial(1)
	game.overlay.coin_target = _gold_icon.global_position + _gold_icon.size * 0.5


func _rebuild_preview() -> void:
	for c in _preview.get_children():
		c.queue_free()
	var summary := game.next_wave_preview()
	for type in summary:
		var d: Dictionary = GameData.ENEMIES[type]
		var chip := UIKit.hbox(0)
		chip.tooltip_text = d.name
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(UIKit.portrait("critter:" + type, 46))
		var boss: bool = d.get("boss", false)
		chip.add_child(UIKit.label("x%d" % summary[type], 20, UIKit.RED if boss else UIKit.INK, 0, true))
		_preview.add_child(chip)


func is_mouse_over_ui() -> bool:
	if _modal:
		return true
	return root.get_viewport().gui_get_hovered_control() != null


# ------------------------------------------------------------------ build bar / selection
func _refresh_cards() -> void:
	for type in _build_cards:
		var card: Dictionary = _build_cards[type]
		var cost := game.price(GameData.TURRETS[type].cost)
		var cl: Label = card.cost
		cl.text = str(cost)
		var b: Button = card.button
		var afford := game.gold >= cost
		var selected: bool = game.build_type == type
		cl.label_settings.font_color = UIKit.INK if afford else UIKit.RED
		var normal := UIKit.sbox("sq_yellow.png" if selected else "panel_brown.png", 20 if selected else 22, Vector4(8, 8, 8, 8))
		if not afford and not selected:
			normal.modulate_color = Color(0.8, 0.74, 0.7)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", UIKit.sbox("sq_yellow.png", 20, Vector4(8, 8, 8, 8), Color(1.05, 1.05, 1.05)))
		b.add_theme_stylebox_override("pressed", UIKit.sbox("sq_yellow_pressed.png", 20, Vector4(8, 8, 8, 8)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
			tw.tween_callback(func(): _sel_panel.visible = game.selected != null)
		return
	var was_hidden := not _sel_panel.visible
	_sel_panel.visible = true
	_sel_panel.modulate.a = 1.0
	Portraits.fill(_sel_portrait, "kitten:" + t.type)
	_sel_title.text = t.def.name
	for c in _sel_stars.get_children():
		c.queue_free()
	for i in Turret.MAX_LEVEL + 1:
		_sel_stars.add_child(UIKit.icon("star" if i <= t.level else "star_empty", Color.WHITE, 24))
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


## Big hanging-ribbon banner. Old callers pass a colour third; it's ignored now
## that the ribbon sets the style.
func banner(title: String, sub: String, hold_or_color: Variant = 1.6, hold := -1.0) -> void:
	var h: float = hold if hold > 0.0 else (hold_or_color if hold_or_color is float else 1.6)
	_banner_title.text = title.to_upper()
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	if _banner_tween:
		_banner_tween.kill()
	_banner.reset_size()
	_banner.position = Vector2((root.size.x - _banner.size.x) * 0.5, root.size.y * 0.24 - _banner.size.y * 0.5)
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, 0)
	_banner.scale = Vector2(1.0, 0.0)
	_banner.modulate.a = 1.0
	_banner_tween = create_tween().set_ignore_time_scale(true)
	# the ribbon drops down and swings into place
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(h)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.35)
	_banner_tween.parallel().tween_property(_banner, "position:y", _banner.position.y - 30.0, 0.35)


func toast(text: String, color := UIKit.CREAM) -> void:
	var l := UIKit.label(text, 22, color, 8, true)
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
			_show_hint("Pick a kitten below (or press 1-5), then click a grass tile next to the road.", Control.PRESET_CENTER_BOTTOM, Vector2(0, -160))
		1:
			_show_hint("Purrfect! Press START WAVE when you're ready. The pack follows the road to my tower!", Control.PRESET_CENTER_TOP, Vector2(0, 160))
		2:
			_show_hint("Click a kitten to upgrade it. Q = Giant Paw, E = Zoomies.\nRight-drag or WASD to look around.", Control.PRESET_CENTER_BOTTOM, Vector2(0, -160))
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
func _open_modal(title := "", width := 0.0) -> VBoxContainer:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_modal)
	UIKit.dim(_modal, 0.5)
	var cc := UIKit.center_container(_modal)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer := UIKit.vbox(-18)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(outer)
	if title != "":
		var rb := UIKit.ribbon(title, 40, maxf(width * 0.8, 380))
		rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rb.z_index = 1
		outer.add_child(rb)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.sbox("panel_brown.png", 22, Vector4(30, 34, 30, 26)))
	panel.custom_minimum_size.x = width
	outer.add_child(panel)
	var v := UIKit.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	UIKit.pop_in(outer)
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
	var v := _open_modal("PAWS-ED", 360)
	_modal.set_meta("pause", true)
	v.add_child(_center(UIKit.label("Lives lost: %d     Critters bonked: %d" % [game.lives_lost, game.stats_kills], 17, UIKit.INK_SOFT)))
	for entry in [["Resume", func(): toggle_pause(), "green", "play"],
			["Settings", func(): _show_settings(), "yellow", "gear"],
			["Restart", func(): game.restart(), "yellow", ""],
			["Main Menu", func(): game.quit_to_menu(), "red", ""]]:
		var b := UIKit.button(entry[0], entry[1], 22, entry[2], entry[3])
		b.custom_minimum_size = Vector2(270, 58)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	var keys := UIKit.label("1-5 build · Q paw · E zoomies · Space wave · F speed\nU upgrade · X sell · T target · right-drag pan · wheel zoom", 14, UIKit.INK_SOFT)
	v.add_child(_center(keys))


func _show_settings() -> void:
	var v := _open_modal("SETTINGS", 420)
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
	var v := _open_modal("CHOOSE A PURR-K", 760)
	v.add_child(_center(UIKit.label("Your cat found something shiny after wave %d!" % game.wave, 18, UIKit.INK_SOFT)))
	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	Sfx.play("perk")
	var i := 0
	for id in options:
		var d: Dictionary = GameData.PERKS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 250)
		b.add_theme_stylebox_override("normal", UIKit.sbox("sq_grey.png", 20, Vector4(8, 8, 8, 8), Color(1.08, 1.06, 1.0)))
		b.add_theme_stylebox_override("hover", UIKit.sbox("sq_yellow.png", 20, Vector4(8, 8, 8, 8)))
		b.add_theme_stylebox_override("pressed", UIKit.sbox("sq_yellow_pressed.png", 20, Vector4(8, 8, 8, 8)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var cv := UIKit.vbox(8)
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.offset_left = 14
		cv.offset_right = -14
		cv.offset_top = 16
		cv.offset_bottom = -20
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cv)
		var ic := UIKit.icon(d.icon, Color.WHITE, 76)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var nm := UIKit.label(d.name, 23, UIKit.INK, 0, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(nm)
		var ds := UIKit.label(d.desc, 16, UIKit.INK_SOFT)
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(ds)
		var stack := game.perk(id)
		if stack > 0:
			cv.add_child(_center(UIKit.label("Level %d → %d" % [stack, stack + 1], 15, UIKit.GREEN, 0, true)))
		b.pressed.connect(func():
			_close_modal()
			get_tree().paused = false
			game.take_perk(id)
			banner(d.name, d.desc, 1.2))
		UIKit.juicy(b, 1.05)
		row.add_child(b)
		UIKit.pop_in(b, 0.1 + i * 0.08)
		i += 1
	if game.rerolls > 0:
		var rr := UIKit.button("Reroll (%d left)" % game.rerolls, func():
			game.rerolls -= 1
			show_perks(game.roll_perks()), 18, "blue")
		rr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(rr)


func show_victory(stars: int, fish: int) -> void:
	get_tree().paused = true
	var v := _open_modal("VICTORY!", 480)
	var hero := UIKit.portrait("hero", 110)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(hero)
	v.add_child(_center(UIKit.label("Your cat napped safely through all %d waves." % GameData.WAVES_TO_WIN, 19)))
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in 3:
		var s := UIKit.icon("star" if i < stars else "star_empty", Color.WHITE, 80)
		row.add_child(s)
		UIKit.pop_in(s, 0.3 + i * 0.35)
		if i < stars:
			get_tree().create_timer(0.3 + i * 0.35).timeout.connect(func(): Sfx.play("coin", 1.0 + i * 0.25, 0.0))
	var reasons := ["Survived all waves", "Lost 3 lives or fewer", "Kept all nine lives"]
	for i in 3:
		var line := UIKit.hbox(6)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(UIKit.icon("check" if i < stars else "cross", Color.WHITE, 20))
		line.add_child(UIKit.label(reasons[i], 16, UIKit.INK if i < stars else UIKit.INK_SOFT))
		v.add_child(line)
	v.add_child(_fish_row(fish))
	var buttons := UIKit.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UIKit.button("Endless Mode", func():
		_close_modal()
		get_tree().paused = false
		game.continue_endless()
		banner("Endless", "How long can your cat hold out?", 1.6), 20, "blue"))
	buttons.add_child(UIKit.button("Main Menu", func(): game.quit_to_menu(), 20, "yellow"))
	v.add_child(buttons)


func show_defeat(fish: int) -> void:
	var v := _open_modal("THE PACK GOT IN!", 480)
	var hero := UIKit.portrait("hero", 110)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(hero)
	v.add_child(_center(UIKit.label("Your cat held out until wave %d and bonked %d critters." % [game.wave, game.stats_kills], 19)))
	v.add_child(_fish_row(fish))
	v.add_child(_center(UIKit.label("Spend fish in the Cat Tree to grow stronger!", 16, UIKit.INK_SOFT)))
	var buttons := UIKit.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UIKit.button("Try Again", func(): game.restart(), 22, "green"))
	buttons.add_child(UIKit.button("Cat Tree", func(): game.quit_to_menu(), 22, "yellow"))
	v.add_child(buttons)


func _fish_row(fish: int) -> HBoxContainer:
	var h := UIKit.hbox(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(UIKit.icon("fish", Color.WHITE, 44))
	var l := UIKit.label("+0 fish", 32, Color("2f7fc1"), 0, true)
	h.add_child(l)
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(0.5)
	tw.tween_method(func(val: float): l.text = "+%d fish" % int(val), 0.0, float(fish), 1.0)
	return h
