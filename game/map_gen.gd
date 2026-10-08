class_name MapGen
## Procedural maps for the "Wild Meadow" mode: a new winding road, trees and
## rocks every run, in the same ASCII format as GameData.MAPS.
##
## The road is a random self-avoiding walk on a coarse lattice of nodes at
## even (x, y) cells; the cell between two consecutive nodes is filled in too.
## Because road cells only ever sit on nodes or between two linked nodes, the
## road can never touch itself sideways, which the level builder relies on.

const COLS := 22
const ROWS := 13
const MIN_NODES := 22 # road length ~ 2 * nodes cells
const MAX_NODES := 30

const ID := "wild"
const NAME := "Wild Meadow"


static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var nodes: Array[Vector2i] = []
	for attempt in 200:
		nodes = _walk(rng)
		if nodes.size() >= MIN_NODES:
			break
	var grid: Array = []
	for y in ROWS:
		grid.append(".".repeat(COLS))
	var road := {}
	for i in nodes.size():
		road[nodes[i]] = true
		if i > 0:
			road[(nodes[i] + nodes[i - 1]) / 2] = true
	for c in road:
		_put(grid, c, "#")
	_put(grid, nodes[0], "S")
	_put(grid, nodes[nodes.size() - 1], "C")
	# trees and rocks: sparse on the board, never touching the road (those
	# tiles are the best build spots) and never next to the cat's tower
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if road.has(c) or _near(road, c):
				continue
			var r := rng.randf()
			if r < 0.11:
				_put(grid, c, "T")
			elif r < 0.15:
				_put(grid, c, "R")
	var palettes := [
		[Color("8fd16a"), Color("82c45f"), Color("e6c98f")],
		[Color("7fcf7a"), Color("72c06d"), Color("e3c28a")],
		[Color("a5d86b"), Color("97ca60"), Color("d9bd8c")],
	]
	var pal: Array = palettes[rng.randi() % palettes.size()]
	return {
		"id": ID, "name": NAME, "difficulty": 1.1, "gold_bonus": 30, "seed": seed_value,
		"desc": "A brand-new road every run. No two meadows are alike.",
		"grass": [pal[0], pal[1]], "road": pal[2],
		"grid": grid,
	}


## Random depth-first walk from a node on the left or right edge. Returns the
## longest path found (capped at MAX_NODES).
static func _walk(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var w := COLS / 2 # node columns: x = 0, 2, ... 20
	var h := (ROWS + 1) / 2 # node rows: y = 0, 2, ... 12
	var start_x := 0 if rng.randf() < 0.5 else w - 1
	var start := Vector2i(start_x, rng.randi_range(1, h - 2))
	var path: Array[Vector2i] = [start]
	var visited := {start: true}
	var best: Array[Vector2i] = path.duplicate()
	var options := [] # per depth: remaining shuffled directions
	options.append(_dirs(rng))
	var steps := 0
	while not path.is_empty() and steps < 4000:
		steps += 1
		# only accept endings away from the board edge, so the cat's tower is
		# never tucked under the HUD
		var tip: Vector2i = path[path.size() - 1]
		var interior := tip.x > 1 and tip.x < w - 2 and tip.y > 1 and tip.y < h - 1
		if interior and path.size() > best.size():
			best = path.duplicate()
		if path.size() >= MAX_NODES:
			if interior:
				break
			# too long and ending at the edge: back up and try another branch
			path.pop_back()
			options.pop_back()
			visited.erase(tip)
			continue
		var opts: Array = options[options.size() - 1]
		if opts.is_empty():
			path.pop_back()
			options.pop_back()
			continue
		var d: Vector2i = opts.pop_back()
		var n: Vector2i = path[path.size() - 1] + d
		if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or visited.has(n):
			continue
		# don't hug the outer edge after leaving it: keeps the road on the board
		if path.size() > 1 and (n.x == 0 or n.x == w - 1):
			continue
		visited[n] = true
		path.append(n)
		options.append(_dirs(rng, d))
	var out: Array[Vector2i] = []
	for n in best:
		out.append(n * 2)
	return out


## Shuffled directions, with a bias toward going straight for a few steps so
## the road winds instead of zig-zagging every tile.
static func _dirs(rng: RandomNumberGenerator, prev := Vector2i.ZERO) -> Array:
	var d := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	for i in range(d.size() - 1, 0, -1): # seeded shuffle, so a seed always gives the same map
		var j := rng.randi_range(0, i)
		var tmp: Vector2i = d[i]
		d[i] = d[j]
		d[j] = tmp
	if prev != Vector2i.ZERO and rng.randf() < 0.45:
		d.erase(prev)
		d.append(prev) # popped first
	return d


static func _put(grid: Array, c: Vector2i, ch: String) -> void:
	var row: String = grid[c.y]
	grid[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)


static func _near(road: Dictionary, c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if road.has(c + Vector2i(dx, dy)):
				return true
	return false
