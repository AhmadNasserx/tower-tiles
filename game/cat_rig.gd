class_name CatRig
extends Node3D
## A procedurally built, procedurally animated low-poly cat.
## Faces -Z. Sitting height is ~1.1 units at scale 1.

const WHITE := Color("fffaf2")
const PINK := Color("ff9fb5")
const EYE := Color("1e1a24")

static var _cache := {}

var fur := Color("ff9f43")
var pattern := "tabby"
var eye_color := Color("7bd389")

var body: MeshInstance3D
var head: Node3D
var eyes: Node3D
var ears: Array[Node3D] = []
var tail_segments: Array[Node3D] = []
var paw: Node3D

var _t := randf() * 10.0
var _blink_timer := randf_range(1.0, 4.0)
var _ear_timer := randf_range(2.0, 6.0)
var _squash := 0.0 # >0 stretched up, <0 squashed
var _squash_v := 0.0
var _puff := 0.0
var _head_target_yaw := 0.0
var _head_yaw := 0.0
var _hop := 0.0
var _hop_v := 0.0
var tail_speed := 2.0
var sleepy := false
var paw_raise := 0.0


static func create(fur_color: Color, pattern_name := "tabby", eye := Color("7bd389")) -> CatRig:
	var c := CatRig.new()
	c.fur = fur_color
	c.pattern = pattern_name
	c.eye_color = eye
	c._build()
	return c


func _darker(c: Color, amt := 0.25) -> Color:
	return c.darkened(amt)


func _build() -> void:
	var key := "%s|%s|%s" % [fur.to_html(), pattern, eye_color.to_html()]
	var meshes: Dictionary
	if _cache.has(key):
		meshes = _cache[key]
	else:
		meshes = _make_meshes()
		_cache[key] = meshes

	body = MeshKit.instance(meshes.body, self)
	head = Node3D.new()
	head.position = Vector3(0, 0.84, -0.06)
	add_child(head)
	MeshKit.instance(meshes.head, head)
	for side in [-1, 1]:
		var ear := Node3D.new()
		ear.position = Vector3(0.16 * side, 0.17, 0.0)
		head.add_child(ear)
		MeshKit.instance(meshes.ear, ear, false).scale.x = side
		ears.append(ear)
	eyes = Node3D.new()
	eyes.position = Vector3(0, 0.03, -0.225)
	head.add_child(eyes)
	MeshKit.instance(meshes.eyes, eyes, false)

	paw = Node3D.new()
	paw.position = Vector3(0.13, 0.3, -0.2)
	add_child(paw)
	MeshKit.instance(meshes.paw, paw, false)

	var parent: Node3D = self
	var pos := Vector3(0, 0.14, 0.33)
	for i in 5:
		var seg := Node3D.new()
		seg.position = pos
		parent.add_child(seg)
		MeshKit.instance(meshes.tail_tip if i == 4 else meshes.tail, seg, false)
		tail_segments.append(seg)
		parent = seg
		pos = Vector3(0, 0.0, 0.14)


