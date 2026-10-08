class_name Turret
extends Node3D
## A kitten on a little castle tower. Behaviour is driven by GameData.TURRETS.
## Models: Kenney Tower Defense Kit + Cube Pets (CC0), drawn with the toon shader.

const MAX_LEVEL := 3
const TS := 1.7 # tower kit -> world scale (a kit tile is 1 unit, ours are 2)
const TD := "res://assets/models/td/"

# Tower pieces per level (bottom to top) and the kitten + weapon on top.
const STYLE := {
	"yarn": {"bottom": "tower-round-bottom-a", "weapon": "weapon-ballista", "pet": "cat", "tint": Color(1, 1, 1), "muzzle": Vector3(0, 0.3, -0.42)},
	"fish": {"bottom": "tower-round-bottom-b", "weapon": "weapon-cannon", "pet": "cat", "tint": Color(1.45, 0.95, 0.55), "muzzle": Vector3(0, 0.3, -0.4)},
	"laser": {"bottom": "tower-round-bottom-c", "weapon": "weapon-turret", "pet": "cat", "tint": Color(1.4, 1.4, 1.5), "muzzle": Vector3(0, 0.32, -0.36)},
	"hiss": {"bottom": "tower-round-bottom-b", "weapon": "", "pet": "cat", "tint": Color(0.42, 0.38, 0.5), "muzzle": Vector3(0, 0.5, 0)},
	"fatcat": {"bottom": "", "weapon": "", "pet": "lion", "tint": Color(1, 1, 1), "muzzle": Vector3(0, 0.5, 0)},
}

# Kit -> world scale for weapons, and the kittens that man them. Sized so
# kitten + weapon fit on the tower's deck (radius ~0.78) at any angle.
const WEAPON_SCALE := 1.05
const KITTEN_SCALE := 0.42
const CREW_GAP := 0.14 # space between the weapon's back and the kitten's nose
const DECK_COLOR := Color("b9835a")
const FLAG_RADIUS := 0.8 # just outside the top tier's wall (outer radius 0.78)

static var _scenes := {}

var game: Game
var type := "yarn"
var def: Dictionary
var level := 0
var cell := Vector2i.ZERO
var invested := 0
var target_mode := 0
var kills := 0
var damage_done := 0.0
var jammed := 0.0

var cat: PetRig
var _turn: Node3D
var _stack: Node3D
var _top_y := 0.0
var _weapon: Node3D
var _muzzle: Node3D
var _cooldown := 0.5
var _target: Enemy
var _retarget_t := 0.0
var _beams: Array[MeshInstance3D] = []
var _beam_dot: MeshInstance3D
var _ramp := 1.0
var _beam_acc := {}
var _beam_tick := 0.0
var _snore_t := 3.0
var _dizzy: Node3D


func setup(p_game: Game, p_type: String, p_cell: Vector2i) -> void:
	game = p_game
	type = p_type
	def = GameData.TURRETS[type]
	cell = p_cell
	_build()


func lvl() -> Dictionary:
	return def.levels[level]


func is_max() -> bool:
	return level >= MAX_LEVEL


func upgrade_cost() -> int:
	if is_max():
		return 0
	return game.price(def.levels[level + 1].up)


func sell_value() -> int:
	return int(invested * GameData.SELL_REFUND)


# ------------------------------------------------------------------ stats
func get_range() -> float:
	return float(lvl().range) * game.range_mult


func get_rate() -> float:
	var r: float = lvl().get("rate", 1.0) * game.rate_mult
	if game.zoomies_time > 0.0:
		r *= 2.0
	return r


func get_damage() -> float:
	var d: float = lvl().get("dmg", lvl().get("dps", 0.0)) * game.dmg_mult
	match type:
		"fish":
			d *= 1.0 + 0.2 * game.perk("hotfish")
		"laser":
			d *= 1.0 + 0.25 * game.perk("focus")
		"hiss":
			d *= 1.0 + 1.0 * game.perk("frost")
	return d


func get_income() -> int:
	return int(round(lvl().get("income", 0) * (1.0 + 0.35 * game.perk("fatter"))))


