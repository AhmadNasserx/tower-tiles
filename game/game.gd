class_name Game
extends Node3D
## Runs one defense: builds the level, spawns waves, handles building,
## upgrades, perks, abilities, juice, and the win/lose flow.

signal gold_changed(gold: int)
signal lives_changed(lives: int, max_lives: int)
signal wave_changed(wave: int)
signal selection_changed(turret: Turret)
signal build_mode_changed(type: String)

static var selected_map := 0

@export var demo := false

const SPEEDS := [1.0, 2.0, 3.0]
const COUNTDOWN := 12.0

var map: Dictionary
var level: Level
var camera: CameraRig
var tower: CatTower
var fx: Fx
var overlay: Overlay
var hud: Node
var sun: DirectionalLight3D

var enemies: Array[Enemy] = []
var turrets := {} # Vector2i -> Turret

var gold := 0
var display_gold := 0.0
var lives := 9
var max_lives := 9
var lives_lost := 0
var wave := 0
var playing := true
var in_wave := false
var countdown := -1.0
var speed_index := 0
var victory_reached := false
var endless := false

var perks := {}
var rerolls := 0
var dmg_mult := 1.0
var rate_mult := 1.0
var range_mult := 1.0
var gold_mult := 1.0
var cost_mult := 1.0
var crit_chance := 0.0
var cd_mult := 1.0

var paw_cd := 0.0
var zoomies_cd := 0.0
var zoomies_time := 0.0

var mode := "" # "", "build", "paw"
var build_type := ""
var selected: Turret
var hover_cell := Vector2i(-99, -99)
var _touch_armed := Vector2i(-99, -99)

var stats_damage := 0.0
var stats_kills := 0
var run_fish := 0
var fish_awarded := 0
var boss: Enemy

var _spawn_queue: Array = []
var _wave_time := 0.0
var _next_events: Array = []
var _combo := 0
var _combo_t := 0.0
var _hitstop := 0.0
var _hitstop_scale := 1.0
var _last_real := 0.0

var _hover_tile: Node3D
var _hover_mat: StandardMaterial3D
var _range_disc: MeshInstance3D
var _range_ring: MeshInstance3D
var _ghost: Node3D
var _ghost_mat: StandardMaterial3D
var _paw_marker: MeshInstance3D
var _demo_t := 0.0


func _ready() -> void:
	map = GameData.MAPS[clampi(selected_map, 0, GameData.MAPS.size() - 1)]
	_build_world()
	_apply_meta()
	_next_events = GameData.build_wave(1, map.difficulty)
	_last_real = Time.get_ticks_msec() / 1000.0
	if demo:
		_setup_demo()
	else:
		hud = preload("res://ui/hud.gd").new()
		hud.game = self
		add_child(hud)
		Sfx.music("battle")
		Sfx.set_music_pitch(1.0, 0.1)
		Sfx.quiet = false
	_emit_all()


