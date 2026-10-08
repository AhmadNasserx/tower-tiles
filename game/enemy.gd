class_name Enemy
extends Node3D
## A dog (or vacuum cleaner) marching down the road toward your cat.

static var _mesh_cache := {}

var game: Game
var type := "pup"
var def: Dictionary
var max_hp := 10.0
var hp := 10.0
var armor := 0.0
var base_speed := 3.0
var gold := 1
var lives := 1
var is_boss := false
var size := 1.0

var curve: Curve3D
var path_len := 1.0
var dist := 0.0
var lateral := 0.0
var alive := true

var slow_amount := 0.0
var slow_time := 0.0
var stun_time := 0.0
var haste_time := 0.0
var hp_display := 1.0
var last_hit_time := -10.0

var _model: Node3D
var _body: MeshInstance3D
var _tail: Node3D
var _brush: Node3D
var _anim_t := randf() * 10.0
var _flash_t := 0.0
var _ability_t := 0.0
var _dir := Vector3.FORWARD
var _squish := 0.0


func setup(p_game: Game, p_type: String, p_curve: Curve3D, wave_hp_mult: float) -> void:
	game = p_game
	type = p_type
	def = GameData.ENEMIES[type]
	curve = p_curve
	path_len = curve.get_baked_length()
	max_hp = def.hp * wave_hp_mult
	hp = max_hp
	armor = def.armor
	base_speed = def.speed * randf_range(0.95, 1.05)
	gold = def.gold
	lives = def.lives
	is_boss = def.get("boss", false)
	size = def.size * 1.55
	lateral = randf_range(-0.35, 0.35) * (0.3 if is_boss else 1.0)
	_ability_t = 4.0
	_build_model()
	_update_transform(0.0)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var meshes := _meshes_for(type)
	_body = MeshKit.instance(meshes.body, _model)
	_body.scale = Vector3.ONE * size
	if meshes.has("tail"):
		_tail = Node3D.new()
		_body.add_child(_tail)
		_tail.position = meshes.tail_pos
		MeshKit.instance(meshes.tail, _tail, false)
	if meshes.has("brush"):
		_brush = Node3D.new()
		_brush.position = Vector3(0, 0.04, 0)
		_body.add_child(_brush)
		MeshKit.instance(meshes.brush, _brush, false)


static func _meshes_for(t: String) -> Dictionary:
	if _mesh_cache.has(t):
		return _mesh_cache[t]
	var d: Dictionary = GameData.ENEMIES[t]
	var out: Dictionary
	if d.get("robot", false):
		out = _vacuum_meshes(d)
	else:
		out = _dog_meshes(d)
	_mesh_cache[t] = out
	return out


