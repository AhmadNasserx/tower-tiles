class_name GameData
## Static design data: kittens (turrets), dogs (enemies), perks, meta upgrades,
## maps and the wave generator. Tweak numbers here to rebalance the game.

const TILE := 2.0
const WAVES_TO_WIN := 20
const BASE_LIVES := 9
const BASE_GOLD := 180
const SELL_REFUND := 0.7

# ------------------------------------------------------------------ palette
const C_CREAM := Color("fff4e0")
const C_ORANGE := Color("ff9f43")
const C_PINK := Color("ff7eb6")
const C_GOLD := Color("ffd23f")
const C_RED := Color("ff4d6d")
const C_GREEN := Color("7bd389")
const C_PURPLE := Color("a66cff")

# ------------------------------------------------------------------ kittens
# Each level entry holds that level's stats; "up" is the price to reach it.
const TURRETS := {
	"yarn": {
		"name": "Yarn Kitty", "cost": 60, "kind": "projectile", "key": "1",
		"desc": "Launches yarn balls with a tiny ballista. Cheap, reliable, adorable.",
		"fur": Color("9aa5b1"), "accent": Color("ff5c8a"), "icon": "yarn",
		"levels": [
			{"dmg": 10.0, "rate": 1.3, "range": 6.5},
			{"dmg": 17.0, "rate": 1.5, "range": 7.0, "up": 50},
			{"dmg": 28.0, "rate": 1.75, "range": 7.5, "up": 95},
			{"dmg": 42.0, "rate": 2.1, "range": 8.0, "up": 170, "multishot": 2},
		],
	},
	"hiss": {
		"name": "Hiss Box", "cost": 80, "kind": "pulse", "key": "2",
		"desc": "Hisses in a ring, slowing every critter nearby. Max level stuns.",
		"fur": Color("3b3b48"), "accent": Color("7fd8ff"), "icon": "hiss",
		"levels": [
			{"dmg": 5.0, "rate": 0.7, "range": 5.0, "slow": 0.35, "slow_time": 1.6},
			{"dmg": 9.0, "rate": 0.8, "range": 5.5, "slow": 0.42, "slow_time": 1.8, "up": 70},
			{"dmg": 15.0, "rate": 0.9, "range": 6.0, "slow": 0.5, "slow_time": 2.0, "up": 120},
			{"dmg": 24.0, "rate": 1.0, "range": 6.5, "slow": 0.55, "slow_time": 2.2, "stun": 0.45, "up": 210},
		],
	},
	"fish": {
		"name": "Fish Cannon", "cost": 110, "kind": "lob", "key": "3",
		"desc": "Lobs smelly fish that splash every critter in the area.",
		"fur": Color("ff9f43"), "accent": Color("5dade2"), "icon": "fish",
		"levels": [
			{"dmg": 26.0, "rate": 0.55, "range": 8.0, "splash": 2.2},
			{"dmg": 44.0, "rate": 0.6, "range": 8.5, "splash": 2.5, "up": 90},
			{"dmg": 70.0, "rate": 0.65, "range": 9.0, "splash": 2.8, "up": 155},
			{"dmg": 115.0, "rate": 0.72, "range": 9.5, "splash": 3.4, "up": 250},
		],
	},
	"laser": {
		"name": "Laser Kitty", "cost": 130, "kind": "beam", "key": "4",
		"desc": "Locks a laser pointer on one critter. Damage ramps up the longer it stares.",
		"fur": Color("f5f0e6"), "accent": Color("ff2d55"), "icon": "laser",
		"levels": [
			{"dps": 16.0, "range": 6.0, "ramp": 2.5},
			{"dps": 28.0, "range": 6.5, "ramp": 2.75, "up": 100},
			{"dps": 44.0, "range": 7.0, "ramp": 3.0, "up": 175},
			{"dps": 66.0, "range": 7.5, "ramp": 3.0, "chain": 2, "up": 270},
		],
	},
	"fatcat": {
		"name": "Fat Cat", "cost": 100, "kind": "income", "key": "5",
		"desc": "Naps on a pile of coins. Pays out gold after every wave.",
		"fur": Color("e8a15c"), "accent": Color("ffd23f"), "icon": "coin",
		"levels": [
			{"income": 18, "range": 0.0},
			{"income": 32, "range": 0.0, "up": 90},
			{"income": 50, "range": 0.0, "up": 140},
			{"income": 75, "range": 0.0, "up": 220},
		],
	},
}
const TURRET_ORDER := ["yarn", "hiss", "fish", "laser", "fatcat"]
const TARGET_MODES := ["First", "Last", "Strong", "Close"]

