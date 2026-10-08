extends Node
## Persistent player progress and settings. On the web, user:// is backed by
## IndexedDB, so progress survives page reloads.

signal fish_changed(amount: int)
signal settings_changed

const PATH := "user://nine_lives_save.json"

var fish := 0
var meta := {} # meta upgrade id -> level
var stars := {} # map id -> best stars (0-3)
var best_wave := {} # map id -> best wave reached
var settings := {
	"master": 0.8,
	"music": 0.6,
	"sfx": 0.8,
	"shake": true,
	"quality": "high",
	"tutorial_done": false,
}
var stats := {"runs": 0, "dogs_bonked": 0, "fish_earned": 0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _is_low_end_web():
		settings.quality = "low"
	load_game()


func _is_low_end_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios")


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	fish = int(data.get("fish", 0))
	meta = _int_dict(data.get("meta", {}))
	stars = _int_dict(data.get("stars", {}))
	best_wave = _int_dict(data.get("best_wave", {}))
	var s: Dictionary = data.get("settings", {})
	for k in s:
		settings[k] = s[k]
	var st: Dictionary = data.get("stats", {})
	for k in st:
		stats[k] = int(st[k])


func _int_dict(d) -> Dictionary:
	var out := {}
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			out[k] = int(d[k])
	return out


func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify({
		"fish": fish,
		"meta": meta,
		"stars": stars,
		"best_wave": best_wave,
		"settings": settings,
		"stats": stats,
	}))


func add_fish(amount: int) -> void:
	fish += amount
	stats.fish_earned += max(amount, 0)
	fish_changed.emit(fish)
	save_game()


func meta_level(id: String) -> int:
	return int(meta.get(id, 0))


func buy_meta(id: String) -> bool:
	var def: Dictionary = GameData.META[id]
	var lvl := meta_level(id)
	if lvl >= def.max:
		return false
	var cost := GameData.meta_cost(id, lvl)
	if fish < cost:
		return false
	fish -= cost
	meta[id] = lvl + 1
	fish_changed.emit(fish)
	save_game()
	return true


func refund_meta() -> void:
	var total := 0
	for id in meta:
		for l in int(meta[id]):
			total += GameData.meta_cost(id, l)
	meta.clear()
	fish += total
	fish_changed.emit(fish)
	save_game()


func record_run(map_id: String, wave: int, star_count: int) -> void:
	stats.runs += 1
	best_wave[map_id] = max(int(best_wave.get(map_id, 0)), wave)
	stars[map_id] = max(int(stars.get(map_id, 0)), star_count)
	save_game()


func map_unlocked(index: int) -> bool:
	if index == 0:
		return true
	var prev: String = GameData.MAPS[index - 1].id
	return int(stars.get(prev, 0)) > 0


func set_setting(key: String, value) -> void:
	settings[key] = value
	settings_changed.emit()
	save_game()