func _build_world() -> void:
	Toon.outlines_enabled = Save.settings.quality != "low"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = (map.grass[1] as Color).darkened(0.35)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("d9ccff")
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	add_child(env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 0.95
	sun.shadow_enabled = Save.settings.quality != "low"
	sun.shadow_opacity = 0.55
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_blur = 1.5
	add_child(sun)

	level = Level.new()
	add_child(level)
	level.build(map)

	tower = CatTower.new()
	add_child(tower)
	tower.position = level.cell_to_world(level.cat_cell)
	tower.rotation.y = PI
	tower.setup(self)

	fx = Fx.new()
	add_child(fx)

	camera = CameraRig.new()
	add_child(camera)
	camera.shake_enabled = Save.settings.shake and not demo
	camera.setup(level.size_world())
	camera.current = true

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	overlay = Overlay.new()
	overlay.game = self
	overlay.camera = camera
	overlay.font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
	layer.add_child(overlay)
	overlay.coin_arrived.connect(_on_coin_arrived)
	fx.overlay = overlay

	_build_indicators()
	if Save.settings.quality == "low":
		get_viewport().scaling_3d_scale = 0.75
	else:
		get_viewport().scaling_3d_scale = 1.0


func _build_indicators() -> void:
	# Kenney's corner-bracket selection marker
	_hover_tile = load("res://assets/models/td/selection-a.glb").instantiate()
	_hover_tile.scale = Vector3.ONE * Level.KIT
	_hover_mat = MeshKit.color_material(Color(1, 1, 1, 0.9), true)
	for mi in _hover_tile.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _hover_mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_tile.visible = false
	add_child(_hover_tile)

	_range_disc = MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 1.0
	dm.bottom_radius = 1.0
	dm.height = 0.02
	dm.radial_segments = 40
	dm.rings = 1
	_range_disc.mesh = dm
	_range_disc.material_override = MeshKit.color_material(Color(1, 1, 1, 0.12), true)
	_range_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_disc.visible = false
	add_child(_range_disc)
	_range_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.97
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 4
	_range_ring.mesh = tm
	_range_ring.material_override = MeshKit.color_material(Color(1, 1, 1, 0.75), true)
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_disc.add_child(_range_ring)

	_ghost = Node3D.new()
	_ghost.visible = false
	add_child(_ghost)
	_ghost_mat = MeshKit.color_material(Color(1, 1, 1, 0.45), true)

	_paw_marker = MeshInstance3D.new()
	var pk := MeshKit.new()
	pk.sphere(Vector3(0, 0, 0.15), Vector3(0.55, 0.02, 0.45), Color(1, 1, 1))
	for i in 4:
		var a := deg_to_rad(-55 + i * 37)
		pk.sphere(Vector3(sin(a) * 0.62, 0, -cos(a) * 0.62 + 0.05), Vector3(0.18, 0.02, 0.22), Color(1, 1, 1))
	_paw_marker.mesh = pk.build_unshaded()
	_paw_marker.material_override = MeshKit.color_material(Color(1, 0.6, 0.3, 0.55), true)
	_paw_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_paw_marker.visible = false
	add_child(_paw_marker)


func _apply_meta() -> void:
	gold = GameData.BASE_GOLD + map.gold_bonus + 30 * Save.meta_level("gold")
	display_gold = gold
	max_lives = GameData.BASE_LIVES + Save.meta_level("lives")
	lives = max_lives
	rerolls = Save.meta_level("reroll")
	_recompute_mods()


func _recompute_mods() -> void:
	dmg_mult = (1.0 + 0.15 * perk("claws")) * (1.0 + 0.06 * Save.meta_level("claws"))
	rate_mult = 1.0 + 0.12 * perk("caffeine")
	range_mult = 1.0 + 0.12 * perk("eyes")
	gold_mult = (1.0 + 0.2 * perk("burglar")) * (1.0 + 0.06 * Save.meta_level("magnet"))
	cost_mult = (1.0 - 0.12 * perk("catalog")) * (1.0 - 0.04 * Save.meta_level("discount"))
	crit_chance = 0.1 * perk("crit")
	cd_mult = maxf(0.35, (1.0 - 0.2 * perk("quickpaws")) * (1.0 - 0.08 * Save.meta_level("cooldown")))


func perk(id: String) -> int:
	return int(perks.get(id, 0))


func price(base: int) -> int:
	return int(round(base * cost_mult))


func roll_crit() -> bool:
	return crit_chance > 0.0 and randf() < crit_chance


func hero_damage() -> float:
	return GameData.HERO_DAMAGE * (1.0 + 0.12 * maxi(wave - 1, 0)) * (1.0 + 0.25 * Save.meta_level("hero")) * (1.0 + 0.4 * perk("heroic")) * dmg_mult


func hero_rate() -> float:
	return GameData.HERO_RATE * (1.0 + 0.1 * Save.meta_level("hero")) * (1.0 + 0.4 * perk("heroic")) * (2.0 if zoomies_time > 0.0 else 1.0)


func hero_range() -> float:
	return GameData.HERO_RANGE * range_mult


func paw_damage() -> float:
	return GameData.PAW_DAMAGE * (1.0 + 0.16 * maxi(wave - 1, 0)) * (1.0 + 0.5 * perk("bigpaw")) * (1.0 + 0.25 * Save.meta_level("paw"))


func paw_radius() -> float:
	return GameData.PAW_RADIUS * (1.0 + 0.2 * perk("bigpaw"))


func _emit_all() -> void:
	gold_changed.emit(gold)
	lives_changed.emit(lives, max_lives)
	wave_changed.emit(wave)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var real_delta := minf(now - _last_real, 0.1)
	_last_real = now
	_update_time_scale(real_delta)
	if demo:
		_demo_process(delta)
	display_gold = move_toward(display_gold, gold, maxf(1.0, absf(gold - display_gold)) * real_delta * 8.0)

	if paw_cd > 0.0:
		paw_cd -= delta
	if zoomies_cd > 0.0:
		zoomies_cd -= delta
	if zoomies_time > 0.0:
		zoomies_time -= delta
		if zoomies_time <= 0.0:
			Sfx.set_music_pitch(1.0)
	if _combo_t > 0.0:
		_combo_t -= delta
		if _combo_t <= 0.0:
			_combo = 0

	if not playing:
		return
	if in_wave:
		_wave_time += delta
		while not _spawn_queue.is_empty() and _spawn_queue[0].t <= _wave_time:
			var ev: Dictionary = _spawn_queue.pop_front()
			_spawn(ev.type)
		if _spawn_queue.is_empty() and enemies.is_empty():
			_wave_cleared()
	elif countdown > 0.0:
		var before := ceili(countdown)
		countdown -= delta
		if ceili(countdown) != before and before <= 3 and not demo:
			Sfx.play("tick", 1.0 + (3 - before) * 0.1, 0.0)
		if countdown <= 0.0:
			start_wave()
	_update_hover()


func _update_time_scale(real_delta: float) -> void:
	var target: float = SPEEDS[speed_index]
	if _hitstop > 0.0:
		_hitstop -= real_delta
		target *= _hitstop_scale
	if get_tree().paused:
		return
	Engine.time_scale = target


func hitstop(duration: float, scale := 0.05) -> void:
	_hitstop = maxf(_hitstop, duration)
	_hitstop_scale = scale


func shake(amount: float) -> void:
	camera.add_trauma(amount)


# ------------------------------------------------------------------ waves
func start_wave() -> void:
	if in_wave or not playing:
		return
	if countdown > 0.0 and wave > 0:
		var bonus := int(countdown * 1.5)
		if bonus > 0:
			add_gold(bonus)
			if hud:
				hud.toast("Early bonus +%d" % bonus, GameData.C_GOLD)
	countdown = -1.0
	wave += 1
	in_wave = true
	_wave_time = 0.0
	_spawn_queue = GameData.build_wave(wave, map.difficulty)
	_next_events = GameData.build_wave(wave + 1, map.difficulty)
	wave_changed.emit(wave)
	if not demo:
		Sfx.play("wave_start", 1.0, 0.0)
		if hud:
			if GameData.is_boss_wave(wave):
				hud.banner("BOSS WAVE %d" % wave, "Something big is coming...", GameData.C_RED)
			else:
				hud.banner("WAVE %d" % wave, _wave_flavor(), GameData.C_CREAM)


func _wave_flavor() -> String:
	var newest := ""
	for t in GameData.UNLOCK_WAVE:
		if GameData.UNLOCK_WAVE[t] == wave:
			newest = t
	match newest:
		"hound": return "Hounds incoming! Sturdier than pups."
		"greyhound": return "Foxes! They are FAST."
		"bulldog": return "Boars! Armored. Big hits work best."
		"poodle": return "Nurse Bunnies heal their friends. Focus them!"
	var lines := ["Here they come!", "Woof woof squeak.", "Protect the nap spot!", "Stay pawsitive!",
		"Hiss-teria incoming.", "Fur real now.", "The pack smells treats.", "Claws out!"]
	return lines[wave % lines.size()]


func next_wave_preview() -> Dictionary:
	return GameData.wave_summary(_next_events)


func _spawn(type: String) -> void:
	var e := Enemy.new()
	add_child(e)
	var boss_type: bool = GameData.ENEMIES[type].get("boss", false)
	var mult := GameData.boss_hp_mult(wave, map.difficulty) if boss_type else GameData.hp_mult(wave, map.difficulty)
	e.setup(self, type, level.curve, mult)
	enemies.append(e)
	level.spawn_wobble()
	if e.is_boss:
		boss = e
		if not demo:
			Sfx.play("boss", 1.0, 0.0)
			Sfx.music("boss")
			shake(0.5)
			if hud:
				hud.banner(e.def.name.to_upper(), "Boss incoming!", GameData.C_RED)
			tower.cat.puff_up()
			Sfx.play("yowl", 1.0, 0.0, -4.0)


func _wave_cleared() -> void:
	in_wave = false
	var bonus := 12 + wave * 3
	add_gold(bonus)
	run_fish += 2 + wave / 5
	if not demo:
		Sfx.play("wave_clear", 1.0, 0.0)
		Sfx.music("battle")
		tower.celebrate()
		Sfx.play("meow", 1.0, 0.1)
		if hud:
			hud.toast("Wave cleared! +%d gold" % bonus, GameData.C_GREEN)
	# Fat Cat payouts
	var delay := 0.3
	for t: Turret in turrets.values():
		if t.def.kind == "income":
			var amount := t.payout()
			get_tree().create_timer(delay, false).timeout.connect(func():
				if is_instance_valid(t):
					overlay.fly_coins(t.global_position + Vector3(0, 1.4, 0), amount, 5)
					fx.coins(t.global_position)
					overlay.text_3d(t.global_position + Vector3(0, 2.0, 0), "+%d" % amount, GameData.C_GOLD, 1.3)
					Sfx.play("cash", 1.0, 0.05))
			delay += 0.2
	if perk("interest") > 0:
		var interest := mini(int(gold * 0.06 * perk("interest")), 60)
		if interest > 0:
			add_gold(interest)
			if hud:
				hud.toast("Interest +%d" % interest, GameData.C_GREEN)
	if demo:
		countdown = 3.0
		return
	if wave >= GameData.WAVES_TO_WIN and not victory_reached:
		_victory()
		return
	countdown = COUNTDOWN
	if wave % 3 == 0:
		get_tree().create_timer(0.8, false).timeout.connect(offer_perks)


# ------------------------------------------------------------------ economy
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	display_gold = gold
	gold_changed.emit(gold)
	return true


func _on_coin_arrived(amount: int) -> void:
	add_gold(amount)
	if not demo:
		Sfx.play("coin", 1.0 + randf() * 0.2, 0.05)
		if hud:
			hud.bump_gold()


# ------------------------------------------------------------------ enemy events
func on_enemy_killed(e: Enemy) -> void:
	enemies.erase(e)
	stats_kills += 1
	_combo += 1
	_combo_t = 1.4
	var g := int(round(e.gold * gold_mult))
	if _combo >= 5:
		g += 1
	if _combo > 0 and _combo % 5 == 0 and not demo:
		overlay.text_3d(e.global_position + Vector3(0, 2.2, 0), "COMBO x%d!" % _combo, GameData.C_PINK, 1.5, 1.1)
		Sfx.play("combo", 1.0 + minf(_combo / 40.0, 0.8), 0.0)
	overlay.fly_coins(e.global_position + Vector3(0, 0.6, 0), g, 1 if not e.is_boss else 12)
	fx.coins(e.global_position)
	if not demo:
		Sfx.play("die" if randf() < 0.5 else "die2", 1.0 / sqrt(e.size * 1.5), 0.12)
	if e.is_boss:
		boss = null
		if not demo:
			hitstop(0.35, 0.08)
			shake(0.8)
			fx.sparkle(e.global_position + Vector3(0, 1, 0), GameData.C_GOLD)
			fx.dust(e.global_position, 1.5)
			Sfx.play("victory", 1.4, 0.0, -6.0)
			if hud:
				hud.toast("%s defeated!" % e.def.name, GameData.C_GOLD)
	elif _combo >= 8 and _combo % 8 == 0 and not demo:
		hitstop(0.05, 0.2)


func on_enemy_leaked(e: Enemy) -> void:
	enemies.erase(e)
	if e == boss:
		boss = null
	if demo or not playing:
		return
	lose_lives(e.lives)


func lose_lives(n: int) -> void:
	lives = maxi(0, lives - n)
	lives_lost += n
	lives_changed.emit(lives, max_lives)
	tower.hurt()
	fx.hearts(tower.global_position + Vector3(0, 4.5, 0))
	shake(0.35 + 0.1 * n)
	hitstop(0.08, 0.15)
	Sfx.play("life_lost", 1.0, 0.08)
	if hud:
		hud.flash_damage()
	if lives <= 0 and playing:
		_defeat()


func splash_damage(source: Node, pos: Vector3, radius: float, dmg: float, crit: bool) -> void:
	for e: Enemy in enemies.duplicate():
		if not e.alive:
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d <= radius:
			var was := e.alive
			var falloff := lerpf(1.0, 0.6, d / radius)
			e.take_damage(dmg * falloff, crit)
			if is_instance_valid(source) and source.has_method("credit"):
				source.credit(e, dmg * falloff, was and not e.alive)


func poodle_heal(p: Enemy) -> void:
	var healed := false
	for e: Enemy in enemies:
		if e.alive and e != p and e.hp < e.max_hp and e.global_position.distance_to(p.global_position) < 3.5:
			e.heal(0.08)
			fx.heal(e.global_position)
			healed = true
	if healed:
		fx.ring(p.global_position + Vector3(0, 0.2, 0), 3.5, GameData.C_GREEN, 0.5)
		if not demo:
			Sfx.play("heal")


func boss_ability(b: Enemy) -> void:
	if b.type == "alpha":
		for e: Enemy in enemies:
			if e.alive and e.global_position.distance_to(b.global_position) < 6.0:
				e.haste_time = 2.0
		fx.ring(b.global_position + Vector3(0, 0.3, 0), 6.0, GameData.C_RED, 0.6)
		overlay.text_3d(b.global_position + Vector3(0, 3, 0), "AWOOOO!", GameData.C_RED, 1.6, 1.2)
		if not demo:
			Sfx.play("yowl", 0.55, 0.05, -2.0)
			shake(0.2)
	elif b.type == "vacuum":
		var jammed := 0
		for t: Turret in turrets.values():
			if t.global_position.distance_to(b.global_position) < 4.2:
				t.jam(2.0)
				jammed += 1
		fx.ring(b.global_position + Vector3(0, 0.3, 0), 4.2, Color("ffd23f"), 0.6)
		overlay.text_3d(b.global_position + Vector3(0, 3, 0), "VRRRRMMM!", GameData.C_GOLD, 1.6, 1.2)
		if not demo:
			Sfx.play("zoomies", 0.5, 0.05)
			if jammed > 0:
				shake(0.25)


func spawn_projectile(source: Node, from: Vector3, target: Enemy, dmg: float, crit: bool, kind: String, opts: Dictionary) -> void:
	var p := Projectile.new()
	add_child(p)
	p.setup(self, source, from, target, dmg, crit, kind, opts)


# ------------------------------------------------------------------ building
func set_build_type(type: String) -> void:
	if type == "" or type == build_type:
		build_type = ""
		mode = ""
	else:
		if gold < price(GameData.TURRETS[type].cost):
			if hud:
				hud.toast("Not enough gold!", GameData.C_RED)
			Sfx.play("error")
			return
		build_type = type
		mode = "build"
		select(null)
		_set_ghost(type)
	_touch_armed = Vector2i(-99, -99)
	build_mode_changed.emit(build_type)
	Sfx.play("click")


## A see-through preview of the kitten's tower under the cursor.
func _set_ghost(type: String) -> void:
	for c in _ghost.get_children():
		c.queue_free()
	var st: Dictionary = Turret.STYLE[type]
	var pieces: Array = ["tower-round-base"] if type == "fatcat" else [st.bottom]
	if st.weapon != "":
		pieces.append(st.weapon)
	var y := 0.0
	for p in pieces:
		var n := Turret._piece(p)
		n.scale = Vector3.ONE * Turret.TS
		n.position.y = y
		_ghost.add_child(n)
		y += 0.6 * Turret.TS
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = _ghost_mat
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func can_build(c: Vector2i) -> bool:
	return level.is_buildable(c) and not turrets.has(c)


func build(type: String, c: Vector2i) -> Turret:
	var cost := price(GameData.TURRETS[type].cost)
	if not can_build(c) or not spend(cost):
		Sfx.play("error")
		return null
	var t := Turret.new()
	add_child(t)
	t.position = level.cell_to_world(c)
	t.setup(self, type, c)
	t.invested = cost
	turrets[c] = t
	t.pop()
	fx.dust(t.global_position, 0.5)
	fx.sparkle(t.global_position + Vector3(0, 1.0, 0), t.def.accent)
	if not demo:
		Sfx.play("build")
		Sfx.play("meow2", randf_range(1.1, 1.4), 0.05, -6.0)
		shake(0.1)
	return t


func upgrade_selected() -> void:
	if selected == null or selected.is_max():
		Sfx.play("error")
		return
	var cost := selected.upgrade_cost()
	if not spend(cost):
		Sfx.play("error")
		if hud:
			hud.toast("Not enough gold!", GameData.C_RED)
		return
	selected.invested += cost
	selected.upgrade()
	fx.sparkle(selected.global_position + Vector3(0, 1.4, 0), GameData.C_GOLD)
	fx.ring(selected.global_position + Vector3(0, 0.2, 0), 1.5, GameData.C_GOLD)
	Sfx.play("upgrade")
	shake(0.08)
	_show_range(selected.global_position, selected.get_range(), Color(1, 1, 1))
	selection_changed.emit(selected)


func sell_selected() -> void:
	if selected == null:
		return
	var t := selected
	var value := t.sell_value()
	select(null)
	turrets.erase(t.cell)
	overlay.fly_coins(t.global_position + Vector3(0, 1, 0), value, 4)
	fx.puff(t.global_position + Vector3(0, 0.8, 0), Color(1, 1, 1), 1.5)
	Sfx.play("sell")
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector3(1.3, 0.01, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(t.queue_free)


func cycle_target_mode() -> void:
	if selected == null or selected.def.kind in ["income", "pulse"]:
		return
	selected.target_mode = (selected.target_mode + 1) % GameData.TARGET_MODES.size()
	Sfx.play("click")
	selection_changed.emit(selected)


func select(t: Turret) -> void:
	selected = t
	if t:
		mode = ""
		build_type = ""
		build_mode_changed.emit("")
		if t.def.kind != "income":
			_show_range(t.global_position, t.get_range(), Color(1, 1, 1))
		else:
			_range_disc.visible = false
		t.cat.bounce(0.2)
		Sfx.play("meow2", randf_range(1.2, 1.5), 0.05, -8.0)
	else:
		_range_disc.visible = false
	selection_changed.emit(t)


func _show_range(pos: Vector3, r: float, col: Color) -> void:
	_range_disc.visible = true
	_range_disc.global_position = Vector3(pos.x, 0.03, pos.z)
	(_range_disc.material_override as StandardMaterial3D).albedo_color = Color(col, 0.12)
	(_range_ring.material_override as StandardMaterial3D).albedo_color = Color(col, 0.8)
	var target := Vector3(r, 1, r)
	if not _range_disc.scale.is_equal_approx(target):
		var tw := _range_disc.create_tween()
		tw.tween_property(_range_disc, "scale", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ abilities
func paw_ready() -> bool:
	return paw_cd <= 0.0


func zoomies_ready() -> bool:
	return zoomies_cd <= 0.0


func paw_cooldown_total() -> float:
	return GameData.PAW_COOLDOWN * cd_mult


func zoomies_cooldown_total() -> float:
	return GameData.ZOOMIES_COOLDOWN * cd_mult


func begin_paw() -> void:
	if not paw_ready():
		Sfx.play("error")
		return
	if mode == "paw":
		mode = ""
		_paw_marker.visible = false
		build_mode_changed.emit("")
		return
	select(null)
	build_type = ""
	mode = "paw"
	build_mode_changed.emit("paw")
	Sfx.play("click")


func cast_paw(pos: Vector3) -> void:
	mode = ""
	_paw_marker.visible = false
	build_mode_changed.emit("")
	paw_cd = paw_cooldown_total()
	tower.slam_pose()
	var paw := _make_giant_paw()
	add_child(paw)
	paw.global_position = pos + Vector3(0, 18, 0)
	paw.scale = Vector3.ONE * paw_radius() / GameData.PAW_RADIUS
	var shadow := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = paw_radius() * 0.9
	sm.bottom_radius = paw_radius() * 0.9
	sm.height = 0.02
	sm.radial_segments = 24
	shadow.mesh = sm
	shadow.material_override = MeshKit.color_material(Color(0, 0, 0, 0.0), true)
	shadow.position = Vector3(pos.x, 0.05, pos.z)
	add_child(shadow)
	var smat: StandardMaterial3D = shadow.material_override
	Sfx.play("slam", 1.0, 0.05)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(paw, "global_position:y", pos.y + 0.2, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(smat, "albedo_color:a", 0.45, 0.32)
	tw.chain().tween_callback(func():
		_paw_impact(pos)
		shadow.queue_free())
	tw.tween_property(paw, "scale", paw.scale * Vector3(1.15, 0.7, 1.15), 0.08)
	tw.chain().tween_interval(0.35)
	tw.chain().tween_property(paw, "global_position:y", 20.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(paw.queue_free)


func _paw_impact(pos: Vector3) -> void:
	var r := paw_radius()
	var dmg := paw_damage()
	var hits := 0
	for e: Enemy in enemies.duplicate():
		if not e.alive:
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d <= r:
			var crit := roll_crit()
			e.take_damage(dmg * (2.5 if crit else 1.0), crit)
			e.apply_stun(0.6)
			hits += 1
	shake(0.75)
	camera.kick(Vector2(0, -0.6))
	hitstop(0.12 if hits > 0 else 0.05, 0.05)
	fx.dust(pos, 1.6)
	fx.crater(pos, r)
	fx.ring(pos + Vector3(0, 0.2, 0), r * 1.3, Color("fff4e0"), 0.5)
	if hits >= 3:
		overlay.text_3d(pos + Vector3(0, 2.5, 0), "SQUASHED x%d!" % hits, GameData.C_ORANGE, 1.6, 1.1)


func _make_giant_paw() -> Node3D:
	var n := Node3D.new()
	var k := MeshKit.new()
	var fur := Color("ff9f43")
	var bean := Color("ff9fb5")
	k.cylinder(Vector3(0, 6.0, 0.8), 1.1, 12.0, fur, Vector3(8, 0, 0), 0.9, 12)
	k.sphere(Vector3(0, 0.6, 0), Vector3(2.0, 0.9, 1.8), fur, Vector3.ZERO, 14)
	for i in 4:
		var a := deg_to_rad(-55 + i * 37)
		k.sphere(Vector3(sin(a) * 1.7, 0.55, -cos(a) * 1.5 - 0.3), Vector3(0.62, 0.6, 0.7), fur, Vector3.ZERO, 10)
		k.sphere(Vector3(sin(a) * 1.75, 0.0, -cos(a) * 1.55 - 0.3), Vector3(0.36, 0.08, 0.42), bean, Vector3.ZERO, 8)
	k.sphere(Vector3(0, 0.0, 0.3), Vector3(1.0, 0.1, 0.85), bean, Vector3.ZERO, 10)
	var mi := MeshKit.instance(k.build(), n)
	Toon.apply(mi, true, true)
	return n


func activate_zoomies() -> void:
	if not zoomies_ready():
		Sfx.play("error")
		return
	zoomies_cd = zoomies_cooldown_total()
	zoomies_time = GameData.ZOOMIES_TIME
	Sfx.play("zoomies", 1.0, 0.0)
	Sfx.set_music_pitch(1.12)
	shake(0.2)
	for t: Turret in turrets.values():
		t.cat.hop(4.0)
		fx.sparkle(t.global_position + Vector3(0, 1.2, 0), GameData.C_PURPLE)
	tower.celebrate()
	if hud:
		hud.banner("ZOOMIES!", "All kittens attack twice as fast", GameData.C_PURPLE, 1.2)


# ------------------------------------------------------------------ perks
func offer_perks() -> void:
	if not playing or hud == null:
		return
	hud.show_perks(roll_perks())


func roll_perks() -> Array:
	var pool: Array = []
	for id in GameData.PERKS:
		if perk(id) < GameData.PERKS[id].max:
			pool.append(id)
	pool.shuffle()
	return pool.slice(0, 3)


func take_perk(id: String) -> void:
	perks[id] = perk(id) + 1
	if id == "ninth":
		max_lives += 2
		lives += 2
		lives_changed.emit(lives, max_lives)
		fx.hearts(tower.global_position + Vector3(0, 4.5, 0))
	_recompute_mods()
	if selected:
		select(selected)
	Sfx.play("perk")
	tower.celebrate()


# ------------------------------------------------------------------ end states
func stars_earned() -> int:
	if lives_lost == 0:
		return 3
	if lives_lost <= 3:
		return 2
	return 1


func _victory() -> void:
	victory_reached = true
	var s := stars_earned()
	run_fish += 20 + s * 10
	_award_fish()
	Save.record_run(map.id, wave, s)
	Sfx.play("victory", 1.0, 0.0)
	Sfx.music("menu")
	tower.celebrate()
	hitstop(0.6, 0.25)
	if hud:
		hud.show_victory(s, run_fish)


func continue_endless() -> void:
	endless = true
	countdown = COUNTDOWN
	Sfx.music("battle")


func _defeat() -> void:
	playing = false
	in_wave = false
	_award_fish()
	Save.record_run(map.id, wave - 1, Save.stars.get(map.id, 0))
	Sfx.play("defeat", 1.0, 0.0)
	Sfx.music("menu")
	hitstop(1.0, 0.2)
	if hud:
		hud.show_defeat(run_fish)


func _award_fish() -> void:
	var owed := run_fish - fish_awarded
	if owed > 0 and not demo:
		Save.add_fish(owed)
		Save.stats.dogs_bonked += stats_kills
		fish_awarded = run_fish


func quit_to_menu() -> void:
	if not demo and wave > 0:
		_award_fish()
		Save.record_run(map.id, wave - (1 if in_wave else 0), Save.stars.get(map.id, 0))
	Transition.change_scene("res://scenes/main_menu.tscn")


func restart() -> void:
	if not demo and wave > 0:
		_award_fish()
	Transition.change_scene("res://scenes/game.tscn")


func set_speed(i: int) -> void:
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	Sfx.play("click")


func cycle_speed() -> void:
	set_speed((speed_index + 1) % SPEEDS.size())


# ------------------------------------------------------------------ input
func _update_hover() -> void:
	if demo or hud == null:
		return
	var mp := get_viewport().get_mouse_position()
	var gp = camera.ground_point(mp)
	if gp == null or hud.is_mouse_over_ui():
		_hover_tile.visible = false
		_ghost.visible = false
		_paw_marker.visible = false
		if mode == "build" and selected == null:
			_range_disc.visible = false
		return
	var c := level.world_to_cell(gp)
	hover_cell = c
	if mode == "paw":
		_hover_tile.visible = false
		_ghost.visible = false
		_paw_marker.visible = true
		_paw_marker.global_position = Vector3(gp.x, 0.06, gp.z)
		_paw_marker.scale = Vector3.ONE * paw_radius() / 1.6
		_show_range(gp, paw_radius(), GameData.C_ORANGE)
		return
	_paw_marker.visible = false
	if not level.in_bounds(c):
		_hover_tile.visible = false
		_ghost.visible = false
		return
	var wp := level.cell_to_world(c)
	_hover_tile.visible = true
	_hover_tile.global_position = wp + Vector3(0, 0.03, 0)
	var pulse := 0.75 + sin(Time.get_ticks_msec() * 0.008) * 0.2
	var col := Color(1, 1, 1, pulse * 0.6)
	if mode == "build":
		var ok := can_build(c)
		col = Color(GameData.C_GREEN, pulse) if ok else Color(GameData.C_RED, pulse)
		_ghost.visible = ok
		_ghost.global_position = wp
		var r: float = GameData.TURRETS[build_type].levels[0].range * range_mult
		if r > 0.0:
			_show_range(wp, r, GameData.C_GREEN if ok else GameData.C_RED)
		else:
			_range_disc.visible = false
	else:
		_ghost.visible = false
		if turrets.has(c):
			col = Color(GameData.C_GOLD, pulse)
	_hover_mat.albedo_color = col
	var bob := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.04
	_hover_tile.scale = Vector3(bob, 1.0, bob) * Level.KIT


func _unhandled_input(event: InputEvent) -> void:
	if demo or not playing:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click(mb.position, mb.shift_pressed, mb.device == InputEvent.DEVICE_ID_EMULATION)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		match k:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				set_build_type(GameData.TURRET_ORDER[k - KEY_1])
			KEY_Q:
				begin_paw()
			KEY_E:
				activate_zoomies()
			KEY_SPACE:
				if not in_wave:
					start_wave()
			KEY_F:
				cycle_speed()
			KEY_U:
				upgrade_selected()
			KEY_X, KEY_DELETE, KEY_BACKSPACE:
				sell_selected()
			KEY_T:
				cycle_target_mode()
			KEY_ESCAPE, KEY_P:
				if mode != "" or selected:
					_cancel()
				elif hud:
					hud.toggle_pause()


func _cancel() -> void:
	if mode == "paw":
		_paw_marker.visible = false
	mode = ""
	build_type = ""
	build_mode_changed.emit("")
	select(null)


func _on_left_click(pos: Vector2, shift: bool, from_touch := false) -> void:
	var gp = camera.ground_point(pos)
	if gp == null:
		return
	if mode == "paw":
		cast_paw(Vector3(gp.x, 0, gp.z))
		return
	var c := level.world_to_cell(gp)
	if mode == "build":
		if not can_build(c):
			Sfx.play("error")
			if turrets.has(c):
				select(turrets[c])
			return
		if from_touch and _touch_armed != c:
			# on touch screens, first tap previews, second tap builds
			_touch_armed = c
			hover_cell = c
			Sfx.play("hover")
			return
		var type := build_type
		build(type, c)
		_touch_armed = Vector2i(-99, -99)
		if not (shift and gold >= price(GameData.TURRETS[type].cost)):
			mode = ""
			build_type = ""
			_ghost.visible = false
			_range_disc.visible = false
			build_mode_changed.emit("")
		return
	if turrets.has(c):
		select(turrets[c])
	else:
		select(null)


# ------------------------------------------------------------------ demo (menu background)
func _setup_demo() -> void:
	playing = true
	camera.set_process_unhandled_input(false)
	Sfx.quiet = true
	gold = 99999
	var spots := []
	for y in level.rows:
		for x in level.cols:
			var c := Vector2i(x, y)
			if not level.is_buildable(c):
				continue
			# only next to the road
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if level.is_road(level.char_at(c + d)):
					spots.append(c)
					break
	spots.shuffle()
	var types := GameData.TURRET_ORDER
	for i in mini(7, spots.size()):
		var t := build(types[i % types.size()], spots[i])
		if t and i % 2 == 0:
			t.upgrade()
	countdown = 1.0


func _demo_process(delta: float) -> void:
	_demo_t += delta
	camera._focus_target = Vector3(sin(_demo_t * 0.1) * 4.0, 0, cos(_demo_t * 0.08) * 2.0)
	if wave > 6:
		wave = 1
