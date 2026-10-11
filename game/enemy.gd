class_name Enemy
extends Node3D
## A dog (or vacuum cleaner) marching down the road toward your cat.

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
var intro_hold := false # true while a boss intro shot holds it still (see Game._boss_intro)

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
var damage_taken_mult := 1.0
var heal_cooldown := 0.0

var rig: PetRig
var height := 1.0
var _model: Node3D
var _anim_t := randf() * 10.0
var _ability_t := 0.0
var _cast_t := 0.0
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
	damage_taken_mult = def.get("vuln", 1.0)
	base_speed = def.speed * randf_range(0.95, 1.05)
	gold = def.gold
	lives = def.lives
	is_boss = def.get("boss", false)
	size = def.scale
	height = 1.6 * size
	lateral = randf_range(-0.35, 0.35) * (0.3 if is_boss else 1.0)
	_ability_t = 4.0
	_build_model()
	_update_transform(0.0)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	rig = PetRig.create(def.model, size, def.tint)
	_model.add_child(rig)
	rig.play("run", 1.0)


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
	if heal_cooldown > 0.0:
		heal_cooldown -= delta
	dist += spd * delta
	_update_transform(delta)
	_animate(delta, spd)
	hp_display = move_toward(hp_display, hp / max_hp, delta * 1.5)
	if def.get("healer", false):
		_ability_t -= delta
		if _ability_t <= 0.0:
			# wind-up: stop in place, then heal once the cast finishes
			_ability_t = GameData.BUNNY_HEAL_INTERVAL
			_cast_t = GameData.BUNNY_WINDUP
			apply_stun(GameData.BUNNY_WINDUP)
		if _cast_t > 0.0:
			_cast_t -= delta
			if _cast_t <= 0.0:
				game.poodle_heal(self)
	elif is_boss:
		_ability_t -= delta
		if _ability_t <= 0.0:
			_ability_t = 6.5
			game.boss_ability(self)
	if dist >= path_len:
		_reach_cat()


## Boss intro: stops the boss in place and idles it. Cleared by Game when the shot ends.
func begin_intro_hold() -> void:
	intro_hold = true
	rig.play("idle", 1.0)


## Boss intro roar: the rig puffs up and gestures. Does nothing once the boss is dead.
func roar() -> void:
	if alive:
		rig.roar()


## Flat unit vector the enemy walks toward, which is the front of its model.
func facing() -> Vector3:
	return _dir


func current_speed() -> float:
	if stun_time > 0.0 or intro_hold:
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
	if intro_hold:
		# keep whatever pose begin_intro_hold / roar set; no wobble
		rig.rotation.z = 0.0
		return
	if stun_time > 0.0:
		rig.play("idle", 1.0)
		rig.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.15
		return
	rig.rotation.z = 0.0
	# match the run cycle to how fast we're actually moving
	var cycle := spd / maxf(base_speed, 0.01)
	if haste_time > 0.0:
		rig.play("run", 2.0 * cycle)
	elif spd < base_speed * 0.75:
		rig.play("walk", 1.6 * cycle)
	else:
		rig.play("run", (1.1 if not is_boss else 0.8) * cycle)


# ------------------------------------------------------------------ combat
func progress() -> float:
	return dist


func take_damage(amount: float, crit := false, show_number := true) -> void:
	if not alive:
		return
	var dmg := amount * damage_taken_mult
	var real := maxf(dmg * 0.2, dmg - armor)
	hp -= real
	last_hit_time = Time.get_ticks_msec() / 1000.0
	_flash()
	_squish = 1.0
	if show_number:
		game.overlay.damage_number(global_position + Vector3(0, height + 0.3, 0), real, crit)
	game.stats_damage += real
	if hp <= 0.0:
		die()


func _flash() -> void:
	rig.flash()
	rig.bounce(0.12)


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
	rig.play("idle", 2.0, 0.0)
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
