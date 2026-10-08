class_name PetRig
extends Node3D
## Wraps a Kenney Cube Pets model: toon materials + outline, its built-in
## animations (idle, walk, run, dance, gestures), hit flash, tint, and a
## springy squash-and-stretch layered on top. Faces -Z like the rest of the game.

const PATHS := {
	"cat": "res://assets/models/pets/animal-cat.glb",
	"dog": "res://assets/models/pets/animal-dog.glb",
	"fox": "res://assets/models/pets/animal-fox.glb",
	"hog": "res://assets/models/pets/animal-hog.glb",
	"bunny": "res://assets/models/pets/animal-bunny.glb",
	"elephant": "res://assets/models/pets/animal-elephant.glb",
	"tiger": "res://assets/models/pets/animal-tiger.glb",
	"lion": "res://assets/models/pets/animal-lion.glb",
	"fish": "res://assets/models/pets/animal-fish.glb",
}

static var _scenes := {}

var kind := "cat"
var model: Node3D
var anim: AnimationPlayer
var geoms: Array[GeometryInstance3D] = []
var _materials: Array[Material] = []
var base_scale := 1.0

var _squash := 0.0
var _squash_v := 0.0
var _hop := 0.0
var _hop_v := 0.0
var _flash_t := 0.0
var _current := ""
var _puff := 0.0


static func scene(k: String) -> PackedScene:
	if not _scenes.has(k):
		_scenes[k] = load(PATHS[k])
	return _scenes[k]


static func create(k: String, s := 1.0, tint := Color(1, 1, 1), outline := true) -> PetRig:
	var r := PetRig.new()
	r.kind = k
	r.base_scale = s
	r._build(tint, outline)
	return r


func _build(tint: Color, outline: bool) -> void:
	model = scene(kind).instantiate()
	model.rotation.y = PI # Kenney pets face +Z; the game uses -Z as forward
	add_child(model)
	geoms = Toon.apply(model, outline, false, false, tint)
	for g in geoms:
		_materials.append(g.material_override)
	# only the big body part casts a shadow (cheap, and it reads the same)
	for g in geoms:
		if g.name.begins_with("body") or g.get_parent().name.begins_with("body"):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim = model.find_child("AnimationPlayer", true, false)
	scale = Vector3.ONE * base_scale
	play("idle")


func play(anim_name: String, speed := 1.0, blend := 0.15) -> void:
	if anim == null:
		return
	anim.speed_scale = speed
	if anim_name == _current and anim.is_playing():
		return
	_current = anim_name
	if anim.has_animation(anim_name):
		var a := anim.get_animation(anim_name)
		if anim_name in ["idle", "walk", "run", "dance"]:
			a.loop_mode = Animation.LOOP_LINEAR
		anim.play(anim_name, blend)


## Plays a one-shot animation then goes back to `then`.
func gesture(anim_name: String, then := "idle", speed := 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	_current = anim_name
	anim.speed_scale = speed
	anim.play(anim_name, 0.08)
	var len := anim.get_animation(anim_name).length / maxf(speed, 0.01)
	get_tree().create_timer(len, false).timeout.connect(func():
		if is_instance_valid(self) and _current == anim_name:
			play(then))


func flash(time := 0.07) -> void:
	_flash_t = time
	var white := Toon.flash_material()
	for g in geoms:
		g.material_override = white


func bounce(amount := 0.18) -> void:
	_squash_v += amount * 14.0


func hop(v := 3.5) -> void:
	_hop_v = v


func puff_up() -> void:
	_puff = 1.0
	bounce(0.3)


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	_squash_v += (-_squash * 180.0 - _squash_v * 14.0) * delta
	_squash += _squash_v * delta
	_hop_v -= 30.0 * delta
	_hop = maxf(0.0, _hop + _hop_v * delta)
	if _hop == 0.0:
		_hop_v = 0.0
	_puff = move_toward(_puff, 0.0, delta * 1.5)
	var w := 1.0 - _squash * 0.5 + _puff * 0.25
	model.scale = Vector3(w, 1.0 + _squash + _puff * 0.15, w)
	model.position.y = _hop / maxf(base_scale, 0.01)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			for i in geoms.size():
				geoms[i].material_override = _materials[i]
