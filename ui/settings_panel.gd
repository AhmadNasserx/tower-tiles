extends VBoxContainer
## Volume, screen shake and quality settings. Used by the main menu and pause menu.

signal closed


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	custom_minimum_size = Vector2(400, 0)
	_slider("Master volume", "master")
	_slider("Music", "music")
	_slider("Sound effects", "sfx")
	var shake := CheckBox.new()
	shake.text = "Screen shake"
	shake.button_pressed = Save.settings.shake
	shake.toggled.connect(func(v): Save.set_setting("shake", v))
	add_child(shake)
	var quality := CheckBox.new()
	quality.text = "Fancy graphics (shadows, outlines, full res)"
	quality.button_pressed = Save.settings.quality != "low"
	quality.toggled.connect(func(v): Save.set_setting("quality", "high" if v else "low"))
	add_child(quality)
	add_child(UIKit.label("Graphics changes apply on the next level load.", 14, UIKit.INK_SOFT))
	var back := UIKit.button("Back", func(): closed.emit(), 22, "yellow")
	back.custom_minimum_size.x = 180
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)


func _slider(title: String, key: String) -> void:
	var row := UIKit.hbox(12)
	var l := UIKit.label(title, 18, UIKit.INK)
	l.custom_minimum_size.x = 150
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Save.settings[key]
	s.custom_minimum_size = Vector2(210, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v):
		Save.settings[key] = v
		Sfx.apply_volumes())
	s.drag_ended.connect(func(_c):
		Save.set_setting(key, s.value)
		Sfx.play("coin", 1.0, 0.0))
	row.add_child(s)
	add_child(row)
