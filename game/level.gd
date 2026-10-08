class_name Level
extends Node3D
## Builds a map from GameData.MAPS out of Kenney Tower Defense Kit tiles:
## grass, auto-oriented road pieces, trees/rocks, decor around the board, and
## the enemy path curve. Each tile type is one MultiMesh (one draw call).

const TD := "res://assets/models/td/"
const KIT := 2.0 # kit tiles are 1 unit; ours are GameData.TILE (2) units
const TOP := 0.2 * KIT # top surface height of a kit tile, sunk so it sits at y = 0

var map: Dictionary
var cols := 0
var rows := 0
var grid: Array[String] = []
var curve := Curve3D.new()
var path_cells: Array[Vector2i] = []
var spawn_cell := Vector2i.ZERO
var cat_cell := Vector2i.ZERO
var dog_house: Node3D
var _rng := RandomNumberGenerator.new()
var _batches := {} # model name -> Array[Transform3D]


func build(p_map: Dictionary) -> void:
	map = p_map
	_rng.seed = hash(map.id)
	grid.assign(map.grid)
	rows = grid.size()
	cols = grid[0].length()
	for y in rows:
		for x in cols:
			var ch := grid[y][x]
			if ch == "S":
				spawn_cell = Vector2i(x, y)
			elif ch == "C":
				cat_cell = Vector2i(x, y)
	_trace_path()
	_build_curve()
	_build_tiles()
	_build_surroundings()
	_flush_batches()
	_build_spawn()


# ------------------------------------------------------------------ grid helpers
func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x - (cols - 1) * 0.5) * GameData.TILE, 0.0, (c.y - (rows - 1) * 0.5) * GameData.TILE)


func world_to_cell(p: Vector3) -> Vector2i:
	var x := int(round(p.x / GameData.TILE + (cols - 1) * 0.5))
	var y := int(round(p.z / GameData.TILE + (rows - 1) * 0.5))
	return Vector2i(x, y)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func char_at(c: Vector2i) -> String:
	if not in_bounds(c):
		return " "
	return grid[c.y][c.x]


func is_buildable(c: Vector2i) -> bool:
	return char_at(c) == "."


func is_road(ch: String) -> bool:
	return ch == "#" or ch == "S" or ch == "C"


func size_world() -> Vector2:
	return Vector2(cols, rows) * GameData.TILE


# ------------------------------------------------------------------ path
func _trace_path() -> void:
	path_cells.clear()
	var visited := {}
	var cur := spawn_cell
	path_cells.append(cur)
	visited[cur] = true
	var guard := 0
	while cur != cat_cell and guard < 1000:
		guard += 1
		var next := Vector2i(-1, -1)
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = cur + d
			if visited.has(n) or not is_road(char_at(n)):
				continue
			next = n
			break
		if next.x < 0:
			push_error("Map %s: road is broken at %s" % [map.id, cur])
			break
		visited[next] = true
		path_cells.append(next)
		cur = next


func _build_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.2
	var pts: Array[Vector3] = []
	var first_dir := Vector2(path_cells[1] - path_cells[0])
	pts.append(cell_to_world(path_cells[0]) - Vector3(first_dir.x, 0, first_dir.y) * GameData.TILE * 0.3)
	for i in range(1, path_cells.size() - 1):
		var a := path_cells[i] - path_cells[i - 1]
		var b := path_cells[i + 1] - path_cells[i]
		if a != b:
			pts.append(cell_to_world(path_cells[i]))
	pts.append(cell_to_world(path_cells[path_cells.size() - 1]))
	var r := GameData.TILE * 0.5
	for i in pts.size():
		var p := pts[i]
		if i == 0 or i == pts.size() - 1:
			curve.add_point(p)
			continue
		var into := (p - pts[i - 1]).normalized()
		var out := (pts[i + 1] - p).normalized()
		curve.add_point(p - into * r, Vector3.ZERO, into * r * 0.55)
		curve.add_point(p + out * r, -out * r * 0.55, Vector3.ZERO)


# ------------------------------------------------------------------ tiles
func _add(model: String, xf: Transform3D) -> void:
	if not _batches.has(model):
		_batches[model] = []
	_batches[model].append(xf)


func _tile_xf(c: Vector2i, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * KIT), cell_to_world(c) + Vector3(0, -TOP, 0))


## Rotates a grid direction the same way Basis(Vector3.UP, yaw) rotates (x, z)
## for a quarter turn: +X goes to -Z.
static func _rot(d: Vector2i, k: int) -> Vector2i:
	var v := d
	for i in k:
		v = Vector2i(v.y, -v.x)
	return v


## Finds the quarter-turn that maps a tile's canonical openings onto `want`.
static func _fit_rotation(canonical: Array, want: Array) -> int:
	for k in 4:
		var ok := true
		for d in canonical:
			if not want.has(_rot(d, k)):
				ok = false
				break
		if ok:
			return k
	return 0


