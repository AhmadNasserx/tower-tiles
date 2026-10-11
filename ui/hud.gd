extends CanvasLayer
## In-game HUD in the storybook style: wooden plates, parchment cards, chunky
## buttons and 3D portraits. Polls the Game for numbers each frame and reacts
## to its signals for the juicy moments.

const SettingsPanel := preload("res://ui/settings_panel.gd")
const Dial := preload("res://ui/cooldown_dial.gd")
const SEL_MARGIN := 16.0 # gap between the selection panel and the right edge
const SEL_SLIDE := 340.0 # how far off-screen the selection panel starts its slide-in
## Touch scale caps per widget. The touch scale itself follows the real window size (see
## UIKit.touch_scale); these stop the big pieces from crowding the screen on small phones.
const CARD_MAX_K := 1.35 # kitten cards (the bar sits at the bottom, so they cost height)
const SEL_MAX_K := 1.45 # selection panel text and portraits
const SEL_TOUCH_W := 460.0 # selection panel width on touch (desktop keeps 290)

## Emitted when the first screen touch turns the touch layout on (see _input).
signal touch_mode_changed

var game: Game

var root: Control
var _build_panel: PanelContainer # the card bar at the bottom centre
var _bottom_column: VBoxContainer # the Cancel row (touch, in build mode) above the card bar
var _cancel_row: HBoxContainer # the touch-only "Cancel" button, above the card bar
var _cancel_btn: Button
var _square_btns: Array[Button] = [] # square icon buttons, sized for touch
var _fs_btn: Button
var _fs_glyph: Control
var _pause_fs_btn: Button # the pause menu's full screen entry, while it is open
var _abilities: Array = [] # {button, icon, key} per ability button
var _sel_grid: GridContainer # Upgrade, Target, Move, Sell: one column on desktop, two on touch
var _lives_label: Label
var _lives_icon: Control
var _gold_label: Label
var _gold_icon: Control
var _wave_label: Label
var _top_box: VBoxContainer # the start-wave button, preview chips and toasts, top centre
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
var _sel_move: Button
var _sel_sell: Button
var _sel_tw: Tween # the selection panel's slide-in or fade-out
var _boss_box: PanelContainer
var _boss_style: StyleBoxFlat
var _boss_name: Label
var _boss_bar: TextureProgressBar
var _boss_hp_label: Label
var _banner: VBoxContainer
var _banner_ribbon: PanelContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _boss_card: Control
var _card_active := false # true while the boss title card is on screen
var _gameplay: Control # every gameplay widget lives under this, so a cinematic can fade them together
var _gameplay_tw: Tween
var _cinematic := false
var _toasts: VBoxContainer
var _vignette: TextureRect
var _zoom_tint: TextureRect
var _modal: Control
var _hint: PanelContainer
var _hint_label: Label
var _hint_preset := Control.PRESET_CENTER_BOTTOM
var _hint_offset: Callable # the hint's lift from its preset, read again on every placement
var _hint_shift_seen := 0.0 # the sideways shift the hint was last placed with
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
	# added after the vignettes so the widgets draw over them, as before
	_gameplay = Control.new()
	_gameplay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_gameplay)
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_build_bar()
	_build_abilities()
	_build_selection_panel()
	_build_banner()
	_build_hint()
	_apply_touch()
	touch_mode_changed.connect(_apply_touch)
	# a rotation or window resize changes the real px per logical px, so the sizes follow.
	# Deferred, so it runs after the stretch has updated the viewport.
	get_viewport().size_changed.connect(_apply_touch, CONNECT_DEFERRED)
	UIKit.make_rotate_overlay(self)

	game.gold_changed.connect(func(_g): _refresh_cards())
	game.lives_changed.connect(_on_lives_changed)
	game.selection_changed.connect(_on_selection_changed)
	game.selection_changed.connect(func(_t): _refresh_cancel())
	game.build_mode_changed.connect(func(_t):
		_refresh_cards()
		_refresh_cancel())
	game.wave_changed.connect(_on_wave_changed)
	_refresh_cards()
	if not Save.settings.tutorial_done:
		_set_tutorial(0)
	banner(game.map.name, "Keep your cat safe. Don't let the pack reach the tower!", 2.6)


## The first screen touch on a device the probe missed turns the touch layout on.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed and not UIKit.is_touch():
		UIKit.touch_seen = true
		touch_mode_changed.emit()


