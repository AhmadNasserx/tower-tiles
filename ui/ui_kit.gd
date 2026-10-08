class_name UIKit
## Shared theme + helpers for building juicy UI in code.

const FONT_BOLD := preload("res://assets/fonts/Asap-Bold.ttf")
const FONT_BLACK := preload("res://assets/fonts/Asap-Black.ttf")

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT_BOLD
	t.default_font_size = 18

	var ink := GameData.C_INK
	var cream := GameData.C_CREAM

	t.set_stylebox("normal", "Button", _box(cream, ink, 3, 14, Vector4(16, 8, 16, 10), 4))
	t.set_stylebox("hover", "Button", _box(Color("ffe2b8"), ink, 3, 14, Vector4(16, 8, 16, 10), 5))
	t.set_stylebox("pressed", "Button", _box(Color("ffc78a"), ink, 3, 14, Vector4(16, 10, 16, 8), 1))
	t.set_stylebox("disabled", "Button", _box(Color("b9adc0"), Color("6b5d73"), 3, 14, Vector4(16, 8, 16, 10), 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", ink)
	t.set_color("font_hover_color", "Button", ink)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_focus_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color("6b5d73"))
	t.set_font("font", "Button", FONT_BLACK)
	t.set_font_size("font_size", "Button", 20)

	t.set_stylebox("panel", "PanelContainer", _box(Color(ink, 0.9), Color("4a3b57"), 3, 18, Vector4(18, 14, 18, 14), 6))
	t.set_stylebox("panel", "Panel", _box(Color(ink, 0.9), Color("4a3b57"), 3, 18, Vector4(18, 14, 18, 14), 6))
	t.set_color("font_color", "Label", cream)
	t.set_color("font_outline_color", "Label", ink)
	t.set_constant("outline_size", "Label", 0)

	t.set_stylebox("slider", "HSlider", _box(Color("4a3b57"), Color("4a3b57"), 0, 6, Vector4(0, 4, 0, 4), 0))
	t.set_stylebox("grabber_area", "HSlider", _box(GameData.C_ORANGE, GameData.C_ORANGE, 0, 6, Vector4(0, 4, 0, 4), 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GameData.C_ORANGE.lightened(0.2), GameData.C_ORANGE, 0, 6, Vector4(0, 4, 0, 4), 0))
	t.set_icon("grabber", "HSlider", _dot_texture(GameData.C_CREAM, 22))
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(Color("ffe2b8"), 24))

	t.set_color("font_color", "CheckButton", cream)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", cream)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_font("font", "CheckButton", FONT_BOLD)

	t.set_stylebox("panel", "TooltipPanel", _box(Color(ink, 0.95), GameData.C_ORANGE, 2, 10, Vector4(10, 6, 10, 6), 0))
	t.set_color("font_color", "TooltipLabel", cream)
	_theme = t
	return t


static func _box(bg: Color, border: Color, bw: int, radius: int, margins: Vector4, shadow: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margins.x
	s.content_margin_top = margins.y
	s.content_margin_right = margins.z
	s.content_margin_bottom = margins.w
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.6)
	s.anti_aliasing = true
	return s


static func panel_style(bg: Color, border: Color, radius := 16, bw := 3) -> StyleBoxFlat:
	return _box(bg, border, bw, radius, Vector4(14, 10, 14, 10), 6)


static func _dot_texture(c: Color, size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var col := c if d < r - 3 else GameData.C_INK
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 18, color := GameData.C_CREAM, outline := 0, black := false) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = FONT_BLACK if black else FONT_BOLD
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = GameData.C_INK
	l.label_settings = ls
	return l


static func button(text: String, callback: Callable, size := 20) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
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
			c.scale = Vector2(hover_scale + 0.06, hover_scale - 0.12))
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
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func center_container(parent: Node) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	return cc


static func dim(parent: Node, alpha := 0.55) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(GameData.C_INK, 0.0)
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


static func icon(kind: String, color: Color, size := 28.0) -> Control:
	var i := preload("res://ui/icon.gd").new()
	i.kind = kind
	i.color = color
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i
