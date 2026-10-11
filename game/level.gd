class_name Level
extends Node3D
## Builds a map (from GameData.MAPS or MapGen) out of Kenney Tower Defense Kit tiles:
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
var _srng := RandomNumberGenerator.new() # its own stream for the surroundings
var _batches := {} # model name -> Array[Transform3D]
var _band_tints := {} # outer meadow band suffix ("o0".."o4") -> tint


func build(p_map: Dictionary) -> void:
	map = p_map
	_rng.seed = hash(map.id) + int(map.get("seed", 0))
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
				_add("tile-rock", _tile_xf(c, _rng.randi_range(0, 3) * PI * 0.5))
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


## The board sits in a continuous meadow at the same height (y = 0). Outer ground
## tiles continue the board's grid in distance bands with their own tints (no
## checker), a huge flat plane lies past them, and trees, rocks, bushes and flower
## patches are scattered on top. Margins are in cells from the board edge: widest
## sideways (the camera pans and zooms out most that way), least at the bottom.
const RING_LEFT := 15
const RING_RIGHT := 15
const RING_TOP := 12
const RING_BOTTOM := 11
const BAND_COUNT := 5
const BAND_DITHER := 0.35 # share of band 1-4 tiles that take the next band's tint
const BOARD_TINT := Color(0.965, 0.985, 0.95) # the board's average: white and 0.93/0.97/0.9 checks
const MEADOW_DEEP := Color(0.84, 0.92, 0.74) # where the meadow drifts to: deeper, shadowed green
const BAND_HUE := [Color(1, 1, 1), Color(1.01, 1.0, 0.98), Color(0.99, 1.01, 0.99), Color(1.0, 0.99, 0.96), Color(0.98, 1.0, 0.97)]
const GRASS_AVG := Color8(112, 178, 100) # matched by eye to how the lit tile tops render, so the flat ground blends into the tile ring
const GROUND_Y := -0.4 # below the recessed road tiles so they stay visible; outside the tile ring it is far from the camera
const GROUND_SIZE := 500.0
const SCATTER_PAD := 3.0 # clear strip (1.5 cells) between the board and any scatter
const TREE_PAD := 5.0 # trees keep a clearing of 2.5 cells (5 units) around the board
const SURROUND_SEED := 7919
const FOREST_SHARE := 0.4 # share of cluster centres that are forest clumps (the rest are bush/flower meadow)
const FOREST_BEYOND := 6.0 # scatter reaches this far past the outer ring: the treeline
const FOREST_RAMP := 9.0 # density climbs from the board edge (WEIGHT_EDGE) to full (1.0) over this distance
const WEIGHT_EDGE := 0.15 # acceptance chance right at the keepout
const RIM_NEAR := 5.0 # framing forest clumps on the left, right and top sit this far out from the board...
const RIM_FAR := 14.0 # ...up to this far, drawn mostly from the near end so they land in the default camera view
const RIM_SIDE := [8, 10] # clumps per side (left and right each), spread evenly along the side
const RIM_TOP := [5, 7] # clumps across the top
const TREELINE_NEAR := 5.5 # the ring of single trees runs along a curve this far out...
const TREELINE_FAR := 8.5 # ...to this far out, wobbling in between (the default view shows only ~6 units past the board)
const NEAR_TREE := 8.0 # trees within this of the board are mostly small; the large kit trees take over further out
const FAR_TREE := 16.0 # trees beyond this distance from the board skip the outline pass
const BUSH_COLS := [Color("5a9a48"), Color("4f8f42"), Color("6aa653")]
const FLOWER_COLS := [Color("f08ab4"), Color("f7f3ea"), Color("f6d34a")] # pink, white, yellow


func _build_surroundings() -> void:
	var half := size_world() * 0.5
	_srng.seed = hash(map.id) + int(map.get("seed", 0)) + SURROUND_SEED
	for k in BAND_COUNT:
		var t := float(k) / (BAND_COUNT - 1)
		_band_tints["o%d" % k] = BOARD_TINT.lerp(MEADOW_DEEP, t) * BAND_HUE[k]
	_build_meadow()
	_build_scatter(half)