# ------------------------------------------------------------------ layout
func _anchored(c: Control, preset: Control.LayoutPreset, offset := Vector2.ZERO) -> Control:
	_gameplay.add_child(c)
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 10)
	c.position += offset
	# on the bottom or right edge, grow back towards the middle when the minimum size
	# changes (touch sizes), so the control never runs off the screen
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_RIGHT]:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT]:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	# the stats plate and the wave counter share a column, so the counter moves down with the plate
	var plate := UIKit.vbox(4)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(panel)
	_wave_label = UIKit.label("WAVE 0/20", 22, UIKit.CREAM, 8, true)
	var wave_row := MarginContainer.new()
	wave_row.add_theme_constant_override("margin_left", 14)
	wave_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_row.add_child(_wave_label)
	plate.add_child(wave_row)
	_anchored(plate, Control.PRESET_TOP_LEFT)


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

	# dark backing card; its shadow is the red glow that pulses when the boss is nearly dead
	_boss_style = StyleBoxFlat.new()
	_boss_style.bg_color = Color(0.17, 0.1, 0.06, 0.9)
	_boss_style.set_corner_radius_all(16)
	_boss_style.set_border_width_all(3)
	_boss_style.border_color = Color("2b1a10")
	_boss_style.content_margin_left = 18.0
	_boss_style.content_margin_right = 18.0
	_boss_style.content_margin_top = 10.0
	_boss_style.content_margin_bottom = 12.0
	_boss_style.shadow_size = 22
	_boss_style.shadow_offset = Vector2.ZERO
	_boss_style.shadow_color = Color(UIKit.RED, 0.0)
	_boss_box = PanelContainer.new()
	_boss_box.add_theme_stylebox_override("panel", _boss_style)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := UIKit.vbox(4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(inner)
	var ribbon := UIKit.ribbon("BOSS", 26, 400)
	_boss_name = ribbon.get_child(0)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(ribbon)
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
	inner.add_child(_boss_bar)
	# "cur / max" readout sits on the bar itself
	_boss_hp_label = UIKit.label("", 16, UIKit.CREAM, 6, true)
	_boss_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_hp_label)
	box.add_child(_boss_box)

	_toasts = UIKit.vbox(2)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_toasts)

	_top_box = box
	_anchored(box, Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.resized.connect(func(): box.position.x = (root.size.x - box.size.x) * 0.5)


func _square_button(icon_kind: String, cb: Callable, tip: String) -> Button:
	var b := Button.new()
	UIKit.style_button(b, "yellow", true)
	b.custom_minimum_size = Vector2(58, 58)
	b.icon = UIKit._scaled_icon(icon_kind, 30)
	b.set_meta("icon_kind", icon_kind) # _apply_touch redraws the icon at the touch size
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.pressed.connect(cb)
	UIKit.juicy(b, 1.1)
	_square_btns.append(b)
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
	_fs_btn = _fullscreen_button()
	row.add_child(_fs_btn)
	_anchored(row, Control.PRESET_TOP_RIGHT)


## Square full screen toggle. The brackets turn inwards while the window is full screen.
func _fullscreen_button() -> Button:
	var b := Button.new()
	UIKit.style_button(b, "yellow", true)
	b.custom_minimum_size = Vector2(58, 58)
	b.tooltip_text = "Full screen"
	b.pressed.connect(_toggle_fullscreen)
	UIKit.juicy(b, 1.1)
	_fs_glyph = UIKit.fullscreen_glyph(_is_fullscreen)
	b.add_child(_fs_glyph)
	_square_btns.append(b)
	return b


func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Switches between full screen and a window. Works from a tap on the web build.
func _toggle_fullscreen() -> void:
	var to_full := not _is_fullscreen()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if to_full else DisplayServer.WINDOW_MODE_WINDOWED)
	_fs_glyph.queue_redraw()
	_fs_btn.tooltip_text = _fs_text(to_full)
	if is_instance_valid(_pause_fs_btn):
		_pause_fs_btn.text = _fs_text(to_full)
	Sfx.play("click")


func _fs_text(full: bool) -> String:
	return "Exit full screen" if full else "Full screen"