# ------------------------------------------------------------------ dogs
const ENEMIES := {
	"pup": {"name": "Pup", "hp": 26.0, "speed": 3.6, "armor": 0.0, "gold": 3, "lives": 1,
		"model": "dog", "scale": 0.39, "tint": Color(1, 1, 1), "coat": Color("e09a4f"), "threat": 1.0, "interval": 0.55},
	"hound": {"name": "Hound", "hp": 60.0, "speed": 2.8, "armor": 0.0, "gold": 5, "lives": 1,
		"model": "dog", "scale": 0.55, "tint": Color(0.8, 0.62, 0.5), "coat": Color("a0643b"), "threat": 2.0, "interval": 0.8},
	"greyhound": {"name": "Fox", "hp": 40.0, "speed": 5.4, "armor": 0.0, "gold": 5, "lives": 1,
		"model": "fox", "scale": 0.48, "tint": Color(1, 1, 1), "coat": Color("ff8a3d"), "threat": 2.0, "interval": 0.6},
	"poodle": {"name": "Nurse Bunny", "hp": 90.0, "speed": 2.5, "armor": 0.0, "gold": 9, "lives": 1,
		"model": "bunny", "scale": 0.49, "tint": Color(1.25, 1.0, 1.15), "coat": Color("f59ac8"), "threat": 4.0, "interval": 1.2, "healer": true},
	"bulldog": {"name": "Boar", "hp": 180.0, "speed": 1.7, "armor": 3.0, "gold": 11, "lives": 2,
		"model": "hog", "scale": 0.63, "tint": Color(1, 1, 1), "coat": Color("c46a4a"), "threat": 5.0, "interval": 1.6},
	"alpha": {"name": "Alpha Hound", "hp": 620.0, "speed": 1.5, "armor": 3.0, "gold": 120, "lives": 3,
		"model": "dog", "scale": 0.94, "tint": Color(0.5, 0.46, 0.62), "coat": Color("4b4e5c"), "threat": 0.0, "interval": 2.0, "boss": true},
	"vacuum": {"name": "Big Ellie", "hp": 1700.0, "speed": 1.1, "armor": 5.0, "gold": 220, "lives": 5,
		"model": "elephant", "scale": 0.91, "tint": Color(1, 1, 1), "coat": Color("a9b0d6"), "threat": 0.0, "interval": 2.0, "boss": true},
}
const UNLOCK_WAVE := {"pup": 1, "hound": 2, "greyhound": 4, "bulldog": 6, "poodle": 8}

