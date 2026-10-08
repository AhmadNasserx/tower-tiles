class_name Level
extends Node3D
## Builds a map from GameData.MAPS: ground tiles, road, decorations, the dog
## house and the enemy path curve. Uses MultiMesh everywhere so a whole map is
## only a handful of draw calls.


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
	_build_ground()
	_build_road()
	_build_decor()
	_build_dog_house()


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
	# Keep only corners so the curve can round them off.
	var pts: Array[Vector3] = []
	# start a little behind the dog house so dogs walk out of the door
	var first_dir := Vector2(path_cells[1] - path_cells[0])
	pts.append(cell_to_world(path_cells[0]) - Vector3(first_dir.x, 0, first_dir.y) * GameData.TILE * 0.3)
	for i in range(1, path_cells.size() - 1):
		var a := path_cells[i] - path_cells[i - 1]
		var b := path_cells[i + 1] - path_cells[i]
		if a != b:
			pts.append(cell_to_world(path_cells[i]))
	pts.append(cell_to_world(path_cells[path_cells.size() - 1]))
	var r := GameData.TILE * 0.45
	for i in pts.size():
		var p := pts[i]
		if i == 0 or i == pts.size() - 1:
			curve.add_point(p)
			continue
		var into := (p - pts[i - 1]).normalized()
		var out := (pts[i + 1] - p).normalized()
		# split each corner into two points with handles for a smooth bend
		curve.add_point(p - into * r, Vector3.ZERO, into * r * 0.55)
		curve.add_point(p + out * r, -out * r * 0.55, Vector3.ZERO)
	for i in curve.point_count:
		curve.set_point_position(i, curve.get_point_position(i) + Vector3(0, 0.02, 0))


# ------------------------------------------------------------------ visuals
func _multimesh(mesh: Mesh, xforms: Array, colors: Array = [], shadows := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _tile_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return m


func _build_ground() -> void:
	var grass: Array = map.grass
	var tile := BoxMesh.new()
	tile.size = Vector3(GameData.TILE * 0.94, 0.3, GameData.TILE * 0.94)
	tile.material = _tile_material()
	var xforms := []
	var colors := []
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if is_road(char_at(c)):
				continue
			var p := cell_to_world(c) + Vector3(0, -0.15, 0)
			xforms.append(Transform3D(Basis(), p))
			var col: Color = grass[(x + y) % 2]
			col = col.lightened(_rng.randf_range(-0.03, 0.04))
			colors.append(col)
	_multimesh(tile, xforms, colors)

	# soil underneath the grid + the wider world
	var under := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sw := size_world()
	bm.size = Vector3(sw.x + 0.3, 0.6, sw.y + 0.3)
	bm.material = MeshKit.color_material(Color("6b4f3a"))
	under.mesh = bm
	under.position.y = -0.42
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(under)

	var world := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	pm.material = MeshKit.color_material((grass[1] as Color).darkened(0.35))
	world.mesh = pm
	world.position.y = -0.7
	world.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(world)


func _build_road() -> void:
	var road_col: Color = map.road
	var tile := BoxMesh.new()
	tile.size = Vector3(GameData.TILE, 0.24, GameData.TILE)
	tile.material = _tile_material()
	var xforms := []
	var colors := []
	for c in path_cells:
		xforms.append(Transform3D(Basis(), cell_to_world(c) + Vector3(0, -0.17, 0)))
		colors.append(road_col.lightened(_rng.randf_range(-0.03, 0.03)))
	_multimesh(tile, xforms, colors)

	# pebbles and paw prints along the road
	var pk := MeshKit.new()
	pk.sphere(Vector3(0, 0, 0), Vector3(0.12, 0.05, 0.1), Color(1, 1, 1), Vector3.ZERO, 6)
	var pebble := pk.build()
	var pebbles := []
	var pcols := []
	var paw_k := MeshKit.new()
	paw_k.sphere(Vector3(0, 0, 0.05), Vector3(0.11, 0.02, 0.09), Color(1, 1, 1), Vector3.ZERO, 8)
	for i in 4:
		var a := deg_to_rad(-60 + i * 40)
		paw_k.sphere(Vector3(sin(a) * 0.13, 0, -cos(a) * 0.13 - 0.02), Vector3(0.04, 0.02, 0.05), Color(1, 1, 1), Vector3.ZERO, 6)
	var paw := paw_k.build()
	var paws := []
	var paw_cols := []
	for i in path_cells.size():
		var base := cell_to_world(path_cells[i])
		for j in 2:
			var off := Vector3(_rng.randf_range(-0.8, 0.8), 0.07, _rng.randf_range(-0.8, 0.8))
			pebbles.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.3)), base + off))
			pcols.append(road_col.darkened(_rng.randf_range(0.15, 0.3)))
		if i % 2 == 1 and i < path_cells.size() - 1:
			var dir := Vector2(path_cells[i + 1] - path_cells[i - 1])
			var yaw := atan2(-dir.x, -dir.y)
			for side in [-1, 1]:
				var perp: Vector3 = Vector3(-dir.y, 0, dir.x).normalized() * 0.3 * side
				var along: Vector3 = Vector3(dir.x, 0, dir.y).normalized() * 0.3 * side
				paws.append(Transform3D(Basis(Vector3.UP, yaw), base + perp + along + Vector3(0, 0.06, 0)))
				paw_cols.append(road_col.darkened(0.22))
	_multimesh(pebble, pebbles, pcols)
	_multimesh(paw, paws, paw_cols)


