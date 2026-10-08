class_name CatTower
extends Node3D
## The castle tower at the end of the road, with YOUR cat on top. The cat throws
## hairballs at critters that get close and reacts to everything that happens.

const TS := 2.0
const MODEL := "tiger" # Cube Pets' tiger makes a perfect big orange tabby

var game: Game
var cat: PetRig
var _cooldown := 1.0
var _target: Enemy
var _wobble := 0.0
var _body: Node3D
var _cat_pivot: Node3D
var _idle_t := 4.0
var _yaw := 0.0
var _yaw_target := 0.0


func setup(p_game: Game) -> void:
	game = p_game
	_body = Node3D.new()
	add_child(_body)
	var y := 0.0
	for piece in ["tower-round-bottom-c", "tower-round-middle-b", "tower-round-top-b"]:
		var n: Node3D = load("res://assets/models/td/%s.glb" % piece).instantiate()
		n.scale = Vector3.ONE * TS
		n.position.y = y
		_body.add_child(n)
		Toon.apply(n, true, true)
		y += (0.6 if piece != "tower-round-top-b" else 0.2) * TS
	_cat_pivot = Node3D.new()
	_cat_pivot.position.y = y
	_body.add_child(_cat_pivot)
	cat = PetRig.create(MODEL, 0.7)
	_cat_pivot.add_child(cat)


func _process(delta: float) -> void:
	_wobble = move_toward(_wobble, 0.0, delta * 2.0)
	_body.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.06 * _wobble
	_yaw = lerp_angle(_yaw, _yaw_target, 1.0 - exp(-delta * 8.0))
	_cat_pivot.global_rotation.y = _yaw
	if game == null or not game.playing:
		_idle(delta)
		return
	_cooldown -= delta
	if _target == null or not is_instance_valid(_target) or not _target.alive or _flat(_target) > game.hero_range():
		_target = _find_target()
	if _target:
		_look_at(_target.global_position)
		if _cooldown <= 0.0:
			_cooldown = 1.0 / game.hero_rate()
			_throw()
	else:
		_idle(delta)


func _look_at(p: Vector3) -> void:
	var d := p - _cat_pivot.global_position
	_yaw_target = atan2(-d.x, -d.z)


func _idle(delta: float) -> void:
	_idle_t -= delta
	if _idle_t <= 0.0:
		_idle_t = randf_range(2.0, 5.0)
		var a := randf_range(-1.0, 1.0)
		_look_at(global_position + Vector3(sin(a) * 5.0, 0, -cos(a) * 5.0))


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
	cat.bounce(0.2)
	Sfx.play("shoot_yarn", 0.7, 0.1)


func credit(_e: Enemy, _dmg: float, _killed: bool) -> void:
	pass


func hurt() -> void:
	_wobble = 1.0
	cat.puff_up()
	cat.hop(3.0)
	cat.flash(0.1)
	cat.gesture("gesture-negative")


func celebrate() -> void:
	cat.hop(5.0)
	cat.bounce(0.3)
	cat.gesture("dance", "idle", 1.3)


func slam_pose() -> void:
	cat.bounce(0.35)
	cat.gesture("gesture-positive", "idle", 1.5)