# ------------------------------------------------------------------ perks
const PERKS := {
	"claws": {"name": "Sharp Claws", "desc": "All kittens deal +15% damage.", "icon": "paw", "color": Color("ff6b6b"), "max": 5},
	"caffeine": {"name": "Catfeine", "desc": "All kittens attack 12% faster.", "icon": "bolt", "color": Color("ffd23f"), "max": 5},
	"eyes": {"name": "Eagle Eyes", "desc": "All kittens get +12% range.", "icon": "eye", "color": Color("5dade2"), "max": 3},
	"burglar": {"name": "Cat Burglar", "desc": "Critters drop 20% more gold.", "icon": "coin", "color": Color("ffd23f"), "max": 4},
	"interest": {"name": "Hoarder", "desc": "Earn 6% interest on your gold after each wave (max 60).", "icon": "coin", "color": Color("7bd389"), "max": 3},
	"bigpaw": {"name": "Big Paw Energy", "desc": "Paw Slam hits 50% harder and 20% wider.", "icon": "paw", "color": Color("ff9f43"), "max": 3},
	"quickpaws": {"name": "Quick Paws", "desc": "Abilities recharge 20% faster.", "icon": "bolt", "color": Color("a66cff"), "max": 3},
	"ninth": {"name": "Ninth Life", "desc": "Gain 2 lives (and raise your max).", "icon": "heart", "color": Color("ff4d6d"), "max": 3},
	"catalog": {"name": "Discount Catalog", "desc": "Kittens and upgrades cost 12% less.", "icon": "coin", "color": Color("ffb3c6"), "max": 2},
	"crit": {"name": "Lucky Whiskers", "desc": "+10% chance to crit for 2.5x damage.", "icon": "star", "color": Color("ffd23f"), "max": 3},
	"frost": {"name": "Spine Chiller", "desc": "Hiss Boxes slow 15% harder and hit twice as hard.", "icon": "hiss", "color": Color("7fd8ff"), "max": 2},
	"hotfish": {"name": "Extra Smelly", "desc": "Fish splash 30% wider and +20% damage.", "icon": "fish", "color": Color("ff9f43"), "max": 2},
	"yarnstorm": {"name": "Yarn Storm", "desc": "Yarn Kitties throw an extra yarn ball.", "icon": "yarn", "color": Color("ff5c8a"), "max": 2},
	"focus": {"name": "Laser Focus", "desc": "Laser Kitties ramp up twice as fast and +25% damage.", "icon": "laser", "color": Color("ff2d55"), "max": 2},
	"heroic": {"name": "Hero Cat", "desc": "Your cat throws hairballs 40% faster and harder.", "icon": "cat", "color": Color("ff9f43"), "max": 3},
	"fatter": {"name": "Fat Stacks", "desc": "Fat Cats pay out 35% more.", "icon": "coin", "color": Color("e8a15c"), "max": 2},
}

# ------------------------------------------------------------------ meta (persistent)
const META := {
	"gold": {"name": "Piggy Bank", "desc": "+30 starting gold", "icon": "coin", "base": 15, "max": 5},
	"lives": {"name": "Spare Life", "desc": "+1 starting life", "icon": "heart", "base": 40, "max": 3},
	"claws": {"name": "Scratching Post", "desc": "+6% kitten damage", "icon": "paw", "base": 20, "max": 5},
	"hero": {"name": "Hero Training", "desc": "Your cat hits 25% harder, 10% faster", "icon": "cat", "base": 15, "max": 5},
	"paw": {"name": "Heavy Paw", "desc": "+25% Paw Slam damage", "icon": "paw", "base": 20, "max": 4},
	"magnet": {"name": "Treat Magnet", "desc": "+6% gold from critters", "icon": "coin", "base": 20, "max": 5},
	"cooldown": {"name": "Power Nap", "desc": "Abilities recharge 8% faster", "icon": "bolt", "base": 25, "max": 4},
	"discount": {"name": "Bulk Kibble", "desc": "Kittens cost 4% less", "icon": "coin", "base": 25, "max": 5},
	"reroll": {"name": "Lucky Paw", "desc": "+1 perk reroll per run", "icon": "star", "base": 30, "max": 3},
}
const META_ORDER := ["gold", "lives", "claws", "hero", "paw", "magnet", "cooldown", "discount", "reroll"]


static func meta_cost(id: String, level: int) -> int:
	var base: float = META[id].base
	return int(round(base * pow(1.0 + level, 1.6) / 5.0) * 5)


# ------------------------------------------------------------------ abilities
const PAW_DAMAGE := 160.0
const PAW_RADIUS := 3.2
const PAW_COOLDOWN := 22.0
const ZOOMIES_COOLDOWN := 45.0
const ZOOMIES_TIME := 7.0
const HERO_DAMAGE := 9.0
const HERO_RATE := 1.0
const HERO_RANGE := 9.0

