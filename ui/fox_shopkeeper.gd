class_name FoxShopkeeper
extends Control
## Fenn, the fox who runs the Cat Tree stall. A live 3D portrait (a Kenney fox
## rendered in its own SubViewport) with a parchment speech bubble above him.
## Lines type out, and every new line gets a little hop. Click him for a quip.
## Freeing this node frees the viewport too, so the portrait stops rendering
## as soon as the shop closes.

const PORTRAIT := Vector2(240, 280)
const BUBBLE_H := 104.0
const TAIL_H := 12.0

const GREET := "Psst! Fresh upgrades, finest fish in the neighborhood!"
const BOUGHT := "Pleasure doing business!"
const BROKE := "Come back with more fish!"
const SOLD_OUT := "Sold out of that one, friend!"
const REFUND := "Changed your mind? Happens to the best of us."
const POKES := [
	"Mmm, fresh herring today.",
	"Tails up, friend!",
	"Nothing sneaky about my prices. Mostly.",
	"Whiskers sharp, wallet ready?",
	"Don't tell the cats I'm open late.",
]

var _rig: PetRig
var _view: SubViewport
var _line: Label
var _type_tw: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(PORTRAIT.x, BUBBLE_H + TAIL_H + PORTRAIT.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)

	var col := UIKit.vbox(0)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# speech bubble, with a fixed height so the portrait never jumps when text changes
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UIKit.sbox("panel_brown.png", 22, Vector4(16, 10, 16, 10)))
	bubble.custom_minimum_size = Vector2(PORTRAIT.x, BUBBLE_H)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bubble)
	_line = UIKit.label("", 15, UIKit.INK)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(_line)

	# little tail pointing down at the fox
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(28, TAIL_H)
	tail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(func():
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(28, 0), Vector2(14, TAIL_H)])
		tail.draw_colored_polygon(pts, Color("e9d2a6"))
		tail.draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(14, TAIL_H), Vector2(28, 0)]), Color("6b4426"), 2.0))
	col.add_child(tail)

	# the 3D portrait
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = PORTRAIT
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	_view = SubViewport.new()
	_view.size = Vector2i(PORTRAIT)
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("web") else Viewport.MSAA_2X
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	holder.add_child(_view)

	# one warm light and ambient, no shadows: cheap enough for web
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("ffe9d0")
	e.ambient_light_energy = 0.6
	env.environment = e
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	_view.add_child(sun)

	_rig = PetRig.create("fox", 1.0)
	_rig.rotation.y = PI - 0.35 # faces the camera, slightly turned
	_view.add_child(_rig)

	var cam := Camera3D.new()
	cam.fov = 30
	cam.current = true
	_view.add_child(cam)
	var target := Vector3(0, 0.85, 0)
	var dir := Basis.from_euler(Vector3(deg_to_rad(-8.0), 0.0, 0.0)) * Vector3(0, 0, 1)
	cam.position = target + dir * 4.5
	cam.look_at(target)


## Greeting when the shop opens.
func greet() -> void:
	say(GREET, 2.0)
	_rig.gesture("gesture-positive")


## A line about the upgrade under the cursor. `d` is its GameData.META entry.
func say_about(d: Dictionary) -> void:
	var nm: String = d.name
	var line := ""
	match randi() % 3:
		0:
			line = "Ooh, %s! A classic." % nm
		1:
			line = "%s? %s. Now THAT's a deal." % [nm, String(d.desc).trim_suffix(".")]
		_:
			line = "Good eye! %s is flying off my shelf." % nm
	say(line)


## A purchase went through.
func celebrate() -> void:
	say(BOUGHT, 4.2)
	_rig.gesture("gesture-positive")
	Sfx.play("coin", 1.0, 0.0)


## Tried to buy with too few fish.
func say_broke() -> void:
	say(BROKE)
	_rig.gesture("gesture-negative")


## The upgrade is already at its max level.
func say_sold_out() -> void:
	say(SOLD_OUT)
	_rig.gesture("gesture-negative")


func say_refund() -> void:
	say(REFUND)


## Clicking Fenn: a random quip and a bounce.
func poke() -> void:
	var line: String = POKES[randi() % POKES.size()]
	say(line, 2.4)
	Sfx.play("click", 1.2, 0.05)


## Types `line` out in the bubble and gives Fenn a small talk bounce.
func say(line: String, hop := 2.4) -> void:
	if _line == null:
		return
	_line.text = line
	_line.visible_ratio = 0.0
	if _type_tw and _type_tw.is_valid():
		_type_tw.kill()
	_type_tw = create_tween().set_ignore_time_scale(true)
	_type_tw.tween_property(_line, "visible_ratio", 1.0, clampf(line.length() * 0.016, 0.2, 1.0))
	_rig.bounce(0.1)
	_rig.hop(hop)


func _on_gui_input(ev) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		poke()
		accept_event()
