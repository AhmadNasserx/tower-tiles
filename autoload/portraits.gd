extends Node
## Renders little 3D portraits of every kitten tower and critter once, at
## startup, so cards and previews show the real (toon-shaded) models.

signal portrait_ready(key: String)

const SIZE := 192

var _cache := {}
var _waiting := {} # key -> Array[TextureRect]
var _queue: Array[String] = []
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("e8dcff")
	e.ambient_light_energy = 0.55
	env.environment = e
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30
	_viewport.add_child(_camera)
	for t in GameData.TURRET_ORDER:
		_queue.append("kitten:" + t)
	for e2 in GameData.ENEMIES:
		_queue.append("critter:" + e2)
	_queue.append("hero")
	_run.call_deferred()


func get_texture(key: String) -> Texture2D:
	return _cache.get(key)


## Puts the portrait into `rect` now, or as soon as it has been rendered.
func fill(rect: TextureRect, key: String) -> void:
	if _cache.has(key):
		rect.texture = _cache[key]
		return
	if not _waiting.has(key):
		_waiting[key] = []
	_waiting[key].append(rect)


func _run() -> void:
	_busy = true
	while not _queue.is_empty():
		var key: String = _queue.pop_front()
		_stage = Node3D.new()
		_viewport.add_child(_stage)
		_build(key)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _viewport.get_texture().get_image()
		var tex := ImageTexture.create_from_image(img)
		_cache[key] = tex
		_stage.queue_free()
		for r in _waiting.get(key, []):
			if is_instance_valid(r):
				r.texture = tex
		_waiting.erase(key)
		portrait_ready.emit(key)
	_busy = false


func _build(key: String) -> void:
	if key.begins_with("kitten:"):
		var type := key.get_slice(":", 1)
		var t := Turret.new()
		t.type = type
		t.def = GameData.TURRETS[type]
		t.set_process(false)
		_stage.add_child(t)
		t._build()
		t.rotation.y = 0.0
		t._turn.rotation.y = PI + 0.5 # three-quarter view of kitten and weapon
		_frame(Vector3(0, 1.55, 0), 4.7, -22.0, 28.0)
	elif key.begins_with("critter:"):
		var type := key.get_slice(":", 1)
		var d: Dictionary = GameData.ENEMIES[type]
		var rig := PetRig.create(d.model, 1.0, d.tint)
		rig.rotation.y = PI - 0.45 # face the camera, slightly turned
		rig.set_process(false)
		_stage.add_child(rig)
		rig.play("idle")
		_frame(Vector3(0, 0.8, 0), 4.6, -10.0, 0.0)
	elif key == "hero":
		var rig2 := PetRig.create(CatTower.MODEL, 1.0)
		rig2.rotation.y = PI - 0.45
		rig2.set_process(false)
		_stage.add_child(rig2)
		_frame(Vector3(0, 0.8, 0), 4.6, -10.0, 0.0)


func _frame(target: Vector3, dist: float, pitch_deg: float, yaw_deg: float) -> void:
	var dir := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0)) * Vector3(0, 0, 1)
	_camera.global_position = target + dir * dist
	_camera.look_at(target)
