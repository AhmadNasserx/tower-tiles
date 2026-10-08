class_name Projectile
extends Node3D
## Yarn balls, fish and hairballs. They home in on a dog along a little arc.

static var _meshes := {}

var game: Game
var source: Node # Turret or the hero cat (anything with credit())
var kind := "yarn"
var target: Enemy
var target_pos := Vector3.ZERO
var start := Vector3.ZERO
var damage := 10.0
var crit := false
var splash := 0.0
var delay := 0.0

var _t := 0.0
var _duration := 0.3
var _arc := 0.6
var _model: MeshInstance3D
var _spin := Vector3.ZERO


func setup(p_game: Game, p_source: Node, from: Vector3, p_target: Enemy, dmg: float, p_crit: bool, p_kind: String, opts: Dictionary) -> void:
	game = p_game
	source = p_source
	kind = p_kind
	target = p_target
	start = from
	damage = dmg
	crit = p_crit
	splash = opts.get("splash", 0.0)
	delay = opts.get("delay", 0.0)
	target_pos = _aim_point()
	var d := start.distance_to(target_pos)
	match kind:
		"yarn":
			_duration = clampf(d / 16.0, 0.12, 0.5)
			_arc = 0.25 + d * 0.06
			_spin = Vector3(14, 3, 0)
		"fish":
			_duration = clampf(d / 9.0, 0.45, 0.9)
			_arc = 1.6 + d * 0.2
			_spin = Vector3(9, 0, 2)
			# lead the target a little so the fish lands where the dog will be
			if target and target.alive:
				var future := minf(target.dist + target.current_speed() * _duration, target.path_len)
				target_pos = target.curve.sample_baked(future, true) + Vector3(0, 0.3, 0)
				target = null
		"hairball":
			_duration = clampf(d / 14.0, 0.15, 0.6)
			_arc = 0.8 + d * 0.08
			_spin = Vector3(8, 8, 0)
	_model = MeshKit.instance(_mesh(kind, crit), self, false)
	position = start
	visible = delay <= 0.0


func _aim_point() -> Vector3:
	if target and is_instance_valid(target) and target.alive:
		return target.global_position + Vector3(0, 0.45 * target.size, 0)
	return target_pos


static func _mesh(k: String, is_crit: bool) -> ArrayMesh:
	var key := k + ("!" if is_crit else "")
	if _meshes.has(key):
		return _meshes[key]
	var m := MeshKit.new()
	match k:
		"yarn":
			var c := Color("ffd23f") if is_crit else Color("ff5c8a")
			m.sphere(Vector3.ZERO, Vector3.ONE * 0.16, c, Vector3.ZERO, 8)
			m.torus(Vector3.ZERO, 0.13, 0.18, c.darkened(0.25), Vector3(0, 0, 40))
			m.torus(Vector3.ZERO, 0.13, 0.18, c.lightened(0.25), Vector3(60, 0, 0))
			m.cylinder(Vector3(0, -0.1, 0.18), 0.015, 0.25, c, Vector3(70, 0, 0))
		"fish":
			var body := Color("ffd23f") if is_crit else Color("5dade2")
			m.sphere(Vector3.ZERO, Vector3(0.14, 0.2, 0.32), body, Vector3.ZERO, 8)
			m.cone(Vector3(0, 0, 0.36), 0.18, 0.2, body.darkened(0.2), Vector3(-90, 0, 0), 3, 0.3)
			m.sphere(Vector3(0.1, 0.06, -0.18), Vector3.ONE * 0.04, Color("1e1a24"), Vector3.ZERO, 6)
			m.sphere(Vector3(-0.1, 0.06, -0.18), Vector3.ONE * 0.04, Color("1e1a24"), Vector3.ZERO, 6)
		"hairball":
			var hc := Color("ffd23f") if is_crit else Color("c9a27e")
			m.sphere(Vector3.ZERO, Vector3.ONE * 0.2, hc, Vector3.ZERO, 6)
			for i in 6:
				var a := TAU * i / 6.0
				m.sphere(Vector3(cos(a) * 0.14, sin(a * 2.0) * 0.08, sin(a) * 0.14), Vector3.ONE * 0.09, hc.darkened(0.15), Vector3.ZERO, 6)
	var mesh := m.build()
	_meshes[key] = mesh
	return mesh


func _process(delta: float) -> void:
	if delay > 0.0:
		delay -= delta
		if delay <= 0.0:
			visible = true
		return
	if kind != "fish":
		target_pos = _aim_point()
	_t = minf(1.0, _t + delta / _duration)
	var p := start.lerp(target_pos, _t)
	p.y += sin(_t * PI) * _arc
	position = p
	_model.rotation += _spin * delta
	if _t >= 1.0:
		_impact()


func _impact() -> void:
	if splash > 0.0:
		game.splash_damage(source, target_pos, splash, damage, crit)
		game.fx.splash(target_pos, splash)
		Sfx.play("splash")
		game.shake(0.12)
	elif target and is_instance_valid(target) and target.alive:
		var was_alive := target.alive
		target.take_damage(damage, crit)
		if is_instance_valid(source) and source.has_method("credit"):
			source.credit(target, damage, was_alive and not target.alive)
		game.fx.hit(target_pos, Color("ffd23f") if crit else (Color("ff9fb5") if kind == "yarn" else Color("e8d5b5")))
		Sfx.play("crit" if crit else "hit", 1.0, 0.15)
	else:
		game.fx.puff(target_pos, Color(1, 1, 1, 0.7), 0.4)
	queue_free()
