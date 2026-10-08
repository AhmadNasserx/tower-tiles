class_name Fx
extends Node3D
## Pooled particle effects. Everything here is one-shot and recycled, so
## nothing is allocated mid-fight (kind on the web's garbage collector).

var overlay: Node # Overlay, for floating text

var _pools := {}
var _pool_index := {}
var _rings: Array[MeshInstance3D] = []
var _ring_index := 0
var _craters: Array[MeshInstance3D] = []
var _crater_index := 0
var _particle_mat: StandardMaterial3D
var _low_quality := false


func _ready() -> void:
	_low_quality = Save.settings.quality == "low"
	_particle_mat = StandardMaterial3D.new()
	_particle_mat.vertex_color_use_as_albedo = true
	_particle_mat.vertex_color_is_srgb = true
	_particle_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var sparkle_mat := _particle_mat.duplicate()
	sparkle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_make_pool("hit", 10, _sphere(0.07, _particle_mat), func(p: CPUParticles3D):
		p.amount = 8
		p.lifetime = 0.35
		p.spread = 180.0
		p.initial_velocity_min = 2.5
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -9, 0))
	_make_pool("puff", 8, _sphere(0.22, _particle_mat), func(p: CPUParticles3D):
		p.amount = 10
		p.lifetime = 0.5
		p.spread = 180.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 2.5
		p.gravity = Vector3(0, 1.5, 0)
		p.damping_min = 3.0
		p.damping_max = 4.0)
	_make_pool("splash", 5, _sphere(0.09, _particle_mat), func(p: CPUParticles3D):
		p.amount = 18
		p.lifetime = 0.6
		p.direction = Vector3.UP
		p.spread = 50.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -14, 0)
		p.color = Color("8fd3ff"))
	_make_pool("sparkle", 5, _box(0.12, sparkle_mat), func(p: CPUParticles3D):
		p.amount = 16
		p.lifetime = 0.8
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -3, 0)
		p.angular_velocity_min = -360
		p.angular_velocity_max = 360
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.6)
	_make_pool("coins", 6, _coin(), func(p: CPUParticles3D):
		p.amount = 6
		p.lifetime = 0.6
		p.direction = Vector3.UP
		p.spread = 35.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 6.5
		p.gravity = Vector3(0, -18, 0)
		p.angular_velocity_min = -540
		p.angular_velocity_max = 540
		p.particle_flag_rotate_y = true)
	_make_pool("dust", 3, _sphere(0.35, _particle_mat), func(p: CPUParticles3D):
		p.amount = 28
		p.lifetime = 0.8
		p.direction = Vector3(1, 0.15, 0)
		p.spread = 180.0
		p.flatness = 0.85
		p.initial_velocity_min = 5.0
		p.initial_velocity_max = 9.0
		p.damping_min = 6.0
		p.damping_max = 9.0
		p.gravity = Vector3(0, 0.5, 0)
		p.color = Color("e8d9c0"))
	_make_pool("heal", 4, _box(0.1, sparkle_mat), func(p: CPUParticles3D):
		p.amount = 8
		p.lifetime = 0.7
		p.direction = Vector3.UP
		p.spread = 25.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 2.5
		p.gravity = Vector3.ZERO
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.5
		p.color = GameData.C_GREEN)
	_make_pool("hearts", 2, _box(0.18, sparkle_mat), func(p: CPUParticles3D):
		p.amount = 10
		p.lifetime = 0.9
		p.direction = Vector3.UP
		p.spread = 40.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0, -4, 0)
		p.color = GameData.C_RED)

	for i in 8:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.92
		tm.outer_radius = 1.0
		tm.rings = 32
		tm.ring_segments = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.material = mat
		r.mesh = tm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		_rings.append(r)
	for i in 3:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.02
		cm.radial_segments = 20
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = Color(0.25, 0.18, 0.12, 0.6)
		mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.material = mat2
		c.mesh = cm
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.visible = false
		add_child(c)
		_craters.append(c)


