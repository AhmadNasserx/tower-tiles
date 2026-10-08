class_name UIKit
## Theme + helpers for the "cozy storybook" UI: Kenney parchment/wood panels,
## chunky bevelled buttons, Lilita One for titles and numbers, Fredoka for body
## text, and SVG icons.

const DISPLAY := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY_FILE := preload("res://assets/fonts/Fredoka.ttf")
const UI := "res://assets/ui/"

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


## Hover bounce, press squish and sounds for any Control that has mouse signals.
static func juicy(c: Control, hover_scale := 1.06) -> void:
	c.mouse_entered.connect(func():
		if c is BaseButton and (c as BaseButton).disabled:
			return
		_pivot(c)
		Sfx.play("hover", 1.0, 0.1)
		var tw := c.create_tween().set_ignore_time_scale(true)
		tw.tween_property(c, "scale", Vector2.ONE * hover_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	c.mouse_exited.connect(func():
		var tw := c.create_tween().set_ignore_time_scale(true)
		tw.tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	if c is BaseButton:
		(c as BaseButton).button_down.connect(func():
			_pivot(c)
			c.scale = Vector2(hover_scale + 0.05, hover_scale - 0.08))
		(c as BaseButton).pressed.connect(func():
			Sfx.play("click", 1.0, 0.05)
			var tw := c.create_tween().set_ignore_time_scale(true)
			tw.tween_property(c, "scale", Vector2.ONE * hover_scale, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	c.resized.connect(func(): _pivot(c))


static func _pivot(c: Control) -> void:
	c.pivot_offset = c.size * 0.5


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


## Hanging ribbon banner with a title on it.
static func ribbon(text: String, size := 34, width := 420.0) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox("banner_hanging.png", 40, Vector4(56, 14, 56, 30)))
	p.custom_minimum_size.x = width
	var l := label(text, size, CREAM, 8, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p
