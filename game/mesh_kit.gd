class_name MeshKit
## Builds low-poly models out of primitive shapes, baked into a single
## vertex-coloured ArrayMesh. One mesh + one shared material = one draw call,
## which keeps the web build fast even with lots of dogs on screen.

var _st := SurfaceTool.new()
var _empty := true

static var _material: StandardMaterial3D
static var _unshaded: StandardMaterial3D
static var _flash: StandardMaterial3D
static var _prim_cache := {}


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.85
		_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_material.rim_enabled = true
		_material.rim = 0.25
		_material.rim_tint = 0.6
	return _material


static func unshaded() -> StandardMaterial3D:
	if _unshaded == null:
		_unshaded = StandardMaterial3D.new()
		_unshaded.vertex_color_use_as_albedo = true
		_unshaded.vertex_color_is_srgb = true
		_unshaded.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _unshaded


## Pure white material swapped in for a frame when something is hit.
static func flash_material() -> StandardMaterial3D:
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.albedo_color = Color(1, 1, 1)
	return _flash


static func color_material(c: Color, unshaded_mat := false, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded_mat:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent or c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


static func _prim_arrays(key: String, make: Callable) -> Array:
	if not _prim_cache.has(key):
		var m: PrimitiveMesh = make.call()
		_prim_cache[key] = m.get_mesh_arrays()
	return _prim_cache[key]


func _add_arrays(arrays: Array, xf: Transform3D, color: Color) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis_n := xf.basis.inverse().transposed()
	_st.set_color(color)
	if indices.is_empty():
		for i in verts.size():
			_st.set_normal((basis_n * normals[i]).normalized())
			_st.add_vertex(xf * verts[i])
	else:
		for i in indices:
			_st.set_normal((basis_n * normals[i]).normalized())
			_st.add_vertex(xf * verts[i])
	_empty = false


static func xf(pos: Vector3, scale := Vector3.ONE, rot_deg := Vector3.ZERO) -> Transform3D:
	# rotate in the shape's own frame, after scaling it (R * S, not S * R)
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(scale)
	return Transform3D(b, pos)


func sphere(pos: Vector3, radius: Vector3, color: Color, rot_deg := Vector3.ZERO, segments := 10) -> MeshKit:
	var rings := maxi(4, segments / 2 + 1)
	var arr := _prim_arrays("sphere%d" % segments, func():
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = segments
		s.rings = rings
		return s)
	_add_arrays(arr, xf(pos, radius, rot_deg), color)
	return self


func box(pos: Vector3, size: Vector3, color: Color, rot_deg := Vector3.ZERO) -> MeshKit:
	var arr := _prim_arrays("box", func():
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		return b)
	_add_arrays(arr, xf(pos, size, rot_deg), color)
	return self


func cylinder(pos: Vector3, radius: float, height: float, color: Color, rot_deg := Vector3.ZERO, top_ratio := 1.0, segments := 10) -> MeshKit:
	var key := "cyl%d_%.2f" % [segments, top_ratio]
	var arr := _prim_arrays(key, func():
		var c := CylinderMesh.new()
		c.top_radius = top_ratio
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = segments
		c.rings = 1
		return c)
	_add_arrays(arr, xf(pos, Vector3(radius, height, radius), rot_deg), color)
	return self


## Cone / pyramid. segments=4 gives a pyramid (great for cat ears).
func cone(pos: Vector3, radius: float, height: float, color: Color, rot_deg := Vector3.ZERO, segments := 8, scale_z := 1.0) -> MeshKit:
	var arr := _prim_arrays("cone%d" % segments, func():
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = segments
		c.rings = 1
		return c)
	_add_arrays(arr, xf(pos, Vector3(radius, height, radius * scale_z), rot_deg), color)
	return self


func torus(pos: Vector3, inner: float, outer: float, color: Color, rot_deg := Vector3.ZERO) -> MeshKit:
	var key := "torus%.3f_%.3f" % [inner, outer]
	var arr := _prim_arrays(key, func():
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 16
		t.ring_segments = 6
		return t)
	_add_arrays(arr, xf(pos, Vector3.ONE, rot_deg), color)
	return self


func build() -> ArrayMesh:
	if _empty:
		return ArrayMesh.new()
	var mesh := _st.commit()
	mesh.surface_set_material(0, material())
	return mesh


func build_unshaded() -> ArrayMesh:
	var mesh := build()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, unshaded())
	return mesh


static func instance(mesh: Mesh, parent: Node3D = null, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent:
		parent.add_child(mi)
	return mi
