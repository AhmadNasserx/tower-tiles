class_name Toon
## Toon-shading helpers: swaps imported model materials for the cel shader,
## adds inverted-hull outlines (with smoothed normals so cube edges don't
## crack), and drives per-instance hit flashes.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

static var _tex_materials := {}
static var _outline_material: ShaderMaterial
static var _outline_thin: ShaderMaterial
static var _smooth_cache := {}
static var outlines_enabled := true


## Cached toon material for a texture + tint combination.
## `ground` = flat board surfaces: no rim light or highlight, which otherwise
## glint along the road's bevelled edges.
static func material_for(tex: Texture2D, tint := Color(1, 1, 1), vertex_colors := false, ground := false) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [tex.resource_path if tex else "white", tint.to_html(), vertex_colors, ground]
	if not _tex_materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON_SHADER
		if tex:
			m.set_shader_parameter("albedo_tex", tex)
		if tint != Color(1, 1, 1):
			m.set_shader_parameter("tint", tint)
		if vertex_colors:
			m.set_shader_parameter("vertex_color_amount", 1.0)
		if ground:
			m.set_shader_parameter("rim_strength", 0.0)
			m.set_shader_parameter("specular_strength", 0.0)
		_tex_materials[key] = m
	return _tex_materials[key]


## Toon material for MeshKit's vertex-coloured meshes.
static func vertex_material() -> ShaderMaterial:
	return material_for(null, Color(1, 1, 1), true)


## Solid white used for a few frames when something gets hit.
static func flash_material() -> ShaderMaterial:
	if not _tex_materials.has("flash"):
		var m := ShaderMaterial.new()
		m.shader = TOON_SHADER
		m.set_shader_parameter("flash", 1.0)
		m.set_shader_parameter("tint", Color(1, 1, 1))
		_tex_materials["flash"] = m
	return _tex_materials["flash"]


static func outline_material(thin := false) -> ShaderMaterial:
	if _outline_material == null:
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = OUTLINE_SHADER
		_outline_thin = ShaderMaterial.new()
		_outline_thin.shader = OUTLINE_SHADER
		_outline_thin.set_shader_parameter("width_px", 1.6)
	return _outline_thin if thin else _outline_material


static func _albedo_of(mat: Material) -> Texture2D:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_texture
	if mat is ShaderMaterial:
		return (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
	return null


## Converts every mesh under `root` to the toon look. Returns the list of
## GeometryInstance3D nodes so callers can flash/tint them cheaply.
static func apply(root: Node, outline := true, shadows := true, thin := false, tint := Color(1, 1, 1)) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	_apply_rec(root, outline and outlines_enabled, shadows, thin, tint, out)
	return out


static func _apply_rec(n: Node, outline: bool, shadows: bool, thin: bool, tint: Color, out: Array[GeometryInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and not n.has_meta("outline"):
		var mi := n as MeshInstance3D
		# one toon material per surface, so multi-material models keep their colours
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, _toon_for(mi.get_active_material(si), tint))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(mi)
		if outline:
			var o := MeshInstance3D.new()
			o.mesh = smooth_mesh(mi.mesh)
			o.material_override = outline_material(thin)
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			o.set_meta("outline", true)
			mi.add_child(o)
	for c in n.get_children():
		_apply_rec(c, outline, shadows, thin, tint, out)


static func _toon_for(src: Material, tint: Color) -> Material:
	var tex := _albedo_of(src)
	if tex:
		return material_for(tex, tint)
	if src is BaseMaterial3D and not (src as BaseMaterial3D).vertex_color_use_as_albedo:
		# plain coloured material: keep its colour
		var c := (src as BaseMaterial3D).albedo_color
		return material_for(null, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b))
	return material_for(null, tint, true)


## Outline hull for `mesh`: all surfaces merged, normals averaged per position
## (so the extruded shell stays closed around hard edges) and winding reversed.
static func smooth_mesh(mesh: Mesh) -> ArrayMesh:
	var key := mesh.get_instance_id()
	if _smooth_cache.has(key):
		return _smooth_cache[key]
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var base := positions.size()
		positions.append_array(v)
		normals.append_array(nm)
		var tri := PackedInt32Array()
		if idx == null or (idx as PackedInt32Array).is_empty():
			for i in v.size():
				tri.append(base + i)
		else:
			for i in idx:
				tri.append(base + i)
		# reverse winding: the hull's outward faces get culled, its inside stays
		for t in range(0, tri.size() - 2, 3):
			indices.append(tri[t])
			indices.append(tri[t + 2])
			indices.append(tri[t + 1])
	var sums := {}
	for i in positions.size():
		var k := (positions[i] * 1000.0).round()
		sums[k] = sums.get(k, Vector3.ZERO) + normals[i]
	var smooth := PackedVector3Array()
	smooth.resize(positions.size())
	for i in positions.size():
		var k := (positions[i] * 1000.0).round()
		smooth[i] = (sums[k] as Vector3).normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = smooth
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_smooth_cache[key] = out
	return out