func describe_stats() -> String:
	var l := lvl()
	match def.kind:
		"projectile":
			var shots := int(l.get("multishot", 1)) + game.perk("yarnstorm")
			return "Damage %d  x%d   Speed %.1f/s   Range %.1f" % [get_damage(), shots, get_rate(), get_range()]
		"lob":
			return "Damage %d   Splash %.1f   Speed %.1f/s   Range %.1f" % [get_damage(), splash_radius(), get_rate(), get_range()]
		"beam":
			return "DPS %d (up to x%.1f)   Range %.1f%s" % [get_damage(), l.ramp, get_range(), "   Chains 2" if l.has("chain") else ""]
		"pulse":
			return "Damage %d   Slow %d%%   Range %.1f%s" % [get_damage(), int(slow_amount() * 100), get_range(), "   Stuns!" if l.has("stun") else ""]
		"income":
			return "Pays %d gold after each wave" % get_income()
	return ""


func splash_radius() -> float:
	return float(lvl().get("splash", 0.0)) * (1.0 + 0.3 * game.perk("hotfish"))


func slow_amount() -> float:
	return minf(0.8, float(lvl().get("slow", 0.0)) + 0.15 * game.perk("frost"))


# ------------------------------------------------------------------ visuals
static func _piece(piece: String) -> Node3D:
	if not _scenes.has(piece):
		_scenes[piece] = load(TD + piece + ".glb")
	var n: Node3D = _scenes[piece].instantiate()
	return n


func _build() -> void:
	var st: Dictionary = STYLE[type]
	_stack = Node3D.new()
	add_child(_stack)
	_turn = Node3D.new()
	_turn.rotation.y = PI # face the camera until there is something to look at
	add_child(_turn)
	_weapon = Node3D.new()
	_turn.add_child(_weapon)
	var w: Node3D = null
	if st.weapon != "":
		w = _piece(st.weapon)
		w.rotation.y = PI
		w.scale = Vector3.ONE * WEAPON_SCALE
		_weapon.add_child(w)
		Toon.apply(w, true, true)
	_muzzle = Node3D.new()
	_weapon.add_child(_muzzle)
	_muzzle.position = st.muzzle * WEAPON_SCALE
	match type:
		"hiss":
			# a spooky black cat, all puffed up
			cat = PetRig.create("cat", 0.46, st.tint)
		"fatcat":
			cat = PetRig.create("lion", 0.62)
			cat.play("idle", 0.4)
		_:
			cat = PetRig.create(st.pet, KITTEN_SCALE, st.tint)
	_turn.add_child(cat)
	if w:
		_layout_crew(w)
	_rebuild_stack()
	if def.kind == "beam":
		for i in 3:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.07, 0.07, 1.0)
			bm.material = MeshKit.color_material(Color(1.0, 0.25, 0.35), true)
			b.mesh = bm
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.top_level = true
			b.visible = false
			add_child(b)
			_beams.append(b)
		_beam_dot = MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = 0.14
		dm.height = 0.28
		dm.material = MeshKit.color_material(Color(1, 0.2, 0.3), true)
		_beam_dot.mesh = dm
		_beam_dot.top_level = true
		_beam_dot.visible = false
		_beam_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_beam_dot)


## Places weapon and kitten from their real mesh bounds: the weapon's back
## edge ends CREW_GAP in front of the kitten's nose, and the pair is centred
## on the tower. Both turn together, so they can never overlap.
func _layout_crew(w: Node3D) -> void:
	var cat_box := _bounds(cat, _turn)
	var w_box := _bounds(w, _turn)
	cat.position.z = CREW_GAP * 0.5 - cat_box.position.z
	_weapon.position.z = -CREW_GAP * 0.5 - w_box.end.z
	# centre on the body (front of weapon .. back of the kitten's body, tail excluded)
	var front := _weapon.position.z + w_box.position.z
	var back := cat.position.z + cat_box.position.z + cat_box.size.z * 0.6
	var shift := -(front + back) * 0.5
	cat.position.z += shift
	_weapon.position.z += shift


