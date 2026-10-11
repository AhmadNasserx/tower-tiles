class_name CameraRig
extends Camera3D
## Angled tabletop camera with trauma-based screen shake, zoom and drag-pan,
## plus the boss intro face-cam shot (see cinematic_face).

const PITCH := deg_to_rad(-56.0)
## Boss intro shot timing in real seconds: move in, hold, move back (2.6s total,
## to match the HUD title card).
const SHOT_IN := 0.55
const SHOT_HOLD := 1.5
const SHOT_OUT := 0.55
## Face cam: degrees the camera sits off the boss's nose, degrees below the head
## (negative = low, looking up), distance per unit of boss size (clamped to 3.5..5),
## dolly-in over the hold, FOV narrowing over the hold, and the lowest camera height.
const SHOT_YAW := 15.0
const SHOT_ELEV := -8.0
const SHOT_DIST := 4.2
const SHOT_PUSH := 0.4
const SHOT_FOV_NARROW := 4.0
const SHOT_MIN_Y := 0.6

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

# Boss intro shot: `_cine_w` blends from the gameplay camera to the face cam
# (`_face_xf`) and back. `_cine_push` goes 0 -> 1 over the hold (dolly and FOV).
# Focus and zoom are frozen while the shot runs, so the gameplay framing is
# exactly what it was when the camera comes back.
var _cine_on := false
var _cine_w := 0.0
var _cine_push := 0.0
var _cine_fov := 32.0 # gameplay FOV, restored when the shot ends
var _cine_tw: Tween
var _face_boss: Enemy
var _face_live := false
var _face_xf := Transform3D.IDENTITY


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


## Boss intro: the camera moves from the gameplay framing to a face-on close-up of
## `boss`: in front of its head (along its travel direction), a little to one side,
## slightly low and looking up at the head. It holds for SHOT_HOLD with a slow
## dolly-in and FOV narrowing, then glides back to the gameplay framing. The whole
## shot is SHOT_IN + SHOT_HOLD + SHOT_OUT real seconds. Pan and zoom input is
## ignored until the shot has returned.
func cinematic_face(boss: Enemy) -> void:
	if not _cine_on:
		_cine_on = true
		_cine_fov = fov
		_cine_push = 0.0
	_face_boss = boss
	_face_live = true
	_face_xf = _face_transform(boss)
	if _cine_tw and _cine_tw.is_valid():
		_cine_tw.kill()
	_cine_tw = create_tween().set_ignore_time_scale(true)
	_cine_tw.tween_property(self, "_cine_w", 1.0, SHOT_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cine_tw.tween_property(self, "_cine_push", 1.0, SHOT_HOLD).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cine_tw.tween_property(self, "_cine_w", 0.0, SHOT_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cine_tw.tween_callback(_cine_done)


## Cuts a running shot short (e.g. the boss died) and glides back. The last face
## framing is used for the glide, so it works after the boss is gone.
func end_cinematic() -> void:
	if not _cine_on:
		return
	if _cine_tw and _cine_tw.is_valid():
		_cine_tw.kill()
	_cine_tw = create_tween().set_ignore_time_scale(true)
	_cine_tw.tween_property(self, "_cine_w", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cine_tw.tween_callback(_cine_done)


func _cine_done() -> void:
	_cine_on = false
	_cine_w = 0.0
	_cine_push = 0.0
	_face_live = false
	_face_boss = null
	fov = _cine_fov


## Where the face cam sits for `boss` right now: in front of its head, a little to
## one side, below eye level, aimed at the head. Uses the boss's current position,
## so it follows the boss while the shot runs.
func _face_transform(boss: Enemy) -> Transform3D:
	var head := boss.global_position + Vector3(0.0, boss.height * 0.75, 0.0)
	var front := boss.facing()
	var side := front.rotated(Vector3.UP, deg_to_rad(SHOT_YAW))
	var el := deg_to_rad(SHOT_ELEV)
	var dist := clampf(SHOT_DIST * boss.size, 3.5, 5.0) - SHOT_PUSH * _cine_push
	var pos := head + (side * cos(el) + Vector3.UP * sin(el)) * dist
	pos.y = maxf(pos.y, SHOT_MIN_Y)
	return Transform3D(Basis.IDENTITY, pos).looking_at(head, Vector3.UP)


## The gameplay camera transform (no shake), from focus and zoom.
func _gameplay_xf() -> Transform3D:
	var dir := Vector3(0, -sin(PITCH), cos(PITCH)) # from focus back toward the camera
	return Transform3D(Basis.from_euler(Vector3(PITCH, 0, 0)), focus + _center + dir * _base_dist * zoom)


func _unhandled_input(event: InputEvent) -> void:
	if _cine_on:
		_dragging = false
		return
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
	if _cine_on:
		# The shot owns framing; keyboard pan and the usual smoothing wait. Keep
		# aiming at the boss's current head. If it was freed, glide back from the
		# last face framing.
		if _face_live:
			if is_instance_valid(_face_boss):
				_face_xf = _face_transform(_face_boss)
			else:
				_face_live = false
				end_cinematic()
	else:
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
	var s := _trauma * _trauma
	var roll := sin(_t * 41.0) * s * 0.025
	var gx := _gameplay_xf()
	if _cine_on and _cine_w > 0.0:
		# Blend the gameplay camera into the face cam; the lens narrows during the hold.
		var q := Quaternion(gx.basis).slerp(Quaternion(_face_xf.basis), _cine_w)
		transform = Transform3D(Basis(q) * Basis(Vector3.BACK, roll), gx.origin.lerp(_face_xf.origin, _cine_w))
		fov = lerpf(_cine_fov, _cine_fov - SHOT_FOV_NARROW * _cine_push, _cine_w)
	else:
		position = gx.origin
		rotation = Vector3(PITCH, 0, 0)
		rotation.z = roll
	h_offset = (sin(_t * 47.0) * 0.6 + sin(_t * 93.0) * 0.4) * s * 0.9 + _kick.x
	v_offset = (sin(_t * 53.0 + 1.3) * 0.6 + sin(_t * 87.0) * 0.4) * s * 0.9 + _kick.y


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