func _build_build_bar() -> void:
	_build_panel = PanelContainer.new()
	_build_panel.add_theme_stylebox_override("panel", UIKit.wood())
	var row := UIKit.hbox(8)
	_build_panel.add_child(row)
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
		var coin := UIKit.icon("coin", Color.WHITE, 20)
		cost_row.add_child(coin)
		var cl := UIKit.label(str(d.cost), 19, UIKit.INK, 0, true)
		cost_row.add_child(cl)
		v.add_child(cost_row)
		var key := UIKit.label(d.key, 15, UIKit.CREAM, 5, true)
		key.position = Vector2(8, 4)
		b.add_child(key)
		UIKit.juicy(b, 1.07)
		row.add_child(b)
		_build_cards[type] = {"button": b, "cost": cl, "pic": pic, "name": nm, "key": key, "coin": coin}
	# the touch-only cancel sits in a column above the card bar, which stays put
	_cancel_btn = UIKit.button("Cancel", func(): game._cancel(), 20, "red", "cross")
	_cancel_btn.tooltip_text = "Leave build, paw or move mode (Esc)"
	_cancel_row = UIKit.hbox(0)
	_cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cancel_row.add_child(_cancel_btn)
	_cancel_row.visible = false
	var column := UIKit.vbox(8)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_cancel_row)
	column.add_child(_build_panel)
	_bottom_column = column
	_anchored(column, Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH


## Returns [button, dial, icon, key label]. The key badge is hidden on touch.
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
	return [b, dial, ic, k]


func _build_abilities() -> void:
	var row := UIKit.hbox(10)
	var paw := _ability_button("paw", "Q", "GIANT PAW  [Q]\nClick the road to squash critters and stun the survivors.", func(): game.begin_paw())
	_paw_dial = paw[1]
	_abilities.append({"button": paw[0], "icon": paw[2], "key": paw[3]})
	row.add_child(paw[0])
	var zoom := _ability_button("bolt", "E", "ZOOMIES  [E]\nEvery kitten (and your cat) attacks twice as fast for a few seconds.", func(): game.activate_zoomies())
	_zoom_dial = zoom[1]
	_abilities.append({"button": zoom[0], "icon": zoom[2], "key": zoom[3]})
	row.add_child(zoom[0])
	_anchored(row, Control.PRESET_BOTTOM_LEFT)


func _build_selection_panel() -> void:
	_sel_panel = PanelContainer.new()
	_sel_panel.custom_minimum_size = Vector2(290, 0)
	var v := UIKit.vbox(4)
	_sel_panel.add_child(v)
	var head := UIKit.hbox(8)
	v.add_child(head)
	_sel_portrait = TextureRect.new()
	_sel_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sel_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sel_portrait.custom_minimum_size = Vector2(64, 64)
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
	# one column on desktop (as a stack); two columns on touch, so the panel stays short
	_sel_grid = GridContainer.new()
	_sel_grid.columns = 1
	_sel_grid.add_theme_constant_override("h_separation", 6)
	_sel_grid.add_theme_constant_override("v_separation", 4)
	v.add_child(_sel_grid)
	_sel_upgrade = UIKit.button("Upgrade", func(): game.upgrade_selected(), 20, "green", "up")
	_sel_grid.add_child(_sel_upgrade)
	_sel_target = UIKit.button("Target: First", func(): game.cycle_target_mode(), 17, "grey", "target")
	_sel_target.tooltip_text = "Which critter to attack first (T)"
	_sel_grid.add_child(_sel_target)
	_sel_move = UIKit.button("Move  [M]", func(): game.begin_move(), 17, "blue")
	_sel_grid.add_child(_sel_move)
	_sel_sell = UIKit.button("Sell", func(): game.sell_selected(), 17, "red", "sell")
	_sel_grid.add_child(_sel_sell)
	_gameplay.add_child(_sel_panel)
	_place_selection()
	_sel_panel.visible = false


## Desktop: at the right edge, centred vertically. It grows leftwards when its content is
## wider than the minimum, so the right edge never leaves the screen. Touch: it stands
## on the card bar, so the tall panel never covers the cards. The slide-in moves only
## the horizontal offsets, and they return to exactly this layout at rest.
func _place_selection() -> void:
	if UIKit.is_touch():
		_sel_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		var lift := -(_build_panel.get_combined_minimum_size().y + 24.0)
		_sel_panel.offset_top = lift
		_sel_panel.offset_bottom = lift
		_sel_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		_sel_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_sel_panel.offset_top = 0.0
		_sel_panel.offset_bottom = 0.0
		_sel_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# the preset derives offsets from the current rect, so all four are set explicitly
	_sel_panel.offset_left = -SEL_MARGIN
	_sel_panel.offset_right = -SEL_MARGIN
	_sel_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN


# ------------------------------------------------------------------ touch
## Sizes and wording that depend on touch. Runs once the HUD is built, and again when
## the first touch turns the touch layout on. Desktop gets back the sizes it always had.
func _apply_touch() -> void:
	var k := UIKit.touch_scale() # touch targets and labels; 1.0 on desktop
	var ck := _card_k() # kitten cards and preview chips
	var sk := _text_k() # selection panel, hint and wave counter
	var touch := UIKit.is_touch()
	# top left: the stats plate and the wave counter
	_lives_icon.custom_minimum_size = Vector2(36, 36) * k
	_gold_icon.custom_minimum_size = Vector2(36, 36) * k
	_lives_label.label_settings.font_size = roundi(28 * k)
	_gold_label.label_settings.font_size = roundi(28 * k)
	_gold_label.custom_minimum_size.x = 64.0 * k
	_wave_label.label_settings.font_size = roundi(22 * sk)
	# top right: speed and square buttons, with the icons drawn at the same size
	_speed_btn.custom_minimum_size = Vector2(76, 58) * k
	_speed_btn.add_theme_font_size_override("font_size", roundi(24 * k))
	for b in _square_btns:
		b.custom_minimum_size = Vector2(58, 58) * k
		if b.has_meta("icon_kind"):
			b.icon = UIKit._scaled_icon(b.get_meta("icon_kind"), roundi(30 * k))
	# top centre and bottom centre
	_wave_btn.custom_minimum_size = Vector2(270, 56) * k
	_wave_btn.add_theme_font_size_override("font_size", roundi(24 * k))
	_cancel_btn.custom_minimum_size = Vector2(180, 56) * k
	_cancel_btn.add_theme_font_size_override("font_size", roundi(20 * k))
	for type in _build_cards:
		var card: Dictionary = _build_cards[type]
		card.button.custom_minimum_size = Vector2(108, 126) * ck
		card.pic.custom_minimum_size = Vector2(72, 72) * ck
		card.name.label_settings.font_size = roundi((16 if touch else 14) * ck)
		card.cost.label_settings.font_size = roundi(19 * ck)
		card.coin.custom_minimum_size = Vector2(20, 20) * ck
		card.key.visible = not touch
	for ab in _abilities:
		var px := Vector2(88, 88) * k
		ab.button.custom_minimum_size = px
		var icon_px := 50.0 * k
		ab.icon.custom_minimum_size = Vector2(icon_px, icon_px)
		ab.icon.position = (px - Vector2(icon_px, icon_px)) * 0.5
		ab.key.visible = not touch
	# selection panel: a wide panel with tap-sized buttons, two to a row on touch
	if touch:
		_sel_panel.custom_minimum_size = Vector2(SEL_TOUCH_W, 0)
		_sel_panel.add_theme_stylebox_override("panel", UIKit.sbox("panel_brown.png", 22, Vector4(16, 12, 16, 12)))
	else:
		_sel_panel.custom_minimum_size = Vector2(290, 0)
		_sel_panel.remove_theme_stylebox_override("panel")
	_sel_grid.columns = 2 if touch else 1
	_sel_title.label_settings.font_size = roundi(26 * sk)
	_sel_portrait.custom_minimum_size = Vector2(64, 64) * sk
	for c in _sel_stars.get_children():
		c.custom_minimum_size = Vector2(24, 24) * sk
	_sel_stats.label_settings.font_size = roundi(16 * sk)
	_sel_stats.custom_minimum_size.x = SEL_TOUCH_W - 40.0 if touch else 250.0
	_sel_extra.label_settings.font_size = roundi((16 if touch else 14) * sk)
	for b in [_sel_upgrade, _sel_target, _sel_move, _sel_sell]:
		b.custom_minimum_size.y = UIKit.tap_min(0.0, 56.0 * k)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if touch else Control.SIZE_FILL
	_sel_upgrade.add_theme_font_size_override("font_size", roundi(20 * sk))
	for b in [_sel_target, _sel_move, _sel_sell]:
		b.add_theme_font_size_override("font_size", roundi(17 * sk))
	_place_selection()
	if game.selected and is_instance_valid(game.selected):
		_sel_target.text = _target_label(game.selected)
		_refresh_selection_buttons()
	# the tutorial hint and the preview chips are placed or sized from the same scale
	_hint_label.label_settings.font_size = roundi(18 * sk)
	_hint_label.custom_minimum_size.x = 340.0 * sk
	_preview_wave = -1 # the chips are rebuilt at the new size on the next frame
	_refresh_cards()
	_refresh_cancel()
	_place_hint()


## Scale for the kitten cards and preview chips: the touch scale, capped at CARD_MAX_K.
func _card_k() -> float:
	return minf(UIKit.touch_scale(), CARD_MAX_K)


## Scale for panel text, the hint and the modal buttons: the touch scale, capped at SEL_MAX_K.
func _text_k() -> float:
	return minf(UIKit.touch_scale(), SEL_MAX_K)


## The touch-only Cancel shows while a card, the paw or a move is waiting for a tap.
## Esc and right-click do the same job on desktop.
func _refresh_cancel() -> void:
	var on := UIKit.is_touch() and game.mode in ["build", "paw", "move"]
	if on == _cancel_row.visible:
		return
	_cancel_row.visible = on
	_place_hint() # the bottom hint sits above the Cancel row too


## Lift of the bottom-centre tutorial hints, clear of the card bar.
func _bottom_lift() -> float:
	return -(_bottom_column.get_combined_minimum_size().y + 24.0) if UIKit.is_touch() else -160.0


func _target_label(t: Turret) -> String:
	return "Target: %s%s" % [GameData.TARGET_MODES[t.target_mode], UIKit.hint("  [T]", "")]


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
	_gameplay.add_child(_hint)


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
	_refresh_cancel() # the paw mode does not emit build_mode_changed, so it is polled

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
	# the title card already names the boss, so the small bar waits until it has finished
	_boss_box.visible = not _card_active and b != null and is_instance_valid(b) and b.alive
	if _boss_box.visible:
		UIKit.ribbon_set_text(_boss_name, b.def.name.to_upper())
		_update_boss_bar(b)

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
	# the selection panel opening or closing moves the hint sideways (see _hint_shift)
	if _hint.visible and _hint_shift() != _hint_shift_seen:
		_place_hint()
	if _tutorial_step == 0 and game.turrets.size() > 0:
		_set_tutorial(1)
	game.overlay.coin_target = _gold_icon.global_position + _gold_icon.size * 0.5


## Keeps the boss bar, its "cur / max" readout and the glow in step with the boss.
## Under a quarter health the card pulses red so the turning point is obvious.
func _update_boss_bar(b: Enemy) -> void:
	_boss_bar.max_value = b.max_hp
	_boss_bar.value = b.hp
	_boss_hp_label.text = "%d / %d" % [ceili(b.hp), ceili(b.max_hp)]
	if b.hp < b.max_hp * 0.25:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		_boss_style.shadow_color = Color(UIKit.RED, 0.2 + 0.5 * pulse)
		_boss_bar.modulate = Color.WHITE.lerp(Color(1.0, 0.5, 0.5), pulse)
	elif _boss_style.shadow_color.a > 0.0:
		_boss_style.shadow_color = Color(UIKit.RED, 0.0)
		_boss_bar.modulate = Color.WHITE


func _rebuild_preview() -> void:
	for c in _preview.get_children():
		c.queue_free()
	var summary := game.next_wave_preview()
	for type in summary:
		var d: Dictionary = GameData.ENEMIES[type]
		var chip := UIKit.hbox(0)
		chip.tooltip_text = d.name
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(UIKit.portrait("critter:" + type, 46.0 * _card_k()))
		var boss: bool = d.get("boss", false)
		chip.add_child(UIKit.label("x%d" % summary[type], roundi(20 * _card_k()), UIKit.RED if boss else UIKit.INK, 0, true))
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
		# the active card is yellow; a card the gold can't cover is dimmed (also on hover)
		var lit := afford or selected
		var dim := Color.WHITE if lit else Color(0.8, 0.74, 0.7)
		var normal := UIKit.sbox("sq_yellow.png" if selected else "panel_brown.png", 20 if selected else 22, Vector4(8, 8, 8, 8), dim)
		b.add_theme_stylebox_override("normal", normal)
		var hover_face := "sq_yellow.png" if lit else "panel_brown.png"
		b.add_theme_stylebox_override("hover", UIKit.sbox(hover_face, 20 if lit else 22, Vector4(8, 8, 8, 8), Color(1.05, 1.05, 1.05) * dim))
		b.add_theme_stylebox_override("pressed", UIKit.sbox("sq_yellow_pressed.png", 20, Vector4(8, 8, 8, 8)))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if selected:
			b.pivot_offset = b.size * 0.5
			b.scale = Vector2(1.08, 1.08)
		elif not b.is_hovered():
			b.scale = Vector2.ONE
	if game.selected:
		_refresh_selection_buttons()


func _on_selection_changed(t: Turret) -> void:
	if _sel_tw and _sel_tw.is_valid():
		_sel_tw.kill()
	if t == null:
		if _sel_panel.visible:
			_sel_tw = create_tween().set_ignore_time_scale(true)
			_sel_tw.tween_property(_sel_panel, "modulate:a", 0.0, 0.12)
			_sel_tw.tween_callback(func(): _sel_panel.visible = game.selected != null)
		return
	var was_hidden := not _sel_panel.visible
	_sel_panel.visible = true
	_sel_panel.modulate.a = 1.0
	Portraits.fill(_sel_portrait, "kitten:" + t.type)
	_sel_title.text = t.def.name
	for c in _sel_stars.get_children():
		c.queue_free()
	for i in Turret.MAX_LEVEL + 1:
		_sel_stars.add_child(UIKit.icon("star" if i <= t.level else "star_empty", Color.WHITE, 24.0 * _text_k()))
	_sel_stats.text = t.describe_stats()
	if t.def.kind == "income":
		_sel_extra.text = "Snoozing. Pays out when a wave ends."
	else:
		_sel_extra.text = "Bonks: %d    Damage: %d" % [t.kills, int(t.damage_done)]
	_sel_target.visible = not (t.def.kind in ["income", "pulse"])
	_sel_target.text = _target_label(t)
	_refresh_selection_buttons()
	if was_hidden:
		_slide_in_selection()


## Slides the panel in from the right by moving its offsets, then lands it on the
## anchored layout. Nothing is left modified once the tween has finished.
func _slide_in_selection() -> void:
	if _sel_tw and _sel_tw.is_valid():
		_sel_tw.kill()
	_sel_panel.offset_left = -SEL_MARGIN + SEL_SLIDE
	_sel_panel.offset_right = -SEL_MARGIN + SEL_SLIDE
	_sel_tw = create_tween().set_ignore_time_scale(true).set_parallel()
	_sel_tw.tween_property(_sel_panel, "offset_left", -SEL_MARGIN, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sel_tw.tween_property(_sel_panel, "offset_right", -SEL_MARGIN, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_selection_buttons() -> void:
	var t: Turret = game.selected
	if t == null or not is_instance_valid(t):
		return
	if t.is_max():
		_sel_upgrade.text = "MAX LEVEL"
		_sel_upgrade.disabled = true
	else:
		var cost := t.upgrade_cost()
		_sel_upgrade.text = "Upgrade  %d%s" % [cost, UIKit.hint("  [U]", "")]
		_sel_upgrade.disabled = game.gold < cost
	# moving is free, but only between waves
	_sel_move.text = ("Cancel Move" if game.mode == "move" else "Move") + UIKit.hint("  [M]", "")
	_sel_move.disabled = game.in_wave or not game.playing
	if _sel_move.disabled:
		_sel_move.tooltip_text = "Kittens can only be moved between waves"
	else:
		_sel_move.tooltip_text = "Pick this kitten up and set it down on another tile (M). Free."
	_sel_sell.text = "Sell  +%d%s" % [t.sell_value(), UIKit.hint("  [X]", "")]
	if t.def.kind != "income":
		_sel_extra.text = "Bonks: %d    Damage: %d" % [t.kills, int(t.damage_done)]


# ------------------------------------------------------------------ reactions
func _on_lives_changed(lives: int, max_lives: int) -> void:
	_lives_label.text = "%d/%d" % [lives, max_lives]
	if _last_lives >= 0 and lives != _last_lives:
		if lives < _last_lives:
			_punch(_lives_icon, 1.6)
			_punch(_lives_label, 1.4)
		else:
			_punch(_lives_label, 1.25)
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
	UIKit.ribbon_set_text(_banner_title, title.to_upper())
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


## Fades the gameplay widgets (chips, build bar, abilities, buttons, hint) out for a
## cinematic, and back in afterwards. The title card, banner, modals and the damage
## and zoom vignettes sit outside that container and are not touched. Hidden widgets
## are also made invisible, so they take no clicks until the fade back in.
func set_cinematic(on: bool) -> void:
	if on == _cinematic:
		return
	_cinematic = on
	if _gameplay_tw and _gameplay_tw.is_valid():
		_gameplay_tw.kill()
	_gameplay_tw = create_tween().set_ignore_time_scale(true)
	if on:
		_gameplay_tw.tween_property(_gameplay, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_gameplay_tw.tween_callback(func(): _gameplay.visible = false)
	else:
		_gameplay.visible = true
		_gameplay_tw.tween_property(_gameplay, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Boss entrance card: letterbox bars slide in, the boss name bounces in large
## in UIKit red, a blurb fades in beneath, then everything fades after ~2s.
## Replaces any card still showing. Mouse input passes straight through.
func boss_title_card(boss_name: String, subtitle: String) -> void:
	if is_instance_valid(_boss_card):
		_boss_card.queue_free()
	# the card takes the centre of the screen, so the ordinary banner steps aside
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0

	var vp := root.size
	var bar_h := clampf(vp.y * 0.14, 56.0, 120.0)
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	_boss_card = card
	_card_active = true

	# [resting y, off-screen starting y] for the top and bottom bars
	for bar in [[0.0, -bar_h], [vp.y - bar_h, vp.y]]:
		var r := ColorRect.new()
		r.color = Color(UIKit.OUTLINE, 0.92)
		r.size = Vector2(vp.x, bar_h)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(r)
		r.position = Vector2(0, bar[1])
		r.create_tween().set_ignore_time_scale(true).tween_property(r, "position:y", bar[0], 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var title := UIKit.label(boss_name.to_upper(), 64, UIKit.RED, 10, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size = Vector2(vp.x, 80.0)
	title.pivot_offset = title.size * 0.5
	card.add_child(title)
	# sits low, under the face the camera frames in the upper-middle of the screen
	var rest := Vector2(0, vp.y * 0.65 - 40.0)
	title.position = rest + Vector2(vp.x * 0.2, 0)
	title.scale = Vector2.ONE * 1.5
	title.modulate.a = 0.0
	var tt := title.create_tween().set_ignore_time_scale(true)
	tt.tween_interval(0.15)
	tt.tween_property(title, "modulate:a", 1.0, 0.12)
	tt.parallel().tween_property(title, "position", rest, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.parallel().tween_property(title, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var sub := UIKit.label(subtitle, 26, UIKit.CREAM, 8, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.size = Vector2(vp.x, 40.0)
	sub.position = rest + Vector2(0, 86.0)
	sub.modulate.a = 0.0
	card.add_child(sub)
	var st := sub.create_tween().set_ignore_time_scale(true)
	st.tween_interval(0.5)
	st.tween_property(sub, "modulate:a", 1.0, 0.3)

	# hold, then fade the whole card; freeing it takes its tweens along
	var tw := card.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(2.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func():
		_card_active = false
		card.queue_free())


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
			_show_hint(UIKit.hint("Pick a kitten below (or press 1-5), then click a grass tile next to the road.", "Tap a kitten card, then tap a grass tile twice to build."), Control.PRESET_CENTER_BOTTOM, _bottom_hint_offset)
		1:
			_show_hint("Purrfect! Press START WAVE when you're ready. The pack follows the road to my tower!", Control.PRESET_CENTER_TOP, _top_hint_offset)
		2:
			_show_hint(UIKit.hint("Click a kitten to upgrade it, or move it between waves. Q = Giant Paw, E = Zoomies.\nRight-drag or WASD to look around.", "Tap a kitten to upgrade it, or move it between waves. Giant Paw and Zoomies are the big buttons at the bottom left.\nDrag to look around, pinch to zoom."), Control.PRESET_CENTER_BOTTOM, _bottom_hint_offset)
			get_tree().create_timer(9.0).timeout.connect(func():
				_hint.visible = false
				_tutorial_step = 3
				Save.set_setting("tutorial_done", true))


func _show_hint(text: String, preset: Control.LayoutPreset, offset: Callable) -> void:
	_hint_label.text = text
	_hint.visible = true
	_hint_preset = preset
	_hint_offset = offset
	_place_hint()
	UIKit.pop_in(_hint)


## Puts the tutorial hint where its offset says now. The bottom hints lift over the card bar
## and the touch Cancel, and the top one under the wave button, so they are placed again
## whenever those change size or show.
func _place_hint() -> void:
	if not _hint.visible:
		return
	_hint.reset_size()
	_hint.set_anchors_and_offsets_preset(_hint_preset, Control.PRESET_MODE_MINSIZE, 12)
	_hint_shift_seen = _hint_shift()
	_hint.position += _hint_offset.call()


## Tutorial offset for the bottom hints: clear of the card bar (and the Cancel row, when shown).
func _bottom_hint_offset() -> Vector2:
	return Vector2(_hint_shift(), _bottom_lift())


## Tutorial offset for the top hint: under the wave button and its preview chips on touch.
func _top_hint_offset() -> Vector2:
	if UIKit.is_touch():
		return Vector2(_hint_shift(), maxf(204.0, _top_box.get_combined_minimum_size().y + 14.0))
	return Vector2(0, 160.0)


## Touch with the selection panel open: the hints move left, centred on the room beside
## the panel, so a long hint never covers the panel's title and buttons.
func _hint_shift() -> float:
	if not (UIKit.is_touch() and _sel_panel.visible):
		return 0.0
	return -(_sel_panel.get_combined_minimum_size().x + SEL_MARGIN) * 0.5


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
	panel.add_theme_stylebox_override("panel", UIKit.modal_panel())
	panel.custom_minimum_size.x = width
	outer.add_child(panel)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	UIKit.fade_scale_in(outer)
	return v


## Button for the bottom row of an end-of-run modal, all the same size.
func _modal_button(text: String, cb: Callable, color: String) -> Button:
	var b := UIKit.button(text, cb, roundi(22 * _text_k()), color)
	b.custom_minimum_size = Vector2(200 * _text_k(), UIKit.tap_min(58.0, 60.0))
	return b


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
			["Full screen", func(): _toggle_fullscreen(), "yellow", ""],
			["Restart", func(): game.restart(), "yellow", ""],
			["Main Menu", func(): game.quit_to_menu(), "red", ""]]:
		var b := UIKit.button(entry[0], entry[1], roundi(22 * _text_k()), entry[2], entry[3])
		b.custom_minimum_size = Vector2(270 * _text_k(), UIKit.tap_min(58.0, 60.0))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
		if entry[0] == "Full screen":
			_pause_fs_btn = b
			b.text = _fs_text(_is_fullscreen())
	var keys := UIKit.label(UIKit.hint("1-5 build · Q paw · E zoomies · Space wave · F speed\nU upgrade · X sell · T target · right-drag pan · wheel zoom", "Tap a kitten to upgrade it · drag to look around · pinch to zoom"), 14, UIKit.INK_SOFT)
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
	var sk := _text_k()
	var v := _open_modal("CHOOSE A PURR-K", maxf(760.0, 3.0 * 220.0 * sk + 80.0))
	v.add_child(_center(UIKit.label("Your cat found something shiny after wave %d!" % game.wave, 18, UIKit.INK_SOFT)))
	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	Sfx.play("perk")
	var i := 0
	for id in options:
		var d: Dictionary = GameData.PERKS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 250) * sk
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
		var ic := UIKit.icon(d.icon, Color.WHITE, 76.0 * sk)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		var nm := UIKit.label(d.name, roundi(23 * sk), UIKit.INK, 0, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(nm)
		var ds := UIKit.label(d.desc, roundi(16 * sk), UIKit.INK_SOFT)
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(ds)
		var stack := game.perk(id)
		if stack > 0:
			cv.add_child(_center(UIKit.label("Level %d → %d" % [stack, stack + 1], roundi(15 * sk), UIKit.GREEN, 0, true)))
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
		rr.custom_minimum_size.y = UIKit.tap_min(0.0, 60.0)
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
	buttons.add_child(_modal_button("Endless Mode", func():
		_close_modal()
		get_tree().paused = false
		game.continue_endless()
		banner("Endless", "How long can your cat hold out?", 1.6), "blue"))
	buttons.add_child(_modal_button("Main Menu", func(): game.quit_to_menu(), "yellow"))
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
	buttons.add_child(_modal_button("Try Again", func(): game.restart(), "green"))
	buttons.add_child(_modal_button("Cat Tree", func(): game.quit_to_menu(), "yellow"))
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