# ------------------------------------------------------------------ maps
# Legend: '.' grass you can build on, '#' road, 'S' dog house (spawn),
# 'C' your cat's tower, 'T' tree, 'R' rock. Roads must not touch sideways.
const MAPS := [
	{
		"id": "backyard", "name": "The Backyard", "difficulty": 0.9, "gold_bonus": 0,
		"desc": "A long winding road. Perfect for a first nap... er, defense.",
		"grass": [Color("8fd16a"), Color("82c45f")], "road": Color("e6c98f"),
		"grid": [
			"T..R....TT.....T..R.T.",
			"S#####.........T......",
			".....#..#########..R..",
			".T...#..#.......#.....",
			".....#..#..TT...#..T..",
			"..R..#..#.......#.....",
			".....####..R....#.....",
			"................#.TT..",
			"..T..#######....#.....",
			".....#.....#....#.....",
			".....#..R..######..R..",
			".....C................",
			"T....................T",
		],
	},
	{
		"id": "garden", "name": "Garden Maze", "difficulty": 1.2, "gold_bonus": 20,
		"desc": "Hedges everywhere. Bulldogs love it here.",
		"grass": [Color("6fc276"), Color("63b46b")], "road": Color("d8b98a"),
		"grid": [
			"......T.......T.......",
			".R.#######.......R....",
			"...#.....#..TT........",
			"...#.....#....######..",
			"...#..T..#....#....#..",
			"S###.....#....#.R..#..",
			".........#....#....#..",
			"..TT.....######....#..",
			"...................#..",
			"..R..C#######......#..",
			"............#......#..",
			"............########..",
			"T......T...........R.T",
		],
	},
	{
		"id": "dogpark", "name": "The Dog Park", "difficulty": 1.2, "gold_bonus": 90,
		"desc": "Short road, big crowds. Only legends keep all nine lives.",
		"grass": [Color("a5d86b"), Color("97ca60")], "road": Color("cdb48c"),
		"grid": [
			"T.....R.......T......T",
			"......................",
			"..##########.....R....",
			"..#........#..........",
			"..#..TT....#..#######S",
			"..#........#..#.......",
			"..#..R.....####..TT...",
			"..#...................",
			"..#######...R.........",
			"........#.............",
			".....C###......T......",
			"......................",
			"T.........R..........T",
		],
	},
]


# ------------------------------------------------------------------ waves
static func hp_mult(wave: int, difficulty: float) -> float:
	var n := float(wave - 1)
	# gentle early, steep late: maxed kittens with perks hit very hard
	return (1.0 + 0.12 * n + 0.02 * n * n + 0.0025 * n * n * n) * difficulty


## Bosses scale more gently so a single big dog doesn't decide the whole run.
static func boss_hp_mult(wave: int, difficulty: float) -> float:
	var n := float(wave - 1)
	return (1.0 + 0.1 * n + 0.01 * n * n) * difficulty


static func is_boss_wave(wave: int) -> bool:
	return wave % 5 == 0


## Returns a list of spawn events: [{"t": seconds, "type": String}], sorted.
static func build_wave(wave: int, difficulty: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wave%d-%f" % [wave, difficulty])
	var budget := (6.0 + 4.0 * wave + 0.3 * wave * wave) * lerpf(1.0, difficulty, 0.5)
	var pool: Array[String] = []
	for t in UNLOCK_WAVE:
		if wave >= UNLOCK_WAVE[t]:
			pool.append(t)
	var events: Array = []
	var time := 0.0
	var speedup: float = max(0.45, 1.0 - wave * 0.025)

	if is_boss_wave(wave):
		var boss := "alpha" if (wave / 5) % 2 == 1 else "vacuum"
		budget *= 0.55
		events.append({"t": 0.0, "type": boss})
		time = 2.5

	# Pick 1-3 groups per wave; later waves mix more types.
	var groups := clampi(1 + wave / 4, 1, 3)
	var newest: String = pool[pool.size() - 1]
	for g in groups:
		var type: String
		if g == 0 and UNLOCK_WAVE[newest] == wave:
			type = newest # introduce the newest dog on the wave it unlocks
		else:
			type = pool[rng.randi_range(0, pool.size() - 1)]
		var share := budget / float(groups - g) if g == groups - 1 else budget * rng.randf_range(0.3, 0.6)
		var def: Dictionary = ENEMIES[type]
		var count := maxi(1, int(round(share / def.threat)))
		budget -= count * def.threat
		var interval: float = def.interval * speedup
		for i in count:
			events.append({"t": time, "type": type})
			time += interval
		time += 1.4
		if budget <= 0.5:
			break
	events.sort_custom(func(a, b): return a.t < b.t)
	return events


## A short summary of a wave for the HUD: {"type": count}
static func wave_summary(events: Array) -> Dictionary:
	var out := {}
	for e in events:
		out[e.type] = int(out.get(e.type, 0)) + 1
	return out
