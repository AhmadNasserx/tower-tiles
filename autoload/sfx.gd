extends Node
## Sound effects and music. Sounds are pooled and rate limited so a screen full
## of dogs doesn't turn into a wall of noise.

const SFX_DIR := "res://audio/sfx/"
const POOL_SIZE := 14
const NAMES := [
	"boss", "build", "cash", "click", "coin", "combo", "crit", "defeat", "die", "die2",
	"error", "heal", "hiss", "hit", "hover", "life_lost", "meow", "meow2", "perk", "pulse",
	"sell", "shoot_fish", "shoot_yarn", "slam", "splash", "tick", "upgrade",
	"victory", "wave_clear", "wave_start", "yowl", "zap", "zoomies",
]
const MUSIC := {
	"menu": preload("res://audio/music/menu.ogg"),
	"battle": preload("res://audio/music/battle.ogg"),
	"boss": preload("res://audio/music/boss.ogg"),
}
# Per-sound volume trims (dB) and the minimum gap between repeats (seconds).
const TRIM := {"hit": -8.0, "shoot_yarn": -6.0, "zap": -8.0, "shoot_fish": -5.0, "coin": -7.0,
	"hover": -6.0, "die": -2.0, "die2": -2.0, "pulse": -6.0, "splash": -4.0, "heal": -6.0, "tick": -4.0}
const GAP := {"hit": 0.05, "coin": 0.06, "shoot_yarn": 0.05, "zap": 0.09, "die": 0.06, "die2": 0.06,
	"hover": 0.04, "splash": 0.08, "pulse": 0.1, "shoot_fish": 0.08, "crit": 0.06, "heal": 0.3}

## When true (menu background demo), gameplay sounds are muted but UI sounds play.
var quiet := false
const UI_SOUNDS := ["click", "hover", "error", "perk", "upgrade", "coin", "meow", "meow2", "cash", "build", "sell", "victory", "defeat"]

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _music_tween: Tween
var _web := false
## Web only: browsers keep audio suspended until the page gets a user gesture.
## While locked, sfx are dropped and the latest music request is remembered.
var _web_locked := false
var _web_poll := 0.0
var _has_pending_music := false
var _pending_track := ""
var _pending_fade := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	_web_locked = _web
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for n in NAMES:
		_streams[n] = load(SFX_DIR + n + ".wav")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		_use_stream_playback(p)
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	for m in MUSIC.values():
		m.loop = true
	Save.settings_changed.connect(apply_volumes)
	apply_volumes()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80
	_use_stream_playback(p)
	add_child(p)
	return p


## Web exports default to Sample playback, which ignores the runtime-created
## buses, pitch_scale and volume tweens used here. Stream playback matches desktop.
func _use_stream_playback(p: AudioStreamPlayer) -> void:
	if _web:
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM


func _process(delta: float) -> void:
	if not _web_locked:
		return
	_web_poll -= delta
	if _web_poll > 0.0:
		return
	_web_poll = 0.2
	if _browser_audio_running():
		_web_locked = false
		if _has_pending_music:
			_has_pending_music = false
			_play_music(_pending_track, _pending_fade)


## True once the browser has let the audio context run. window.__ttAudio is
## installed by html/head_include in export_presets.cfg, which also resumes the
## context on the first click, tap or key press. Without it, never block.
func _browser_audio_running() -> bool:
	if not Engine.has_singleton("JavaScriptBridge"):
		return true
	var js = Engine.get_singleton("JavaScriptBridge")
	var ok = js.eval("!window.__ttAudio || window.__ttAudio.running()", true)
	return ok == null or bool(ok)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_bus("Master", Save.settings.master)
	_set_bus("Music", Save.settings.music)
	_set_bus("SFX", Save.settings.sfx)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(max(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


## Plays a sound. pitch_var randomizes pitch by +/- that fraction.
func play(sfx_name: String, pitch: float = 1.0, pitch_var: float = 0.08, volume_db: float = 0.0) -> void:
	if _web_locked:
		return
	var stream: AudioStream = _streams.get(sfx_name)
	if stream == null:
		return
	if quiet and not sfx_name in UI_SOUNDS:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = GAP.get(sfx_name, 0.025)
	if now - float(_last_played.get(sfx_name, -1.0)) < gap:
		return
	_last_played[sfx_name] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = max(0.05, pitch * (1.0 + randf_range(-pitch_var, pitch_var)))
	p.volume_db = volume_db + TRIM.get(sfx_name, 0.0)
	p.play()


func music(track: String, fade: float = 1.0) -> void:
	if _web_locked:
		_has_pending_music = true
		_pending_track = track
		_pending_fade = fade
		return
	_play_music(track, fade)


func _play_music(track: String, fade: float) -> void:
	if track == _current_music:
		return
	_current_music = track
	var incoming := _music_b if _music_a.playing and _music_a.volume_db > -40 else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	if _music_tween:
		_music_tween.kill()
	if track != "":
		incoming.stream = MUSIC[track]
		incoming.pitch_scale = 1.0
		incoming.volume_db = -40
		incoming.play()
	_music_tween = create_tween().set_parallel()
	if track != "":
		_music_tween.tween_property(incoming, "volume_db", -6.0, fade)
	_music_tween.tween_property(outgoing, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(outgoing.stop)


func set_music_pitch(pitch: float, time: float = 0.4) -> void:
	for p in [_music_a, _music_b]:
		create_tween().tween_property(p, "pitch_scale", pitch, time)
