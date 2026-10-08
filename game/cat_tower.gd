class_name CatTower
extends Node3D
## The cat tree at the end of the road, with YOUR cat on top. The cat throws
## hairballs at dogs that get close and reacts to everything that happens.

const TOP := 3.35

var game: Game
var cat: CatRig
var _cooldown := 1.0
var _target: Enemy
var _wobble := 0.0
var _body: Node3D
var _idle_t := 4.0


func setup(p_game: Game, fur := Color("ff8a3d")) -> void:
	game = p_game
	_body = Node3D.new()
	add_child(_body)
	MeshKit.instance(_tower_mesh(), _body)
	cat = CatRig.create(fur, "tabby", Color("7bd389"))
	cat.position = Vector3(0, TOP, 0.1)
	cat.scale = Vector3.ONE * 1.6
	_body.add_child(cat)


func _tower_mesh() -> ArrayMesh:
	var rope := Color("d9b48f")
	var carpet := Color("a66cff")
	var carpet2 := Color("ff7eb6")
	var k := MeshKit.new()
	k.cylinder(Vector3(0, 0.12, 0), 1.25, 0.24, carpet.darkened(0.2), Vector3.ZERO, 0.95, 16)
	# little cube house with a round door
	k.box(Vector3(0, 0.85, 0), Vector3(1.5, 1.25, 1.5), carpet2)
	k.sphere(Vector3(0, 0.8, -0.76), Vector3(0.42, 0.42, 0.04), Color("2a1f33"))
	k.box(Vector3(0, 1.52, 0), Vector3(1.65, 0.12, 1.65), carpet.darkened(0.1))
	# posts
	for sx in [-1, 1]:
		k.cylinder(Vector3(0.48 * sx, 2.3, 0.35), 0.17, 1.6, rope)
		for i in 7:
			k.cylinder(Vector3(0.48 * sx, 1.65 + i * 0.2, 0.35), 0.18, 0.04, rope.darkened(0.15))
	k.cylinder(Vector3(0, 2.3, -0.35), 0.17, 1.6, rope)
	# hanging toy
	k.cylinder(Vector3(0.85, 2.7, -0.4), 0.012, 0.8, Color("fff4e0"))
	k.sphere(Vector3(0.85, 2.25, -0.4), Vector3.ONE * 0.14, Color("ffd23f"), Vector3.ZERO, 8)
	# top bed
	k.cylinder(Vector3(0, 3.15, 0.05), 1.0, 0.18, carpet, Vector3.ZERO, 1.0, 16)
	k.torus(Vector3(0, 3.28, 0.05), 0.75, 1.0, carpet2)
	return k.build()


func _process(delta: float) -> void:
	_wobble = move_toward(_wobble, 0.0, delta * 2.0)
	_body.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.06 * _wobble
	if game == null or not game.playing:
		_idle(delta)
		return
	_cooldown -= delta
	if _target == null or not is_instance_valid(_target) or not _target.alive or _flat(_target) > game.hero_range():
		_target = _find_target()
	if _target:
		cat.look_at_point(_target.global_position)
		if _cooldown <= 0.0:
			_cooldown = 1.0 / game.hero_rate()
			_throw()
	else:
		_idle(delta)


func _idle(delta: float) -> void:
	_idle_t -= delta
	if _idle_t <= 0.0:
		_idle_t = randf_range(2.0, 5.0)
		var a := randf_range(-1.0, 1.0)
		cat.look_at_point(global_position + Vector3(sin(a) * 5.0, 0, -cos(a) * 5.0))


func _flat(e: Enemy) -> float:
	var d := e.global_position - global_position
	return Vector2(d.x, d.z).length()


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e: Enemy in game.enemies:
		if not e.alive:
			continue
		var d := _flat(e)
		if d <= game.hero_range() and d < best_d:
			best_d = d
			best = e
	return best


func _throw() -> void:
	var crit: bool = game.roll_crit()
	var dmg: float = game.hero_damage() * (2.5 if crit else 1.0)
	var from := cat.global_position + Vector3(0, 1.0, -0.3)
	game.spawn_projectile(self, from, _target, dmg, crit, "hairball", {})
	cat.raise_paw()
	cat.bounce(0.2)
	Sfx.play("shoot_yarn", 0.7, 0.1)


func credit(_e: Enemy, _dmg: float, _killed: bool) -> void:
	pass


func hurt() -> void:
	_wobble = 1.0
	cat.puff_up()
	cat.hop(3.0)


func celebrate() -> void:
	cat.hop(5.0)
	cat.bounce(0.3)


func slam_pose() -> void:
	cat.raise_paw()
	cat.bounce(0.35)