## Merged mesh AABB of `node` in the space of `space` (ignores outline hulls).
static func _bounds(node: Node3D, space: Node3D) -> AABB:
	var out := [null]
	_bounds_rec(node, space.global_transform.affine_inverse() * node.global_transform if node.is_inside_tree() else _rel(node, space), out)
	return out[0] if out[0] != null else AABB()


static func _rel(node: Node3D, space: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != space:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _bounds_rec(n: Node, xf: Transform3D, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and not n.has_meta("outline"):
		var b: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
		out[0] = b if out[0] == null else (out[0] as AABB).merge(b)
	for c in n.get_children():
		if c is Node3D:
			_bounds_rec(c, xf * (c as Node3D).transform, out)


## Stacks tower pieces for the current level and puts the kitten on top.
func _rebuild_stack() -> void:
	for c in _stack.get_children():
		c.queue_free()
	var st: Dictionary = STYLE[type]
	var pieces: Array = []
	match type:
		"fatcat":
			pieces = ["tower-round-base"]
		_:
			# always a proper castle tower: battlements on top, one more floor per level
			pieces = [st.bottom]
			for i in mini(level, 2):
				pieces.append("tower-round-middle-a" if i == 0 else "tower-round-middle-b")
			pieces.append("tower-round-top-a")
	var y := 0.0
	var heights := {"tower-round-base": 0.21, "tower-round-top-a": 0.5}
	for p in pieces:
		var n := _piece(p)
		n.scale = Vector3.ONE * TS
		n.position.y = y
		_stack.add_child(n)
		Toon.apply(n, true, true)
		y += heights.get(p, 0.6) * TS
	_top_y = y
	if type != "fatcat":
		# a wooden deck flush with the battlement tops: the crew stands on it,
		# so nothing they do (turning, hopping, recoil) can clip the walls
		var k := MeshKit.new()
		k.cylinder(Vector3(0, -0.04, 0), 0.32 * TS, 0.08, DECK_COLOR, Vector3.ZERO, 1.0, 16)
		for i in 4:
			k.box(Vector3(0, 0.002, (i - 1.5) * 0.13 * TS), Vector3(0.6 * TS, 0.004, 0.012 * TS), DECK_COLOR.darkened(0.25))
		var deck := MeshKit.instance(k.build(), _stack, false)
		deck.position.y = y
		Toon.apply(deck, false, false)
	if type == "fatcat":
		_add_coin_pile()
		_turn.position = Vector3(0, y, 0)
		cat.base_scale = 0.55 + level * 0.07
		cat.scale = Vector3.ONE * cat.base_scale
	else:
		_turn.position = Vector3(0, y, 0)
	if level >= MAX_LEVEL and type != "fatcat":
		_add_flag(y)


func _add_coin_pile() -> void:
	var k := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 10 + level * 6
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.55)
		k.cylinder(Vector3(cos(a) * r, 0.04 + rng.randf() * (0.1 + level * 0.05), sin(a) * r), 0.13, 0.04, GameData.C_GOLD,
			Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 1.0, 10)
	var mi := MeshKit.instance(k.build(), _stack)
	mi.position.y = _top_y
	Toon.apply(mi, true, false, true)


## Max-level banner: a gold pennant hanging down the front of the top tier.
## It sits entirely below the deck, so the crew above can never touch it.
func _add_flag(y: float) -> void:
	var k := MeshKit.new()
	var gold := GameData.C_GOLD
	k.box(Vector3(0, -0.06, 0), Vector3(0.5, 0.08, 0.06), Color("6b5d73")) # rod
	k.box(Vector3(0, -0.36, 0), Vector3(0.4, 0.52, 0.03), gold)
	k.cone(Vector3(0, -0.66, 0), 0.2, 0.18, gold, Vector3(180, 45, 0), 4, 0.08)
	k.sphere(Vector3(0, -0.36, 0.03), Vector3(0.09, 0.09, 0.02), Color("e8484f"), Vector3.ZERO, 8)
	var mi := MeshKit.instance(k.build(), _stack, false)
	mi.position = Vector3(0, y - 0.04, FLAG_RADIUS) # +Z faces the camera
	Toon.apply(mi, true, false, true)


# ------------------------------------------------------------------ logic
func _process(delta: float) -> void:
	if game == null: # portrait / preview copies have no game to fight in
		return
	if jammed > 0.0:
		jammed -= delta
		_set_beams_visible(false)
		_dizzy_spin(delta)
		return
	elif _dizzy:
		_dizzy.queue_free()
		_dizzy = null
	match def.kind:
		"income":
			_snore_t -= delta
			if _snore_t <= 0.0:
				_snore_t = randf_range(3.0, 6.0)
				game.fx.floating_text(global_position + Vector3(0.3, 1.6, 0), "z", Color(1, 1, 1, 0.9), 0.7)
			return
		"beam":
			_process_beam(delta)
			return
	_retarget_t -= delta
	if _retarget_t <= 0.0 or _target == null or not _valid(_target):
		_retarget_t = 0.15
		_target = _find_target(get_range())
	if _target:
		_face(_target.global_position, delta)
	_cooldown -= delta
	if _cooldown <= 0.0 and _target:
		_cooldown = 1.0 / get_rate()
		_fire()


func _face(world: Vector3, delta: float) -> void:
	var to := world - global_position
	var yaw := atan2(-to.x, -to.z)
	_turn.rotation.y = lerp_angle(_turn.rotation.y, yaw, 1.0 - exp(-delta * 14.0))


func _valid(e: Enemy) -> bool:
	if not is_instance_valid(e) or not e.alive:
		return false
	return _flat_dist(e.global_position) <= get_range()


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _find_target(rng: float, exclude: Array = []) -> Enemy:
	var best: Enemy = null
	var best_score := -INF
	for e: Enemy in game.enemies:
		if not e.alive or e in exclude:
			continue
		var d := _flat_dist(e.global_position)
		if d > rng:
			continue
		var score := 0.0
		match target_mode:
			0: score = e.dist
			1: score = -e.dist
			2: score = e.hp
			3: score = -d
		if score > best_score:
			best_score = score
			best = e
	return best


func _fire() -> void:
	match def.kind:
		"projectile":
			var shots := int(lvl().get("multishot", 1)) + game.perk("yarnstorm")
			var targets: Array = [_target]
			for i in shots - 1:
				var extra := _find_target(get_range(), targets)
				targets.append(extra if extra else _target)
			for i in targets.size():
				var dmg := get_damage()
				var crit := game.roll_crit()
				game.spawn_projectile(self, _muzzle.global_position, targets[i], dmg * (2.5 if crit else 1.0), crit, "yarn", {"delay": i * 0.08})
			cat.bounce(0.15)
			Sfx.play("shoot_yarn", 1.1, 0.12)
		"lob":
			var crit2 := game.roll_crit()
			game.spawn_projectile(self, _muzzle.global_position, _target, get_damage() * (2.5 if crit2 else 1.0), crit2, "fish", {"splash": splash_radius()})
			cat.bounce(0.25)
			_recoil()
			Sfx.play("shoot_fish")
			game.fx.puff(_muzzle.global_position, Color(1, 1, 1, 0.8), 0.4)
		"pulse":
			_pulse()


func _recoil() -> void:
	var tw := create_tween()
	_weapon.scale = Vector3(1.25, 0.8, 1.25)
	tw.tween_property(_weapon, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _pulse() -> void:
	var rng := get_range()
	var l := lvl()
	var hit_any := false
	for e: Enemy in game.enemies.duplicate():
		if not e.alive or _flat_dist(e.global_position) > rng:
			continue
		hit_any = true
		var crit := game.roll_crit()
		var dmg := get_damage() * (2.5 if crit else 1.0)
		e.apply_slow(slow_amount(), l.slow_time)
		if l.has("stun"):
			e.apply_stun(l.stun)
		_deal(e, dmg, crit)
	if hit_any:
		cat.puff_up()
		_recoil()
		game.fx.ring(global_position + Vector3(0, 0.3, 0), rng, def.accent)
		Sfx.play("hiss", 1.0, 0.15)


func _deal(e: Enemy, dmg: float, crit: bool, show_number := true) -> void:
	var was_alive := e.alive
	e.take_damage(dmg, crit, show_number)
	damage_done += dmg
	if was_alive and not e.alive:
		kills += 1


func credit(e: Enemy, dmg: float, killed: bool) -> void:
	damage_done += dmg
	if killed:
		kills += 1


# --------------------------------------------------------------- laser
func _process_beam(delta: float) -> void:
	var rng := get_range()
	if _target == null or not _valid(_target):
		var nt := _find_target(rng)
		if nt != _target:
			_ramp = 1.0
		_target = nt
	if _target == null:
		_set_beams_visible(false)
		return
	_face(_target.global_position, delta)
	var l := lvl()
	var ramp_speed := 0.6 * (1.0 + game.perk("focus"))
	_ramp = minf(float(l.ramp), _ramp + delta * ramp_speed)
	var targets: Array = [_target]
	if l.has("chain"):
		for i in int(l.chain):
			var last: Enemy = targets[targets.size() - 1]
			var best: Enemy = null
			var bd := 3.5
			for e: Enemy in game.enemies:
				if not e.alive or e in targets:
					continue
				var d := e.global_position.distance_to(last.global_position)
				if d < bd:
					bd = d
					best = e
			if best == null:
				break
			targets.append(best)
	var from := _muzzle.global_position
	var dps := get_damage() * _ramp
	for i in _beams.size():
		var b := _beams[i]
		if i < targets.size():
			var e: Enemy = targets[i]
			var to := e.global_position + Vector3(0, 0.5 * e.height, 0)
			_aim_beam(b, from, to, 1.0 + (_ramp - 1.0) * 0.6)
			b.visible = true
			var share := 1.0 if i == 0 else 0.5
			_beam_acc[e] = float(_beam_acc.get(e, 0.0)) + dps * share * delta
			from = to
		else:
			b.visible = false
	_beam_dot.visible = true
	_beam_dot.global_position = _target.global_position + Vector3(0, 0.5 * _target.height, 0)
	_beam_dot.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.25) * (0.8 + _ramp * 0.3)
	_beam_tick -= delta
	if _beam_tick <= 0.0:
		_beam_tick = 0.25
		for e in _beam_acc.keys():
			if is_instance_valid(e) and e.alive:
				var crit := game.roll_crit()
				_deal(e, _beam_acc[e] * (2.5 if crit else 1.0), crit)
		_beam_acc.clear()
		Sfx.play("zap", 0.8 + _ramp * 0.25, 0.05, -4.0)
		cat.bounce(0.05)


func _aim_beam(b: MeshInstance3D, from: Vector3, to: Vector3, thick: float) -> void:
	var len := from.distance_to(to)
	if len < 0.01:
		return
	b.global_position = (from + to) * 0.5
	b.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	b.scale = Vector3(thick, thick, len)


func _set_beams_visible(v: bool) -> void:
	for b in _beams:
		b.visible = v
	if _beam_dot:
		_beam_dot.visible = v
	if not v:
		_ramp = 1.0


# --------------------------------------------------------------- jam (vacuum boss)
func jam(time: float) -> void:
	jammed = maxf(jammed, time)
	cat.puff_up()
	if _dizzy == null:
		_dizzy = Node3D.new()
		_dizzy.position = Vector3(0, _top_y + 1.4, 0)
		add_child(_dizzy)
		var k := MeshKit.new()
		for i in 3:
			var a := TAU * i / 3.0
			k.sphere(Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3.ONE * 0.08, GameData.C_GOLD, Vector3.ZERO, 6)
		MeshKit.instance(k.build_unshaded(), _dizzy, false)


func _dizzy_spin(delta: float) -> void:
	if _dizzy:
		_dizzy.rotation.y += delta * 6.0


# --------------------------------------------------------------- upgrades
func upgrade() -> void:
	level += 1
	_rebuild_stack()
	pop()


func pop() -> void:
	scale = Vector3(1.3, 0.6, 1.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	cat.hop(4.0)
	cat.gesture("gesture-positive")


func payout() -> int:
	if def.kind != "income":
		return 0
	cat.hop(3.0)
	cat.bounce(0.3)
	cat.gesture("dance", "idle", 1.5)
	return get_income()