func _build_meadow() -> void:
	for y in range(-RING_TOP, rows + RING_BOTTOM):
		for x in range(-RING_LEFT, cols + RING_RIGHT):
			var c := Vector2i(x, y)
			if in_bounds(c):
				continue
			# distance from the board edge in cells, as a fraction of this side's margin
			var dx := maxi(0, maxi(-x, x - (cols - 1)))
			var dy := maxi(0, maxi(-y, y - (rows - 1)))
			var fx := float(dx) / (RING_LEFT if x < 0 else RING_RIGHT)
			var fy := float(dy) / (RING_TOP if y < 0 else RING_BOTTOM)
			var band := mini(BAND_COUNT - 1, int(maxf(fx, fy) * BAND_COUNT))
			if band > 0 and _srng.randf() < BAND_DITHER:
				band = band + 1 if band < BAND_COUNT - 1 else band - 1
			var yaw := _srng.randi_range(0, 3) * PI * 0.5
			_add("tile|o%d" % band, _tile_xf(c, yaw))
	# past the tiles: one big flat plane at the same height, in the far meadow colour
	var far_tint: Color = _band_tints["o%d" % (BAND_COUNT - 1)]
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = pm
	ground.material_override = Toon.material_for(null, GRASS_AVG * far_tint, false, true)
	ground.position.y = GROUND_Y
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_scatter(half: Vector2) -> void:
	var bushes := [[], [], []]
	var flowers := [[], [], []]
	_build_rim(half, bushes, flowers)
	_build_treeline(half)
	# cluster centres, drawn denser further out: forest clumps or bush/flower meadows
	var want := _srng.randi_range(34, 40)
	var centres: Array[Vector3] = []
	for i in 8000:
		if centres.size() >= want:
			break
		var p := _meadow_point(half)
		if _clear_of_board(p, half, SCATTER_PAD) and _srng.randf() < _meadow_weight(p, half):
			centres.append(p)
	for c in centres:
		if _srng.randf() < FOREST_SHARE:
			_forest_clump(c, half, bushes, flowers)
		else:
			var n := _srng.randi_range(6, 14)
			var spread := 1.2 + 0.4 * sqrt(float(n))
			for i in n:
				var p := c + Vector3(_srng.randfn(0.0, spread), 0.0, _srng.randfn(0.0, spread))
				_place("bush" if _srng.randf() < 0.4 else "flower", p, half, bushes, flowers)
	# a thin sprinkling of single trees and shrubs so the edge does not read as a pattern
	for i in 130:
		var p := _meadow_point(half)
		if _srng.randf() > _meadow_weight(p, half):
			continue
		var r := _srng.randf()
		var kind: String
		if r < 0.25:
			kind = "tree"
		elif r < 0.35:
			kind = "rock"
		elif r < 0.7:
			kind = "bush"
		else:
			kind = "flower"
		_place(kind, p, half, bushes, flowers)
	# bushes and flower dots: one MultiMesh per colour, no outlines
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.55
	bush_mesh.height = 0.7
	bush_mesh.radial_segments = 6
	bush_mesh.rings = 3
	for k in BUSH_COLS.size():
		if not bushes[k].is_empty():
			_multimesh(bush_mesh, bushes[k], Toon.material_for(null, BUSH_COLS[k]), true)
	var dot := SphereMesh.new()
	dot.radius = 0.14
	dot.height = 0.14
	dot.radial_segments = 5
	dot.rings = 2
	for k in FLOWER_COLS.size():
		if not flowers[k].is_empty():
			_multimesh(dot, flowers[k], Toon.material_for(null, FLOWER_COLS[k]), false)


## A uniform point in the scatter area: inside the outer tile ring, a unit short of its
## edge, and up to FOREST_BEYOND past it so the outer forest reads as a treeline.
func _meadow_point(half: Vector2) -> Vector3:
	var x := _srng.randf_range(-half.x - (RING_LEFT * GameData.TILE - 1.0 + FOREST_BEYOND), half.x + (RING_RIGHT * GameData.TILE - 1.0 + FOREST_BEYOND))
	var z := _srng.randf_range(-half.y - (RING_TOP * GameData.TILE - 1.0 + FOREST_BEYOND), half.y + (RING_BOTTOM * GameData.TILE - 1.0 + FOREST_BEYOND))
	return Vector3(x, 0.0, z)


## Distance from a point to the board rectangle (0 on or inside it).
func _edge_dist(p: Vector3, half: Vector2) -> float:
	var dx := maxf(0.0, absf(p.x) - half.x)
	var dz := maxf(0.0, absf(p.z) - half.y)
	return sqrt(dx * dx + dz * dz)


