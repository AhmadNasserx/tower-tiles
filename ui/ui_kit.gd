class_name UIKit
## Theme + helpers for the "cozy storybook" UI: Kenney parchment/wood panels,
## chunky bevelled buttons, Lilita One for titles and numbers, Fredoka for body
## text, and SVG icons.

const DISPLAY := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY_FILE := preload("res://assets/fonts/Fredoka.ttf")
const UI := "res://assets/ui/"

## Ribbon geometry, measured from banner_hanging.png (512x128, texture margin 40).
## Left/right: the red band is symmetric (x 8..503), so both sides are 56.
## Top/bottom: at the centre column the band runs from y=19 (its top, under the
## pins) down to y=121, so it sits 19 px from the top edge and 7 px from the
## bottom edge. The art has no tails hanging below, so the band is not centred
## vertically in the panel. Its centre is 6 px below the panel's centre, and the
## title's content box must shift down by the same amount: top - bottom = 12.
## top + bottom = 44 keeps the panel height the same as it was before.
const RIBBON_MARGINS := Vector4(56, 28, 56, 16)
const RIBBON_OUTLINE := 8

# UI palette
const INK := Color("4a2c1d") # text on parchment
const INK_SOFT := Color("8a6a54")
const OUTLINE := Color("2b1a10") # outlines for text over the 3D world
const PARCH := Color("fdf0d5")
const CREAM := Color("fff7e6")
const GOLD := Color("ffd23f")
const RED := Color("e8484f")
const GREEN := Color("2f9e5b")

static var _theme: Theme
static var _body: FontVariation
static var _body_bold: FontVariation
static var _tex := {}

## Touch layout. Phones and tablets get bigger tap targets and wording without
## keyboard keys. The device is probed once; the HUD also sets `touch_seen` on the
## first screen touch, for touch screens the probe missed.
##
## Sizes are in logical px, but the stretch (canvas_items + expand, 720 logical px
## high) means one logical px can be much less than one real screen px: on a 390 px
## tall phone it is 0.54 real px. So the touch scale follows the real window size.
const TOUCH_SCALE_MIN := 1.25 # what a 1280x720 touch screen gets (one logical px = one real px)
const TOUCH_SCALE_MAX := 1.7 # cap for very small windows
const TOUCH_BASE := 56.0 # a base tap target, in logical px
const TOUCH_MIN_PX := 46.0 # the real screen px a tap target should cover (44 is the floor)
static var touch_seen := false
static var _probed := false
static var _probe_touch := false


static func body_font(bold := false) -> Font:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = BODY_FILE
		_body.variation_opentype = {"wght": 500}
		_body_bold = FontVariation.new()
		_body_bold.base_font = BODY_FILE
		_body_bold.variation_opentype = {"wght": 650}
	return _body_bold if bold else _body


static func tex(file: String) -> Texture2D:
	if not _tex.has(file):
		_tex[file] = load(UI + file)
	return _tex[file]


## Nine-slice style from a Kenney texture. `m` = texture margin, `c` = content
## margins (left, top, right, bottom).
static func sbox(file: String, m: float, c := Vector4(14, 10, 14, 10), modulate := Color(1, 1, 1)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex(file)
	s.texture_margin_left = m
	s.texture_margin_top = m
	s.texture_margin_right = m
	s.texture_margin_bottom = m
	s.content_margin_left = c.x
	s.content_margin_top = c.y
	s.content_margin_right = c.z
	s.content_margin_bottom = c.w
	s.modulate_color = modulate
	return s


static func parchment() -> StyleBoxTexture:
	return sbox("panel_brown.png", 22, Vector4(22, 18, 22, 20))


static func wood() -> StyleBoxTexture:
	return sbox("panel_brown_dark.png", 22, Vector4(18, 12, 18, 14))


## Chunky bevelled button styles: "green", "yellow", "red", "grey", "blue".
static func button_styles(color: String, square := false) -> Dictionary:
	var base := ("sq_" if square else "btn_") + color
	var m := 20.0
	var c := Vector4(20, 9, 20, 17)
	var cp := Vector4(20, 13, 20, 13)
	return {
		"normal": sbox(base + ".png", m, c),
		"hover": sbox(base + ".png", m, c, Color(1.12, 1.12, 1.12)),
		"pressed": sbox(base + "_pressed.png", m, cp),
		"disabled": sbox("btn_grey.png" if not square else "sq_grey.png", m, c, Color(0.85, 0.82, 0.8)),
		"focus": StyleBoxEmpty.new(),
	}


static func style_button(b: Button, color: String, square := false) -> void:
	var st := button_styles(color, square)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	var light := color in ["green", "red", "blue"]
	var fc := CREAM if light else INK
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color("7d6d66"))
	if light:
		b.add_theme_constant_override("outline_size", 6)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font(true)
	t.default_font_size = 18

	var st := button_styles("yellow")
	for k in st:
		t.set_stylebox(k, "Button", st[k])
	t.set_font("font", "Button", DISPLAY)
	t.set_font_size("font_size", "Button", 22)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color("7d6d66"))

	t.set_stylebox("panel", "PanelContainer", parchment())
	t.set_stylebox("panel", "Panel", parchment())
	t.set_color("font_color", "Label", INK)

	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("c9a77c")
	groove.set_corner_radius_all(6)
	groove.content_margin_top = 5
	groove.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e8913a")
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _scaled_icon("paw", 30)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)

	t.set_icon("checked", "CheckBox", tex("checkbox_brown_checked.png"))
	t.set_icon("unchecked", "CheckBox", tex("checkbox_brown_empty.png"))
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(k, "CheckBox", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, "CheckBox", INK)
	t.set_constant("h_separation", "CheckBox", 10)

	t.set_stylebox("panel", "TooltipPanel", sbox("panel_brown.png", 22, Vector4(16, 12, 16, 12)))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", body_font(true))
	t.set_font_size("font_size", "TooltipLabel", 16)
	_theme = t
	return t