func _build_tiles() -> void:
	var road_index := {}
	for i in path_cells.size():
		road_index[path_cells[i]] = i
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var ch := char_at(c)
			if road_index.has(c):
				_road_tile(c, road_index[c])
			elif ch == "T":
				var r := _rng.randf()
				_add("tile-tree" if r < 0.4 else ("tile-tree-double" if r < 0.75 else "tile-tree-quad"), _tile_xf(c, _rng.randi_range(0, 3) * PI * 0.5))
			elif ch == "R":
				_add("tile-rock" if _rng.randf() < 0.7 else "tile-crystal", _tile_xf(c, _rng.randi_range(0, 3) * PI * 0.5))
			else:
				# two tints of the same tile model make a soft checkerboard
				_add("tile|a" if (x + y) % 2 == 0 else "tile|b", _tile_xf(c))


func _road_tile(c: Vector2i, i: int) -> void:
	var opens: Array = []
	if i > 0:
		opens.append(path_cells[i - 1] - c)
	if i < path_cells.size() - 1:
		opens.append(path_cells[i + 1] - c)
	if i == 0:
		opens.append(-(path_cells[1] - c)) # the road runs in from off the board
	var model := "tile-straight"
	var canonical: Array = [Vector2i(0, -1), Vector2i(0, 1)]
	if opens.size() == 1:
		model = "tile-end-round"
		canonical = [Vector2i(0, 1)]
	elif opens[0] != -opens[1]:
		model = "tile-corner-round"
		canonical = [Vector2i(0, 1), Vector2i(1, 0)]
	var k := _fit_rotation(canonical, opens)
	_add(model, _tile_xf(c, k * PI * 0.5))


func _build_surroundings() -> void:
	var half := size_world() * 0.5
	# a dirt skirt under the board so its edges read as a thick diorama base
	var under := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(half.x * 2.0, 1.2, half.y * 2.0)
	under.mesh = bm
	under.material_override = Toon.material_for(null, Color("8a5a3c"))
	under.position.y = -TOP - 0.6
	add_child(under)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260, 260)
	ground.mesh = pm
	ground.material_override = Toon.material_for(null, (map.grass[1] as Color).darkened(0.3))
	ground.position.y = -1.0
	add_child(ground)
	# forest and rocks around the board
	var kinds := ["detail-tree", "detail-tree", "detail-tree-large", "detail-tree-large", "detail-rocks", "detail-tree", "detail-crystal", "detail-rocks-large"]
	for i in 320:
		var p := Vector3(_rng.randf_range(-half.x - 16, half.x + 16), -1.0, _rng.randf_range(-half.y - 14, half.y + 10))
		if absf(p.x) < half.x + 0.8 and absf(p.z) < half.y + 0.8:
			continue
		var kind: String = kinds[_rng.randi() % kinds.size()]
		var s := KIT * _rng.randf_range(1.0, 1.7)
		_add(kind, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p))


func _mesh_of(model: String) -> Array:
	# list of [mesh, local transform, albedo texture]
	var scene: PackedScene = load(TD + model + ".glb")
	var inst := scene.instantiate()
	var found := []
	_find_mesh(inst, Transform3D.IDENTITY, found)
	inst.free()
	return found


func _find_mesh(n: Node, xf: Transform3D, out: Array) -> void:
	var x := xf
	if n is Node3D:
		x = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var tex: Texture2D = null
		var mat := mi.get_active_material(0)
		if mat is BaseMaterial3D:
			tex = (mat as BaseMaterial3D).albedo_texture
		out.append([mi.mesh, x, tex])
	for c in n.get_children():
		_find_mesh(c, x, out)


func _flush_batches() -> void:
	for key in _batches:
		var xforms: Array = _batches[key]
		var model: String = key.get_slice("|", 0)
		var tint := Color(1, 1, 1)
		if key.ends_with("|b"):
			tint = Color(0.93, 0.97, 0.9)
		var outline: bool = model.begins_with("detail") or model in ["tile-tree", "tile-tree-double", "tile-tree-quad", "tile-rock", "tile-crystal"]
		for part in _mesh_of(model):
			var list := []
			for x in xforms:
				list.append(x * part[1])
			_multimesh(part[0], list, Toon.material_for(part[2], tint), true)
			if outline and Toon.outlines_enabled:
				_multimesh(Toon.smooth_mesh(part[0]), list, Toon.outline_material(true), false)
	_batches.clear()


func _multimesh(mesh: Mesh, xforms: Array, mat: Material, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _build_spawn() -> void:
	# the pack climbs out of a burrow at the start of the road
	dog_house = Node3D.new()
	add_child(dog_house)
	dog_house.position = cell_to_world(spawn_cell)
	var n: Node3D = load(TD + "spawn-round.glb").instantiate()
	n.scale = Vector3.ONE * KIT * 1.25
	dog_house.add_child(n)
	Toon.apply(n, true, false)


func spawn_wobble() -> void:
	if dog_house == null:
		return
	dog_house.scale = Vector3(1.2, 0.7, 1.2)
	var tw := dog_house.create_tween()
	tw.tween_property(dog_house, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