func _sphere(r: float, mat: Material) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = mat
	return m


func _box(s: float, mat: Material) -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE * s
	m.material = mat
	return m


func _coin() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.16
	m.bottom_radius = 0.16
	m.height = 0.05
	m.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameData.C_GOLD
	mat.metallic = 0.4
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Color("7a5a00")
	m.material = mat
	return m


func _make_pool(pool_name: String, count: int, mesh: Mesh, config: Callable) -> void:
	var arr: Array[CPUParticles3D] = []
	if _low_quality:
		count = maxi(2, count / 2)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.8))
	curve.add_point(Vector2(1, 0))
	for i in count:
		var p := CPUParticles3D.new()
		p.mesh = mesh
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 0.95
		p.local_coords = false
		p.scale_amount_curve = curve
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		config.call(p)
		if _low_quality:
			p.amount = maxi(3, p.amount / 2)
		add_child(p)
		arr.append(p)
	_pools[pool_name] = arr
	_pool_index[pool_name] = 0


func _emit(pool_name: String, pos: Vector3, color := Color(-1, 0, 0), scale_mult := 1.0) -> CPUParticles3D:
	var arr: Array = _pools[pool_name]
	var i: int = _pool_index[pool_name]
	_pool_index[pool_name] = (i + 1) % arr.size()
	var p: CPUParticles3D = arr[i]
	p.global_position = pos
	if color.r >= 0.0:
		p.color = color
	p.scale_amount_min = 0.6 * scale_mult
	p.scale_amount_max = 1.2 * scale_mult
	p.restart()
	return p


# ------------------------------------------------------------------ public api
func hit(pos: Vector3, color: Color) -> void:
	_emit("hit", pos, color)


func puff(pos: Vector3, color: Color, size := 1.0) -> void:
	var p := _emit("puff", pos, color, size)
	p.initial_velocity_max = 2.5 * size
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2 * size


func splash(pos: Vector3, radius: float) -> void:
	var p := _emit("splash", pos)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.4
	ring(Vector3(pos.x, 0.15, pos.z), radius, Color("8fd3ff"))


func sparkle(pos: Vector3, color: Color) -> void:
	_emit("sparkle", pos, color)


func coins(pos: Vector3) -> void:
	_emit("coins", pos + Vector3(0, 0.5, 0))


func heal(pos: Vector3) -> void:
	_emit("heal", pos + Vector3(0, 0.6, 0))


func hearts(pos: Vector3) -> void:
	_emit("hearts", pos)


func dust(pos: Vector3, size := 1.0) -> void:
	var p := _emit("dust", pos + Vector3(0, 0.2, 0), Color("e8d9c0"), size)
	p.initial_velocity_max = 9.0 * size


func ring(pos: Vector3, radius: float, color: Color, time := 0.45) -> void:
	var r := _rings[_ring_index]
	_ring_index = (_ring_index + 1) % _rings.size()
	r.visible = true
	r.global_position = pos
	r.scale = Vector3(0.2, 1.0, 0.2)
	var mat: StandardMaterial3D = (r.mesh as TorusMesh).material
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "scale", Vector3(radius, 1.0 + radius * 0.3, radius), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func(): r.visible = false)


func crater(pos: Vector3, radius: float) -> void:
	var c := _craters[_crater_index]
	_crater_index = (_crater_index + 1) % _craters.size()
	c.visible = true
	c.global_position = Vector3(pos.x, 0.02, pos.z)
	c.scale = Vector3(radius * 0.8, 1, radius * 0.8)
	var mat: StandardMaterial3D = (c.mesh as CylinderMesh).material
	mat.albedo_color.a = 0.55
	var tw := c.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	tw.tween_callback(func(): c.visible = false)


func floating_text(pos: Vector3, text: String, color: Color, size := 1.0) -> void:
	if overlay:
		overlay.text_3d(pos, text, color, size)