static func _scaled_icon(kind: String, px: int) -> Texture2D:
	var img: Image = icon_texture(kind).get_image()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


static func icon_texture(kind: String) -> Texture2D:
	return tex("icons/%s.svg" % kind)


## Text label. `display` = Lilita One (titles/numbers), otherwise Fredoka.
## `outline` > 0 adds a dark outline, for text sitting on top of the 3D world.
static func label(text: String, size := 18, color := INK, outline := 0, display := false) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = DISPLAY if display else body_font(true)
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = OUTLINE
		ls.shadow_size = 0
		ls.shadow_color = Color(0, 0, 0, 0.35)
		ls.shadow_offset = Vector2(0, 3)
	l.label_settings = ls
	return l


static func button(text: String, callback: Callable, size := 22, color := "yellow", icon_kind := "") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	style_button(b, color)
	if icon_kind != "":
		b.icon = _scaled_icon(icon_kind, int(size * 1.3))
		b.add_theme_constant_override("h_separation", 8)
	b.pressed.connect(callback)
	juicy(b)
	return b


## Hover bounce, press squash and sounds for any Control that has mouse signals.
## Every move goes through _scale_to, so a new move cancels the tween still
## running and quick hover in/out never fights itself. Touch taps usually emulate
## a mouse, so they get the same bounce as a hover.
static func juicy(c: Control, hover_scale := 1.06) -> void:
	c.mouse_entered.connect(func():
		if c is BaseButton and (c as BaseButton).disabled:
			return
		Sfx.play("hover", 1.0, 0.1)
		_scale_to(c, Vector2.ONE * hover_scale, 0.12, Tween.TRANS_BACK))
	c.mouse_exited.connect(func():
		_scale_to(c, Vector2.ONE, 0.15, Tween.TRANS_QUAD))
	if c is BaseButton:
		(c as BaseButton).button_down.connect(func():
			_scale_to(c, Vector2(hover_scale + 0.05, hover_scale - 0.08), 0.06, Tween.TRANS_QUAD))
		(c as BaseButton).pressed.connect(func():
			Sfx.play("click", 1.0, 0.05)
			_scale_to(c, Vector2.ONE * hover_scale, 0.35, Tween.TRANS_ELASTIC))
	c.resized.connect(func(): _pivot(c))


## One scale tween per control, real-time (ignores slow-mo and pause scaling).
static func _scale_to(c: Control, target: Vector2, dur: float, trans: Tween.TransitionType) -> void:
	_pivot(c)
	if c.has_meta("juicy_tw"):
		var old: Variant = c.get_meta("juicy_tw")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := c.create_tween().set_ignore_time_scale(true)
	tw.tween_property(c, "scale", target, dur).set_trans(trans).set_ease(Tween.EASE_OUT)
	c.set_meta("juicy_tw", tw)


static func _pivot(c: Control) -> void:
	c.pivot_offset = c.size * 0.5