## Acceptance chance for scatter: WEIGHT_EDGE at the keepout, easing up (smoothstep) to 1
## FOREST_RAMP units out, so the cover is open around the board and dense just beyond it.
func _meadow_weight(p: Vector3, half: Vector2) -> float:
	var t := clampf(_edge_dist(p, half) / FOREST_RAMP, 0.0, 1.0)
	return lerpf(WEIGHT_EDGE, 1.0, t * t * (3.0 - 2.0 * t))


## The framing edge: forest clumps on the left and right sides (RIM_NEAR-RIM_FAR out, stratified
## along the side so there is no bare stretch in view) and a row of closer clumps across the top
## (the default view shows only ~6 units past it). The south side gets none; the sides stop short
## of the south corner so the forest thins toward the bottom and the strip below the board stays open.
func _build_rim(half: Vector2, bushes: Array, flowers: Array) -> void:
	var sides := _srng.randi_range(RIM_SIDE[0], RIM_SIDE[1])
	for k in sides:
		var z := lerpf(-half.y - 8.0, half.y - 2.0, (k + _srng.randf()) / sides)
		for sx in [-1.0, 1.0]:
			var d := RIM_NEAR + (RIM_FAR - RIM_NEAR) * _srng.randf() * _srng.randf()
			_forest_clump(Vector3(sx * (half.x + d), 0.0, z + _srng.randf_range(-1.5, 1.5)), half, bushes, flowers)
	var tops := _srng.randi_range(RIM_TOP[0], RIM_TOP[1])
	for k in tops:
		var x := lerpf(-half.x - 8.0, half.x + 8.0, (k + _srng.randf()) / tops)
		_forest_clump(Vector3(x, 0.0, -half.y - RIM_NEAR - 2.5 * _srng.randf()), half, bushes, flowers)


## A forest clump: 12-40 trees in a tight gaussian core with a looser rim, a few rock piles,
## and bushes around the fringe. Each tree is also thinned by the distance weight.
func _forest_clump(c: Vector3, half: Vector2, bushes: Array, flowers: Array) -> void:
	var trees := _srng.randi_range(12, 40)
	var spread := 1.2 + 0.36 * sqrt(float(trees))
	for i in trees:
		var sig := spread * (0.75 if _srng.randf() < 0.7 else 1.4)
		var p := c + Vector3(_srng.randfn(0.0, sig), 0.0, _srng.randfn(0.0, sig))
		if _srng.randf() < _meadow_weight(p, half):
			_place("tree", p, half, bushes, flowers)
	for i in _srng.randi_range(1, 3):
		var p := c + Vector3(_srng.randfn(0.0, spread), 0.0, _srng.randfn(0.0, spread))
		_place("rock", p, half, bushes, flowers)
	for i in _srng.randi_range(3, 6):
		var a := _srng.randf() * TAU
		var p := c + Vector3(cos(a), 0.0, sin(a)) * spread * _srng.randf_range(1.1, 1.6)
		_place("bush", p, half, bushes, flowers)


## A ring of single trees on an irregular curve TREELINE_NEAR-TREELINE_FAR units out on the
## left, right and top. Walked at 1.6-2.4 unit steps with jitter, and skipped in places
## (random gaps plus a slow wobble) so it reads as a forest edge, not a wall.
func _build_treeline(half: Vector2) -> void:
	var mid := (TREELINE_NEAR + TREELINE_FAR) * 0.5
	var amp := (TREELINE_FAR - TREELINE_NEAR) * 0.5
	var phase0 := _srng.randf_range(0.0, TAU)
	for side in 3: # 0 left, 1 right, 2 top
		var phase := phase0 + side * 1.7
		var start := -half.y - 8.0 if side < 2 else -half.x - 6.0
		var stop := half.y + 2.0 if side < 2 else half.x + 6.0 # the south end tapers off
		var along := start
		while along < stop:
			var depth := maxf(TREE_PAD + 0.2, mid + amp * 0.7 * sin(along * 0.31 + phase) + amp * 0.3 * sin(along * 0.87 + phase * 2.3) + _srng.randf_range(-0.4, 0.4))
			var lat := _srng.randf_range(-0.5, 0.5)
			var gap := sin(along * 0.23 + phase) > 0.55 or _srng.randf() < 0.12
			if not gap:
				var p: Vector3
				if side == 0:
					p = Vector3(-half.x - depth, 0.0, along + lat)
				elif side == 1:
					p = Vector3(half.x + depth, 0.0, along + lat)
				else:
					p = Vector3(along + lat, 0.0, -half.y - depth)
				_add_tree(p, half)
			along += _srng.randf_range(1.6, 2.4)