func _make_meshes() -> Dictionary:
	var dark := _darker(fur, 0.3)
	var belly := WHITE if pattern != "black" else fur.lightened(0.15)
	var out := {}

	var k := MeshKit.new()
	# body: pear shaped sitting pose
	k.sphere(Vector3(0, 0.38, 0.06), Vector3(0.3, 0.37, 0.33), fur)
	k.sphere(Vector3(0.19, 0.2, 0.12), Vector3(0.17, 0.17, 0.22), fur)
	k.sphere(Vector3(-0.19, 0.2, 0.12), Vector3(0.17, 0.17, 0.22), fur)
	k.sphere(Vector3(0, 0.44, -0.19), Vector3(0.17, 0.22, 0.1), belly)
	# left front leg (right one is the animated paw)
	k.cylinder(Vector3(-0.13, 0.17, -0.2), 0.07, 0.32, fur)
	k.sphere(Vector3(-0.13, 0.03, -0.25), Vector3(0.085, 0.05, 0.11), belly)
	# back paws
	k.sphere(Vector3(0.22, 0.03, -0.06), Vector3(0.08, 0.045, 0.12), belly)
	k.sphere(Vector3(-0.22, 0.03, -0.06), Vector3(0.08, 0.045, 0.12), belly)
	if pattern == "tabby":
		for i in 3:
			k.box(Vector3(0, 0.55 - i * 0.14, 0.3), Vector3(0.36, 0.05, 0.12), dark, Vector3(-25 + i * 15, 0, 0))
	elif pattern == "calico":
		k.sphere(Vector3(0.12, 0.5, 0.18), Vector3(0.2, 0.18, 0.2), Color("2b2b2b"))
		k.sphere(Vector3(-0.15, 0.3, 0.2), Vector3(0.18, 0.15, 0.2), Color("e88a3a"))
	out.body = k.build()

	k = MeshKit.new()
	k.sphere(Vector3.ZERO, Vector3(0.29, 0.25, 0.26), fur)
	k.sphere(Vector3(0.11, -0.07, -0.17), Vector3(0.11, 0.09, 0.1), WHITE)
	k.sphere(Vector3(-0.11, -0.07, -0.17), Vector3(0.11, 0.09, 0.1), WHITE)
	k.cone(Vector3(0, -0.02, -0.255), 0.035, 0.05, PINK, Vector3(180, 0, 0), 3)
	k.box(Vector3(0, -0.12, -0.21), Vector3(0.04, 0.04, 0.02), Color("c46a7f"))
	if pattern == "tabby":
		k.box(Vector3(0, 0.2, -0.08), Vector3(0.05, 0.06, 0.16), dark)
		k.box(Vector3(0.08, 0.19, -0.06), Vector3(0.04, 0.05, 0.14), dark, Vector3(0, 0, -20))
		k.box(Vector3(-0.08, 0.19, -0.06), Vector3(0.04, 0.05, 0.14), dark, Vector3(0, 0, 20))
	elif pattern == "calico":
		k.sphere(Vector3(-0.12, 0.1, -0.05), Vector3(0.16, 0.14, 0.18), Color("e88a3a"))
	# whiskers
	for side in [-1, 1]:
		for j in 2:
			k.box(Vector3(0.25 * side, -0.06 - j * 0.04, -0.17), Vector3(0.2, 0.008, 0.008), Color(1, 1, 1, 1), Vector3(0, 10 * side, (8 - j * 14) * side))
	out.head = k.build()

	k = MeshKit.new()
	k.cone(Vector3(0, 0.08, 0), 0.11, 0.2, fur, Vector3(0, 45, -12), 4)
	k.cone(Vector3(0.0, 0.065, -0.035), 0.06, 0.13, PINK, Vector3(0, 45, -12), 4)
	out.ear = k.build()

	k = MeshKit.new()
	for side in [-1, 1]:
		k.sphere(Vector3(0.105 * side, 0, 0), Vector3(0.06, 0.075, 0.03), eye_color)
		k.sphere(Vector3(0.105 * side, 0, -0.012), Vector3(0.035, 0.065, 0.025), EYE)
		k.sphere(Vector3(0.105 * side + 0.02, 0.03, -0.03), Vector3(0.015, 0.015, 0.01), WHITE)
	out.eyes = k.build_unshaded()

	k = MeshKit.new()
	k.cylinder(Vector3(0, -0.12, 0), 0.07, 0.3, fur)
	k.sphere(Vector3(0, -0.27, -0.05), Vector3(0.085, 0.05, 0.11), belly)
	out.paw = k.build()

	k = MeshKit.new()
	k.sphere(Vector3(0, 0, 0.07), Vector3(0.06, 0.06, 0.1), fur, Vector3.ZERO, 6)
	out.tail = k.build()
	k = MeshKit.new()
	k.sphere(Vector3(0, 0, 0.07), Vector3(0.065, 0.065, 0.11), dark if pattern != "black" else fur, Vector3.ZERO, 6)
	out.tail_tip = k.build()
	return out


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0) # keep the springs stable on long frames
	_t += delta
	# breathing + springy squash
	var spring := -_squash * 180.0 - _squash_v * 14.0
	_squash_v += spring * delta
	_squash += _squash_v * delta
	_hop_v -= 30.0 * delta
	_hop = max(0.0, _hop + _hop_v * delta)
	if _hop == 0.0:
		_hop_v = 0.0
	var breathe := sin(_t * (1.2 if sleepy else 2.4)) * 0.02
	_puff = move_toward(_puff, 0.0, delta * 1.5)
	var s := 1.0 + _squash + breathe + _puff * 0.25
	body.scale = Vector3(1.0 - _squash * 0.5 + _puff * 0.3, s, 1.0 - _squash * 0.5 + _puff * 0.3)
	body.position.y = _hop
	head.position.y = 0.84 * s + _hop + (-0.12 if sleepy else 0.0)
	# head yaw (look at stuff)
	_head_yaw = lerp_angle(_head_yaw, _head_target_yaw, 1.0 - exp(-delta * 8.0))
	head.rotation.y = _head_yaw
	head.rotation.z = sin(_t * 0.7) * 0.06
	head.rotation.x = 0.35 if sleepy else 0.0

	# blinking
	_blink_timer -= delta
	if sleepy:
		eyes.scale.y = 0.12
	elif _blink_timer < 0.0:
		eyes.scale.y = 0.1
		if _blink_timer < -0.12:
			_blink_timer = randf_range(1.5, 5.0)
	else:
		eyes.scale.y = 1.0

	# ear twitches
	_ear_timer -= delta
	for i in ears.size():
		var target := 0.0
		if _ear_timer < 0.0 and i == int(_t) % 2:
			target = -0.6
		if _puff > 0.0:
			target = 0.9 # ears back when angry
		ears[i].rotation.z = lerpf(ears[i].rotation.z, target * (1 if i == 0 else -1), delta * 18.0)
	if _ear_timer < -0.15:
		_ear_timer = randf_range(2.0, 6.0)

	# tail sway
	for i in tail_segments.size():
		var seg := tail_segments[i]
		var phase := _t * tail_speed - i * 0.6
		seg.rotation.x = deg_to_rad(-35.0 if i == 0 else -12.0) - _puff * 0.15
		seg.rotation.y = sin(phase) * deg_to_rad(16.0 + i * 4.0) * (0.3 if sleepy else 1.0)
		# only the root segment scales: children inherit it, so scaling each one would compound
		if i == 0:
			seg.scale = Vector3.ONE * (1.0 + _puff * 0.5)

	# paw (slam / wave)
	paw_raise = move_toward(paw_raise, 0.0, delta * 2.0)
	paw.rotation.x = -paw_raise * 2.2
	paw.position.y = 0.3 + _hop + paw_raise * 0.1


func look_at_point(world_pos: Vector3) -> void:
	var local := to_local(world_pos)
	_head_target_yaw = clampf(atan2(-local.x, -local.z), -1.2, 1.2)


func look_forward() -> void:
	_head_target_yaw = 0.0


## Squash-and-stretch kick, e.g. when attacking.
func bounce(amount := 0.18) -> void:
	_squash_v += amount * 14.0


func hop(height := 3.5) -> void:
	_hop_v = height


func puff_up() -> void:
	_puff = 1.0
	bounce(0.3)


func raise_paw() -> void:
	paw_raise = 1.0