## Gentle modal entrance: fades in while easing up from a slight shrink, no
## bounce. Real-time, so it still plays while the game is paused or slowed.
static func fade_scale_in(c: Control, start_scale := 0.94, dur := 0.22) -> void:
	_pivot(c)
	c.resized.connect(func(): _pivot(c))
	c.scale = Vector2.ONE * start_scale
	c.modulate.a = 0.0
	var tw := c.create_tween().set_ignore_time_scale(true)
	tw.tween_property(c, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, dur + 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## The parchment card behind modal and panel content, so they all share margins.
static func modal_panel() -> StyleBoxTexture:
	return sbox("panel_brown.png", 22, Vector4(30, 34, 30, 26))


static func pop_in(c: Control, delay := 0.0) -> void:
	_pivot(c)
	c.scale = Vector2(0.3, 0.3)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_callback(func(): _pivot(c))
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func center_container(parent: Node) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	return cc


static func dim(parent: Node, alpha := 0.5) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.12, 0.07, 0.04, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(r)
	r.create_tween().set_ignore_time_scale(true).tween_property(r, "color:a", alpha, 0.25)
	return r


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func icon(kind: String, _color := Color.WHITE, size := 28.0) -> TextureRect:
	var i := TextureRect.new()
	i.texture = icon_texture(kind)
	i.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	i.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## A 3D portrait (see Portraits) that fills in as soon as it's rendered.
static func portrait(key: String, size := 64.0) -> TextureRect:
	var i := TextureRect.new()
	i.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	i.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portraits: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Portraits")
	if portraits:
		portraits.fill(i, key)
	return i


## Hanging ribbon banner with a title on it (see RIBBON_MARGINS for the geometry).
static func ribbon(text: String, size := 34, width := 420.0) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox("banner_hanging.png", 40, RIBBON_MARGINS))
	p.set_meta("ribbon_size", size)
	p.set_meta("ribbon_width", width)
	var l := label(text, size, CREAM, RIBBON_OUTLINE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	_fit_ribbon(p)
	return p


## Changes a ribbon's title (the Label returned as its child) and re-fits it.
static func ribbon_set_text(l: Label, text: String) -> void:
	if l.text == text:
		return
	l.text = text
	var p := l.get_parent() as PanelContainer
	if p:
		_fit_ribbon(p)


## Shrinks the title font (down to 60% of its base size) until it fits the
## ribbon's width. If it still does not fit, the ribbon grows to fit the text
## instead of spilling out of the frame.
static func _fit_ribbon(p: PanelContainer) -> void:
	var l := p.get_child(0) as Label
	var base_fs: int = p.get_meta("ribbon_size")
	var width: float = p.get_meta("ribbon_width")
	var pad: float = RIBBON_MARGINS.x + RIBBON_MARGINS.z + 2.0 * RIBBON_OUTLINE
	var min_fs := int(round(base_fs * 0.6))
	var fs := base_fs
	while fs > min_fs and DISPLAY.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width - pad:
		fs -= 1
	l.label_settings.font_size = fs
	var text_w := DISPLAY.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	p.custom_minimum_size.x = maxf(width, text_w + pad)


# ------------------------------------------------------------------ touch

## True on touch devices, or once a screen touch has been seen. Cached.
static func is_touch() -> bool:
	if touch_seen:
		return true
	if not _probed:
		_probed = true
		_probe_touch = _device_has_touch()
	return _probe_touch


## Window size in real screen px. On the web it is the canvas's CSS size, so a
## high-density phone (devicePixelRatio 2 or 3) is not counted as bigger than it is.
static func window_px() -> Vector2:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js = Engine.get_singleton("JavaScriptBridge")
		var s := str(js.eval("(function(){var c=document.getElementById('canvas');return c?c.clientWidth+','+c.clientHeight:''})()", true))
		var parts := s.split(",")
		if parts.size() == 2 and parts[0].to_float() > 0.0 and parts[1].to_float() > 0.0:
			return Vector2(parts[0].to_float(), parts[1].to_float())
	return Vector2(DisplayServer.window_get_size())


## Real screen px per logical px, as the stretch currently draws them. The logical
## size is the root viewport's visible rect; with `expand` the smaller of the two
## ratios is the drawn scale (in a landscape window that is the height ratio).
## Returns 1.0 when there is no window yet.
static func px_per_logical() -> float:
	var main := Engine.get_main_loop() as SceneTree
	if main == null or main.root == null:
		return 1.0
	var logical := main.root.get_visible_rect().size
	var px := window_px()
	if logical.x <= 0.0 or logical.y <= 0.0 or px.x <= 0.0 or px.y <= 0.0:
		return 1.0
	return minf(px.x / logical.x, px.y / logical.y)


## Layout multiplier for touch: 1.0 on desktop. On touch it makes a TOUCH_BASE
## logical target cover TOUCH_MIN_PX real px, clamped to [TOUCH_SCALE_MIN, TOUCH_SCALE_MAX].
## A 1280x720 touch screen gets TOUCH_SCALE_MIN, as before.
static func touch_scale() -> float:
	if not is_touch():
		return 1.0
	return clampf(TOUCH_MIN_PX / (TOUCH_BASE * px_per_logical()), TOUCH_SCALE_MIN, TOUCH_SCALE_MAX)


## The touch wording on touch screens, the desktop wording otherwise.
static func hint(desktop: String, touch: String) -> String:
	return touch if is_touch() else desktop


## `desktop` as it is, but on touch screens at least `touch_min` logical px and never
## less than TOUCH_MIN_PX real px (so it is the same on every screen, not only 720 high).
static func tap_min(desktop: float, touch_min: float) -> float:
	if not is_touch():
		return desktop
	return maxf(desktop, maxf(touch_min, TOUCH_MIN_PX / px_per_logical()))


static func _device_has_touch() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js = Engine.get_singleton("JavaScriptBridge")
		var ok = js.eval("('ontouchstart' in window) || navigator.maxTouchPoints > 0", true)
		return ok is bool and ok
	return false


## Thicker track and a bigger paw grabber on touch. Desktop sliders are left alone.
static func touch_slider(s: HSlider) -> void:
	if not is_touch():
		return
	s.custom_minimum_size.y = 48.0
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("c9a77c")
	groove.set_corner_radius_all(9)
	groove.content_margin_top = 9
	groove.content_margin_bottom = 9
	var fill := groove.duplicate() as StyleBoxFlat
	fill.bg_color = Color("e8913a")
	s.add_theme_stylebox_override("slider", groove)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var grab := _scaled_icon("paw", 42)
	s.add_theme_icon_override("grabber", grab)
	s.add_theme_icon_override("grabber_highlight", grab)


## Four corner brackets for a full-screen button, drawn so no glyph font is needed.
## `exit` is asked on each draw: the brackets point inwards while full screen.
static func fullscreen_glyph(exit: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var s := c.size
		var a := s * 0.26
		var b := s - a
		var arm := s.x * 0.2
		var ex: bool = exit.call()
		# [corner, inward x, inward y] for the four corners of the frame
		for corner in [[a, 1.0, 1.0], [Vector2(b.x, a.y), -1.0, 1.0], [Vector2(a.x, b.y), 1.0, -1.0], [b, -1.0, -1.0]]:
			var p: Vector2 = corner[0]
			var sx: float = corner[1]
			var sy: float = corner[2]
			# windowed: the bracket sits on the frame; full screen: it steps inwards, arms pointing out
			var tip := p + Vector2(sx * arm, sy * arm) if ex else p
			var dir := -1.0 if ex else 1.0
			c.draw_line(tip, tip + Vector2(dir * sx * arm, 0), INK, 3.0, true)
			c.draw_line(tip, tip + Vector2(0, dir * sy * arm), INK, 3.0, true))
	return c


## A full-screen "turn your phone" card for portrait viewports. It sits on a top
## layer above the HUD, the modals and the menus, blocks input while shown, and is
## re-checked on every viewport resize. It never pauses the game.
static func make_rotate_overlay(parent: Node) -> Control:
	var top := CanvasLayer.new()
	top.layer = 120
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(top)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	top.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(OUTLINE, 0.94)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var box := vbox(12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	# Sized for portrait: the stretch keeps the 1280-wide base, so the whole phone screen
	# is 1280 logical px across, roughly three times the landscape scale.
	var phone := _phone_glyph(2.8)
	box.add_child(phone)
	var rb := ribbon("Rotate your phone", 84, 1000)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rb)
	var tip := label("Tower Tiles plays best in landscape", 52, CREAM, 14, true)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size.x = 900
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tip)

	var tw := phone.create_tween().set_loops().set_ignore_time_scale(true)
	tw.tween_interval(0.5)
	tw.tween_property(phone, "rotation", -PI * 0.5, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(phone, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	var vp := parent.get_viewport()
	var refresh: Callable = func():
		if is_instance_valid(root):
			var s := root.get_viewport_rect().size
			root.visible = s.y > s.x * 1.05
	if vp:
		vp.size_changed.connect(refresh)
		root.tree_exiting.connect(func():
			if vp.size_changed.is_connected(refresh):
				vp.size_changed.disconnect(refresh))
	refresh.call()
	return root


## A phone outline with a grass screen, for the rotate overlay, drawn at `k` times
## the 80x136 size. Turns about its centre.
static func _phone_glyph(k: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(150, 150) * k
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	var body := StyleBoxFlat.new()
	body.bg_color = Color("6b4426")
	body.border_color = CREAM
	body.set_border_width_all(int(6 * k))
	body.set_corner_radius_all(int(16 * k))
	c.draw.connect(func():
		var mid := c.size * 0.5
		var r := Rect2(mid - Vector2(40, 68) * k, Vector2(80, 136) * k)
		c.draw_style_box(body, r)
		c.draw_rect(Rect2(r.position + Vector2(8, 14) * k, r.size - Vector2(16, 30) * k), Color("8fd16a"))
		c.draw_circle(Vector2(mid.x, r.end.y - 9 * k), 4.0 * k, CREAM))
	return c