static func _dog_meshes(d: Dictionary) -> Dictionary:
	var coat: Color = d.coat
	var ear: Color = d.ear
	var snout := coat.lightened(0.35)
	var ink := Color("1e1a24")
	var slim: bool = d.get("slim", false)
	var chunky: bool = d.get("chunky", false)
	var healer: bool = d.get("healer", false)
	var boss: bool = d.get("boss", false)
	var w := 0.2 if slim else (0.36 if chunky else 0.27)
	var leg_h := 0.46 if slim else (0.26 if chunky else 0.34)
	var body_y := leg_h + 0.14
	var k := MeshKit.new()
	# body
	k.sphere(Vector3(0, body_y, 0), Vector3(w, 0.24 if not chunky else 0.28, 0.44 if slim else 0.4), coat)
	# legs
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var lp := Vector3(sx * w * 0.6, leg_h * 0.5, sz * 0.24)
			k.cylinder(lp, 0.06 if slim else 0.08, leg_h, coat)
			k.sphere(Vector3(lp.x, 0.04, lp.z - 0.03), Vector3(0.08, 0.05, 0.1), snout)
			if healer:
				k.sphere(Vector3(lp.x, 0.12, lp.z), Vector3.ONE * 0.11, Color("fff0f7"))
	# head
	var hy := body_y + 0.24
	var hz := -0.42 if not slim else -0.48
	k.sphere(Vector3(0, hy, hz), Vector3(0.24, 0.22, 0.23) * (1.15 if chunky else 1.0), coat)
	var snout_len := 0.2 if slim else (0.08 if chunky else 0.14)
	k.sphere(Vector3(0, hy - 0.07, hz - 0.16 - snout_len * 0.4), Vector3(0.13 if not chunky else 0.19, 0.1, snout_len + 0.05), snout)
	k.sphere(Vector3(0, hy - 0.02, hz - 0.2 - snout_len), Vector3(0.055, 0.045, 0.045), ink)
	# eyes + angry brows
	var eye_c := Color("ff3355") if boss else ink
	for sx in [-1, 1]:
		k.sphere(Vector3(0.1 * sx, hy + 0.06, hz - 0.19), Vector3(0.04, 0.045, 0.03), eye_c)
		k.box(Vector3(0.1 * sx, hy + 0.13, hz - 0.18), Vector3(0.11, 0.03, 0.03), ink, Vector3(0, 0, -22 * sx))
	# ears
	if slim or boss:
		for sx in [-1, 1]:
			k.cone(Vector3(0.13 * sx, hy + 0.2, hz + 0.02), 0.08, 0.2, ear, Vector3(0, 45, 18 * -sx), 4)
	else:
		for sx in [-1, 1]:
			k.box(Vector3(0.22 * sx, hy - 0.02, hz + 0.02), Vector3(0.07, 0.26, 0.15), ear, Vector3(0, 0, 18 * sx))
	if chunky:
		# jowls + spiked collar
		k.sphere(Vector3(0.1, hy - 0.13, hz - 0.12), Vector3(0.1, 0.08, 0.08), snout)
		k.sphere(Vector3(-0.1, hy - 0.13, hz - 0.12), Vector3(0.1, 0.08, 0.08), snout)
	if healer:
		k.sphere(Vector3(0, hy + 0.24, hz + 0.02), Vector3.ONE * 0.16, Color("fff0f7"))
		k.box(Vector3(0, hy + 0.47, hz), Vector3(0.05, 0.16, 0.05), GameData.C_GREEN)
		k.box(Vector3(0, hy + 0.47, hz), Vector3(0.16, 0.05, 0.05), GameData.C_GREEN)
	# collar
	var collar := Color("e63946") if not boss else Color("2a2c35")
	k.torus(Vector3(0, hy - 0.16, hz + 0.1), 0.14 if not chunky else 0.2, 0.2 if not chunky else 0.27, collar, Vector3(70, 0, 0))
	if chunky or boss:
		for i in 6:
			var a := TAU * i / 6.0
			var p := Vector3(cos(a) * 0.24, hy - 0.16 + sin(a) * 0.08, hz + 0.1 + sin(a) * 0.2)
			k.cone(p, 0.04, 0.09, Color("d8dee9"), Vector3(0, 0, rad_to_deg(-a) + 90), 4)
	else:
		k.sphere(Vector3(0, hy - 0.24, hz - 0.03), Vector3.ONE * 0.04, GameData.C_GOLD)
	if boss:
		# a mohawk of spiky fur
		for i in 4:
			k.cone(Vector3(0, body_y + 0.2, -0.2 + i * 0.15), 0.07, 0.22, ear, Vector3(-20, 0, 0), 4)
	var out := {"body": k.build()}
	var tk := MeshKit.new()
	tk.cylinder(Vector3(0, 0.12, 0), 0.045, 0.25, coat, Vector3.ZERO, 0.6, 6)
	if healer:
		tk.sphere(Vector3(0, 0.27, 0), Vector3.ONE * 0.1, Color("fff0f7"), Vector3.ZERO, 6)
	out.tail = tk.build()
	out.tail_pos = Vector3(0, body_y + 0.12, 0.38 if not slim else 0.42)
	return out


static func _vacuum_meshes(d: Dictionary) -> Dictionary:
	var shell: Color = d.coat
	var dark: Color = d.ear
	var k := MeshKit.new()
	k.cylinder(Vector3(0, 0.25, 0), 0.62, 0.3, shell, Vector3.ZERO, 0.92, 16)
	k.torus(Vector3(0, 0.15, 0), 0.55, 0.7, dark)
	k.cylinder(Vector3(0, 0.45, 0.05), 0.4, 0.12, Color("d8dee9"), Vector3.ZERO, 0.85, 14)
	k.sphere(Vector3(0, 0.52, 0.05), Vector3(0.28, 0.12, 0.28), Color("30303a"))
	# angry LED face
	for sx in [-1, 1]:
		k.box(Vector3(0.12 * sx, 0.56, -0.12), Vector3(0.1, 0.04, 0.06), Color("ff3355"), Vector3(0, 0, -20 * sx))
	k.box(Vector3(0, 0.33, -0.6), Vector3(0.5, 0.08, 0.06), Color("ffd23f"))
	# handle / antenna
	k.cylinder(Vector3(0, 0.75, 0.25), 0.03, 0.5, dark)
	k.sphere(Vector3(0, 1.0, 0.25), Vector3.ONE * 0.07, Color("ff3355"))
	var bk := MeshKit.new()
	for i in 3:
		bk.box(Vector3.ZERO, Vector3(1.1, 0.03, 0.08), Color("ffd23f"), Vector3(0, i * 60, 0))
	return {"body": k.build(), "brush": bk.build()}


