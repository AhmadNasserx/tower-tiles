class_name CameraRig
extends Camera3D
## Angled tabletop camera with trauma-based screen shake, zoom and drag-pan.

const PITCH := deg_to_rad(-56.0)

var focus := Vector3.ZERO
var bounds := Vector2(20, 12)
var zoom := 1.0
var shake_enabled := true

var _trauma := 0.0
var _t := 0.0
var _base_dist := 30.0
var _dragging := false
var _focus_target := Vector3.ZERO
var _zoom_target := 1.0
var _intro := 0.0
var _kick := Vector2.ZERO
var _center := Vector3.ZERO


func setup(map_size: Vector2) -> void:
	bounds = map_size * 0.5
	fov = 32.0
	near = 0.5
	far = 220.0
	_fit()
	get_viewport().size_changed.connect(_fit)
	_focus_target = Vector3.ZERO
	focus = Vector3(0, 0, 6)
	_intro = 1.0
	_apply()


func _fit() -> void:
	# Find the distance where the whole board fits inside the area the HUD
	# leaves free, then nudge the focus so the board is centred in it.
	var vp := get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2(20, 76), vp - Vector2(40, 76 + 150))
	var corners: Array[Vector3] = []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			corners.append(Vector3(sx * (bounds.x + 0.4), 0, sz * (bounds.y + 0.4)))
	var dist := 18.0
	_center = Vector3.ZERO
	for i in 120:
		var r := _project_bounds(corners, dist, _center)
		if r.size.x <= safe.size.x and r.size.y <= safe.size.y:
			break
		dist += 0.5
	for i in 4:
		var r := _project_bounds(corners, dist, _center)
		var dy := (r.get_center().y - safe.get_center().y)
		_center.z += dy * 0.02 * dist / 30.0
	_base_dist = dist


func _project_bounds(corners: Array[Vector3], dist: float, center: Vector3) -> Rect2:
	var dir := Vector3(0, -sin(PITCH), cos(PITCH))
	global_transform = Transform3D(Basis.from_euler(Vector3(PITCH, 0, 0)), center + dir * dist)
	h_offset = 0.0
	v_offset = 0.0
	var r := Rect2(unproject_position(corners[0]), Vector2.ZERO)
	for c in corners:
		r = r.expand(unproject_position(c))
	return r


func add_trauma(amount: float) -> void:
	if not shake_enabled:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## A directional nudge (e.g. when the giant paw lands).
func kick(dir: Vector2) -> void:
	if shake_enabled:
		_kick += dir


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_target = clampf(_zoom_target - 0.08, 0.6, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_target = clampf(_zoom_target + 0.08, 0.6, 1.15)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var k := 0.045 * zoom
		_focus_target += Vector3(-mm.relative.x * k, 0, -mm.relative.y * k * 1.3)
		_clamp_focus()
	elif event is InputEventMagnifyGesture:
		_zoom_target = clampf(_zoom_target / (event as InputEventMagnifyGesture).factor, 0.6, 1.15)
	elif event is InputEventPanGesture:
		_focus_target += Vector3((event as InputEventPanGesture).delta.x, 0, (event as InputEventPanGesture).delta.y) * 0.3
		_clamp_focus()


func _clamp_focus() -> void:
	var slack := (1.0 - zoom) * 1.5 + 0.15
	_focus_target.x = clampf(_focus_target.x, -bounds.x * slack, bounds.x * slack)
	_focus_target.z = clampf(_focus_target.z, -bounds.y * slack, bounds.y * slack)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_t += real_delta
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1
	if pan != Vector3.ZERO:
		_focus_target += pan * real_delta * 18.0 * zoom
		_clamp_focus()
	zoom = lerpf(zoom, _zoom_target, 1.0 - exp(-real_delta * 10.0))
	focus = focus.lerp(_focus_target, 1.0 - exp(-real_delta * (3.0 if _intro > 0.0 else 10.0)))
	_intro = maxf(0.0, _intro - real_delta)
	_trauma = maxf(0.0, _trauma - real_delta * 1.6)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-real_delta * 12.0))
	_apply()


func _apply() -> void:
	var dist := _base_dist * zoom
	var dir := Vector3(0, -sin(PITCH), cos(PITCH)) # from focus back toward the camera
	position = focus + _center + dir * dist
	rotation = Vector3(PITCH, 0, 0)
	var s := _trauma * _trauma
	h_offset = (sin(_t * 47.0) * 0.6 + sin(_t * 93.0) * 0.4) * s * 0.9 + _kick.x
	v_offset = (sin(_t * 53.0 + 1.3) * 0.6 + sin(_t * 87.0) * 0.4) * s * 0.9 + _kick.y
	rotation.z = sin(_t * 41.0) * s * 0.025


## Ray from the screen into the ground plane (y = 0).
func ground_point(screen_pos: Vector2) -> Variant:
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t