static func _tree_meshes() -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	var trunk := Color("8b5e3c")
	# round leafy tree
	var k := MeshKit.new()
	k.cylinder(Vector3(0, 0.5, 0), 0.16, 1.0, trunk, Vector3.ZERO, 0.7, 6)
	k.sphere(Vector3(0, 1.45, 0), Vector3(0.8, 0.7, 0.8), Color("4caf50"), Vector3.ZERO, 8)
	k.sphere(Vector3(0.35, 1.85, 0.1), Vector3(0.5, 0.45, 0.5), Color("66bb6a"), Vector3.ZERO, 8)
	k.sphere(Vector3(-0.3, 1.75, -0.2), Vector3(0.45, 0.42, 0.45), Color("43a047"), Vector3.ZERO, 8)
	out.append(k.build())
	# pine
	k = MeshKit.new()
	k.cylinder(Vector3(0, 0.3, 0), 0.14, 0.6, trunk, Vector3.ZERO, 0.8, 6)
	k.cone(Vector3(0, 1.0, 0), 0.8, 1.1, Color("2e7d5b"), Vector3.ZERO, 7)
	k.cone(Vector3(0, 1.6, 0), 0.62, 0.95, Color("358f67"), Vector3.ZERO, 7)
	k.cone(Vector3(0, 2.15, 0), 0.42, 0.8, Color("3fa374"), Vector3.ZERO, 7)
	out.append(k.build())
	# cherry blossom
	k = MeshKit.new()
	k.cylinder(Vector3(0, 0.55, 0), 0.15, 1.1, Color("7a4b3a"), Vector3(0, 0, 6), 0.7, 6)
	k.sphere(Vector3(0.1, 1.5, 0), Vector3(0.75, 0.6, 0.75), Color("ffb3c6"), Vector3.ZERO, 8)
	k.sphere(Vector3(-0.35, 1.7, 0.2), Vector3(0.45, 0.4, 0.45), Color("ff9fbf"), Vector3.ZERO, 8)
	k.sphere(Vector3(0.4, 1.85, -0.15), Vector3(0.4, 0.38, 0.4), Color("ffc8d8"), Vector3.ZERO, 8)
	out.append(k.build())
	return out


static func _rock_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.sphere(Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 0.5), Color("a7a9b4"), Vector3(0, 20, 8), 6)
	k.sphere(Vector3(0.45, 0.15, 0.25), Vector3(0.35, 0.28, 0.3), Color("9196a3"), Vector3(0, -30, 0), 6)
	k.sphere(Vector3(-0.35, 0.12, -0.3), Vector3(0.28, 0.2, 0.25), Color("b5b8c2"), Vector3.ZERO, 6)
	return k.build()