# ------------------------------------------------------------------ update
func _process(delta: float) -> void:
	if not alive:
		return
	var spd := current_speed()
	if stun_time > 0.0:
		stun_time -= delta
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_amount = 0.0
	if haste_time > 0.0:
		haste_time -= delta
	dist += spd * delta
	_update_transform(delta)
	_animate(delta, spd)
	hp_display = move_toward(hp_display, hp / max_hp, delta * 1.5)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_body.material_override = null
	if def.get("healer", false):
		_ability_t -= delta
		if _ability_t <= 0.0:
			_ability_t = 2.5
			game.poodle_heal(self)
	elif is_boss:
		_ability_t -= delta
		if _ability_t <= 0.0:
			_ability_t = 6.5
			game.boss_ability(self)
	if dist >= path_len:
		_reach_cat()


func current_speed() -> float:
	if stun_time > 0.0:
		return 0.0
	var s := base_speed * (1.0 - slow_amount)
	if haste_time > 0.0:
		s *= 1.3
	return s


func _update_transform(delta: float) -> void:
	var d := clampf(dist, 0.0, path_len)
	var p := curve.sample_baked(d, true)
	var ahead := curve.sample_baked(minf(d + 0.4, path_len), true)
	var dir := ahead - p
	dir.y = 0
	if dir.length_squared() > 0.0001:
		_dir = dir.normalized()
	var side := Vector3(-_dir.z, 0, _dir.x)
	# fade lateral offset near the cat so everyone funnels into the tower
	var lat := lateral * clampf((path_len - d) / 3.0, 0.0, 1.0)
	position = p + side * lat
	var yaw := atan2(-_dir.x, -_dir.z)
	if delta == 0.0:
		_model.rotation.y = yaw
	else:
		_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-delta * 10.0))


func _animate(delta: float, spd: float) -> void:
	_squish = move_toward(_squish, 0.0, delta * 4.0)
	if def.get("robot", false):
		_brush.rotation.y += delta * 14.0
		_body.position.y = sin(_anim_t * 20.0) * 0.015
		_anim_t += delta
		_body.rotation.z = sin(_anim_t * 3.0) * 0.04
		return
	var gait := spd * (3.2 if not is_boss else 1.6) / size
	_anim_t += delta * gait
	var hop_phase := absf(sin(_anim_t))
	_body.position.y = hop_phase * 0.16 * size
	var stretch := 1.0 + (hop_phase - 0.5) * 0.14 - _squish * 0.3
	_body.scale = Vector3(size * (2.0 - stretch) , size * stretch, size)
	_body.rotation.x = cos(_anim_t) * 0.12
	if _tail:
		_tail.rotation.x = -0.6
		_tail.rotation.z = sin(_anim_t * 2.6) * 0.7
	if stun_time > 0.0:
		_body.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.15


# ------------------------------------------------------------------ combat
func progress() -> float:
	return dist


func take_damage(amount: float, crit := false, show_number := true) -> void:
	if not alive:
		return
	var real := maxf(amount * 0.2, amount - armor)
	hp -= real
	last_hit_time = Time.get_ticks_msec() / 1000.0
	_flash()
	_squish = 1.0
	if show_number:
		game.overlay.damage_number(global_position + Vector3(0, 1.0 * size + 0.4, 0), real, crit)
	game.stats_damage += real
	if hp <= 0.0:
		die()


func _flash() -> void:
	_body.material_override = MeshKit.flash_material()
	_flash_t = 0.06


func apply_slow(amount: float, time: float) -> void:
	var resist := 0.5 if is_boss else 1.0
	slow_amount = maxf(slow_amount, amount * resist)
	slow_time = maxf(slow_time, time)


func apply_stun(time: float) -> void:
	if is_boss:
		time *= 0.3
	stun_time = maxf(stun_time, time)


func heal(frac: float) -> void:
	if not alive:
		return
	var amt := max_hp * frac
	hp = minf(max_hp, hp + amt)


func die() -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	game.on_enemy_killed(self)
	_body.material_override = null
	# Bonk! Launch the dog off the screen spinning, then poof.
	var tw := create_tween().set_parallel()
	var fly := Vector3(randf_range(-1.5, 1.5), 3.5 if not is_boss else 1.5, randf_range(-1.5, 1.5))
	tw.tween_property(_model, "position", fly, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "rotation", _model.rotation + Vector3(randf_range(4, 8), randf_range(-6, 6), randf_range(3, 6)), 0.45)
	tw.tween_property(_model, "scale", Vector3.ONE * 0.2, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		game.fx.puff(global_position + fly, Color(1, 1, 1), 1.0 if not is_boss else 2.5)
		queue_free())


func _reach_cat() -> void:
	alive = false
	game.on_enemy_leaked(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