func _clear_of_board(p: Vector3, half: Vector2, pad: float) -> bool:
	return absf(p.x) > half.x + pad or absf(p.z) > half.y + pad


func _place(kind: String, p: Vector3, half: Vector2, bushes: Array, flowers: Array) -> void:
	# the strip right below the board stays low: no trees, only bushes, flowers and small rocks
	var south := p.z > half.y and absf(p.x) < half.x + 4.0
	match kind:
		"tree":
			if south or not _clear_of_board(p, half, TREE_PAD):
				return
			_add_tree(p, half)
		"rock":
			if not _clear_of_board(p, half, SCATTER_PAD + 0.5):
				return
			var rock_model := "detail-rocks" if south or _srng.randf() < 0.6 else "detail-rocks-large"
			var rock_s := KIT * _srng.randf_range(1.0, 1.7)
			_add(rock_model, Transform3D(Basis(Vector3.UP, _srng.randf() * TAU).scaled(Vector3.ONE * rock_s), Vector3(p.x, 0.0, p.z)))
		"bush":
			if _clear_of_board(p, half, SCATTER_PAD):
				_bush(p, bushes)
		_:
			if _clear_of_board(p, half, SCATTER_PAD):
				_flower_patch(p, flowers)


## One tree at p. Near the board the trees are small detail trees and a little bigger;
## the large kit trees and the bigger scales take over further out.
func _add_tree(p: Vector3, half: Vector2) -> void:
	var d := _edge_dist(p, half)
	var k := clampf((d - 5.0) / 12.0, 0.0, 1.0)
	var large := _srng.randf() < clampf((d - NEAR_TREE) / 10.0 + 0.25, 0.25, 0.75)
	var tree_model := "detail-tree-large" if large else "detail-tree"
	var tree_s := KIT * _srng.randf_range(lerpf(0.9, 1.1, k), lerpf(1.4, 1.8, k))
	# the treeline past FAR_TREE goes in its own batch without outlines (half the cost)
	var key := tree_model + ("|far" if d > FAR_TREE else "")
	_add(key, Transform3D(Basis(Vector3.UP, _srng.randf() * TAU).scaled(Vector3.ONE * tree_s), Vector3(p.x, 0.0, p.z)))


## A bush is 2-3 squashed spheres of one green, sitting on y = 0.
func _bush(p: Vector3, bushes: Array) -> void:
	var col := _srng.randi() % BUSH_COLS.size()
	var s := _srng.randf_range(0.9, 1.4)
	for i in _srng.randi_range(2, 3):
		var sc := s * _srng.randf_range(0.75, 1.1)
		var sy := sc * 0.75
		var off := Vector3(_srng.randf_range(-0.5, 0.5), 0.0, _srng.randf_range(-0.5, 0.5)) * s
		var pos := Vector3(p.x + off.x, 0.35 * sy, p.z + off.z)
		bushes[col].append(Transform3D(Basis.IDENTITY.scaled(Vector3(sc, sy, sc)), pos))


## A small patch of 5-12 flower dots, mostly one colour.
func _flower_patch(p: Vector3, flowers: Array) -> void:
	var main := _srng.randi() % FLOWER_COLS.size()
	var n := _srng.randi_range(5, 12)
	var spread := 0.35 + 0.08 * n
	for i in n:
		var col := main if _srng.randf() < 0.8 else _srng.randi() % FLOWER_COLS.size()
		var q := Vector3(_srng.randfn(0.0, spread), 0.06, _srng.randfn(0.0, spread))
		flowers[col].append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _srng.randf_range(0.8, 1.2)), p + q))


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
		var suffix: String = key.get_slice("|", 1)
		var tint := Color(1, 1, 1)
		if _band_tints.has(suffix):
			tint = _band_tints[suffix] # outer meadow band
		elif key.ends_with("|b"):
			tint = Color(0.93, 0.97, 0.9)
		elif "rock" in model:
			tint = Color(1.0, 0.96, 0.82) # warm the kit's lavender stone to a natural grey
		var outline: bool = (model.begins_with("detail") or model in ["tile-tree", "tile-tree-double", "tile-tree-quad", "tile-rock"]) and suffix != "far"
		# outer meadow tiles are flat ground and far trees sit outside the action: neither casts shadows
		var shadows: bool = not str(key).begins_with("tile|o") and suffix != "far"
		for part in _mesh_of(model):
			var list := []
			for x in xforms:
				list.append(x * part[1])
			_multimesh(part[0], list, Toon.material_for(part[2], tint, false, model.begins_with("tile")), shadows)
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