func _build_decor() -> void:
	var tree_meshes := _tree_meshes()
	var trees := [[], [], []]
	var rocks := []
	var flowers := []
	var flower_cols := []
	var tree_scale := GameData.TILE * 0.5
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var ch := char_at(c)
			var p := cell_to_world(c)
			if ch == "T":
				trees[_tree_kind()].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * tree_scale * _rng.randf_range(0.85, 1.15)), p))
			elif ch == "R":
				rocks.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * tree_scale * _rng.randf_range(0.7, 1.0)), p))
	# frame the map with a forest so it feels like a garden diorama
	var half := size_world() * 0.5
	for i in 260:
		var p := Vector3(_rng.randf_range(-half.x - 14, half.x + 14), 0, _rng.randf_range(-half.y - 12, half.y + 10))
		if absf(p.x) < half.x + 1.2 and absf(p.z) < half.y + 1.2:
			continue
		p.y = -0.7
		var s := tree_scale * _rng.randf_range(0.9, 1.5)
		if _rng.randf() < 0.85:
			trees[_tree_kind()].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p))
		else:
			rocks.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s * 0.8), p))
	for i in tree_meshes.size():
		if not trees[i].is_empty():
			_multimesh(tree_meshes[i], trees[i], [], true)
	_multimesh(_rock_mesh(), rocks, [], true)

	# flowers on blocked tiles and around the edge
	var fk := MeshKit.new()
	for i in 5:
		var a := TAU * i / 5.0
		fk.sphere(Vector3(cos(a) * 0.09, 0.12, sin(a) * 0.09), Vector3(0.07, 0.03, 0.07), Color(1, 1, 1), Vector3.ZERO, 6)
	fk.sphere(Vector3(0, 0.13, 0), Vector3.ONE * 0.05, Color("ffd23f"), Vector3.ZERO, 6)
	fk.cylinder(Vector3(0, 0.05, 0), 0.015, 0.12, Color("3f8f4a"))
	var flower := fk.build()
	var palette := [Color("ffffff"), Color("ff7eb6"), Color("a66cff"), Color("5dade2"), Color("ffb3c6")]
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var ch := char_at(c)
			if ch == "T" or ch == "R":
				for j in 3:
					var fp := cell_to_world(c) + Vector3(_rng.randf_range(-0.85, 0.85), 0.0, _rng.randf_range(-0.85, 0.85))
					flowers.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.9, 1.4)), fp))
					flower_cols.append(palette[_rng.randi() % palette.size()])
	for i in 140:
		var fp2 := Vector3(_rng.randf_range(-half.x - 8, half.x + 8), -0.7, _rng.randf_range(-half.y - 8, half.y + 6))
		if absf(fp2.x) < half.x + 0.5 and absf(fp2.z) < half.y + 0.5:
			continue
		flowers.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * 1.6), fp2))
		flower_cols.append(palette[_rng.randi() % palette.size()])
	_multimesh(flower, flowers, flower_cols)


func _build_dog_house() -> void:
	dog_house = Node3D.new()
	add_child(dog_house)
	dog_house.position = cell_to_world(spawn_cell)
	var dir := Vector2(path_cells[1] - path_cells[0])
	dog_house.rotation.y = atan2(-dir.x, -dir.y) + PI
	var wall := Color("c0504d")
	var roof := Color("6b4f3a")
	var k := MeshKit.new()
	k.box(Vector3(0, 0.6, 0), Vector3(1.5, 1.2, 1.4), wall)
	k.box(Vector3(-0.42, 1.45, 0), Vector3(1.05, 0.12, 1.6), roof, Vector3(0, 0, 38))
	k.box(Vector3(0.42, 1.45, 0), Vector3(1.05, 0.12, 1.6), roof, Vector3(0, 0, -38))
	# door faces +Z locally (we rotated the house so +Z points down the road)
	k.box(Vector3(0, 0.45, 0.68), Vector3(0.7, 0.85, 0.06), Color("2a1f33"))
	k.sphere(Vector3(0, 0.88, 0.68), Vector3(0.35, 0.3, 0.03), Color("2a1f33"))
	# bone sign
	k.cylinder(Vector3(0, 1.3, 0.75), 0.05, 0.5, Color("fff4e0"), Vector3(0, 0, 90))
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			k.sphere(Vector3(0.27 * sx, 1.3 + 0.06 * sy, 0.75), Vector3.ONE * 0.07, Color("fff4e0"), Vector3.ZERO, 6)
	# food bowl
	k.cylinder(Vector3(0.9, 0.08, 0.5), 0.25, 0.16, Color("5dade2"), Vector3.ZERO, 1.3, 10)
	MeshKit.instance(k.build(), dog_house)


func _tree_kind() -> int:
	var r := _rng.randf()
	return 0 if r < 0.5 else (1 if r < 0.82 else 2)


func spawn_wobble() -> void:
	if dog_house == null:
		return
	dog_house.scale = Vector3(1.15, 0.85, 1.15)
	var tw := dog_house.create_tween()
	tw.tween_property(dog_house, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
