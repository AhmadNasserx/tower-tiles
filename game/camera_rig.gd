class_name CameraRig
extends Camera3D
## Angled tabletop camera with trauma-based screen shake, zoom, drag-pan (mouse and
## touch), inertia, keyboard framing and the boss intro face-cam shot (see
## cinematic_face).

const PITCH := deg_to_rad(-56.0)
## Boss intro shot timing in real seconds: move in, hold, move back (2.6s total,
## to match the HUD title card).
const SHOT_IN := 0.55
const SHOT_HOLD := 1.5
const SHOT_OUT := 0.55
## Face cam: degrees the camera sits off the boss's nose, degrees below the aim point
## (negative = low, looking up), distance per unit of boss size (clamped to 6.5..10),
## dolly-in over the hold (world units), FOV narrowing over the hold, and the lowest
## camera height. The aim point is SHOT_AIM of the boss's height, a bit under the
## head centre, so the face lands in the upper-middle of the frame.
const SHOT_YAW := 18.0
const SHOT_ELEV := -4.0
const SHOT_DIST := 8.5
const SHOT_PUSH := 0.8
const SHOT_FOV_NARROW := 4.0
const SHOT_MIN_Y := 1.2
const SHOT_AIM := 0.6

## Zoom range (1.0 = gameplay framing) and the step per mouse-wheel notch.
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.3
const WHEEL_STEP := 0.08
## Keyboard zoom rate (exp per second while +/- is held).
const KEY_ZOOM_RATE := 1.4
## A left press that moves more than this many px is a camera drag, not a click.
const DRAG_PX := 10.0
## Same for one finger (fingers wobble more than a mouse).
const TOUCH_PX := 12.0
## Drag inertia: velocity decays with this time constant (about 0.35s to settle).
const GLIDE_TAU := 0.1
const GLIDE_MAX := 60.0
## Two quick two-finger taps reset the framing.
const TAP_MAX_MS := 350
const TAP_MAX_PX := 14.0
const DOUBLE_TAP_MS := 400

var focus := Vector3.ZERO
var bounds := Vector2(20, 12)
var zoom := 1.0
var shake_enabled := true
## True when the current or most recent press has become a camera drag or a
## multi-touch gesture. Reset on every new press (mouse button or first finger), so
## game.gd can ignore the release of a drag.
var drag_moved := false

var _trauma := 0.0
var _t := 0.0
var _base_dist := 30.0
var _focus_target := Vector3.ZERO
var _zoom_target := 1.0
var _intro := 0.0
var _kick := Vector2.ZERO
var _center := Vector3.ZERO

# Mouse: the button that started the press (0 = none), whether it has become a drag,
# the press position and the last position seen.
var _mouse_btn := 0
var _mouse_drag := false
var _mouse_origin := Vector2.ZERO
var _mouse_last := Vector2.ZERO
# Touch: active fingers (index -> position), single-finger drag state, and the
# two-finger gesture (pinch, pan and tap detection).
var _touches: Dictionary = {}
var _touch_drag := false
var _touch_origin := Vector2.ZERO
var _touch_last := Vector2.ZERO
var _gesture := false
var _pinch_mid := Vector2.ZERO
var _pinch_dist := 0.0
var _gesture_mid0 := Vector2.ZERO
var _gesture_dist0 := 0.0
var _gesture_moved := 0.0
var _gesture_ms := 0
var _last_tap_ms := -100000
# Inertia: world velocity sampled over the last ~16ms of panning, and the glide that
# runs after a drag is released.
var _pan_vel := Vector3.ZERO
var _pan_acc := Vector3.ZERO
var _pan_acc_t := 0.0
var _pan_us := 0
var _glide_vel := Vector3.ZERO

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
## one side, below the aim point, aimed at it. Uses the boss's current position,
## so it follows the boss while the shot runs.
func _face_transform(boss: Enemy) -> Transform3D:
	var aim := boss.global_position + Vector3(0.0, boss.height * SHOT_AIM, 0.0)
	var front := boss.facing()
	var side := front.rotated(Vector3.UP, deg_to_rad(SHOT_YAW))
	var el := deg_to_rad(SHOT_ELEV)
	var dist := clampf(SHOT_DIST * boss.size, 6.5, 10.0) - SHOT_PUSH * _cine_push
	var pos := aim + (side * cos(el) + Vector3.UP * sin(el)) * dist
	pos.y = maxf(pos.y, SHOT_MIN_Y)
	return Transform3D(Basis.IDENTITY, pos).looking_at(aim, Vector3.UP)


## The gameplay camera transform (no shake), from focus and zoom.
func _gameplay_xf() -> Transform3D:
	var dir := Vector3(0, -sin(PITCH), cos(PITCH)) # from focus back toward the camera
	return Transform3D(Basis.from_euler(Vector3(PITCH, 0, 0)), focus + _center + dir * _base_dist * zoom)


# ------------------------------------------------------------------ input
# Touch bookkeeping runs in _input and never consumes an event, so a plain tap still
# reaches game.gd as the emulated left click. Mouse buttons and keys run in
# _unhandled_input, so HUD controls that consume a press keep it.

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		# Clear the flag before any _unhandled_input handler (game.gd) sees the new
		# press. Only when no camera drag is held, and never for the wheel.
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.device != InputEvent.DEVICE_ID_EMULATION and _mouse_btn == 0 \
				and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT):
			drag_moved = false


func _unhandled_input(event: InputEvent) -> void:
	if _cine_on:
		_clear_input()
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_R or k.keycode == KEY_HOME):
			_reset_framing()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.position, _zoom_target / mg.factor)
	elif event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		_focus_target += Vector3(pg.delta.x, 0, pg.delta.y) * 0.3
		_clamp_focus()


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.device == InputEvent.DEVICE_ID_EMULATION:
		return # touch-emulated clicks are handled through the touch events
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		_zoom_at(mb.position, _zoom_target - WHEEL_STEP)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		_zoom_at(mb.position, _zoom_target + WHEEL_STEP)
	elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			if _mouse_btn != 0:
				return
			_mouse_btn = mb.button_index
			_mouse_origin = mb.position
			_mouse_last = mb.position
			_mouse_drag = false
			_glide_vel = Vector3.ZERO
			_pan_us = Time.get_ticks_usec()
			_pan_acc = Vector3.ZERO
			_pan_acc_t = 0.0
		elif mb.button_index == _mouse_btn:
			_end_mouse_drag()


func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
	if mm.device == InputEvent.DEVICE_ID_EMULATION or _mouse_btn == 0:
		return
	if not _mouse_drag:
		# Left needs DRAG_PX of travel; middle and right pan on any motion.
		var need := DRAG_PX if _mouse_btn == MOUSE_BUTTON_LEFT else 0.0
		if _mouse_origin.distance_to(mm.position) <= need:
			return
		_mouse_drag = true
		drag_moved = true
		_mouse_last = _mouse_origin
	_pan_screen(_mouse_last, mm.position)
	_mouse_last = mm.position


func _end_mouse_drag() -> void:
	if _mouse_drag:
		_release_pan()
	_mouse_btn = 0
	_mouse_drag = false


func _on_screen_touch(st: InputEventScreenTouch) -> void:
	if _cine_on or not is_processing_unhandled_input():
		_clear_input()
		return
	if st.pressed:
		if _touches.is_empty():
			# New press: reset the flag and stop any glide. Done even for a touch that
			# lands on the HUD, so drag_moved always describes the latest press.
			drag_moved = false
			_touch_drag = false
			_gesture = false
			_glide_vel = Vector3.ZERO
		if _touches.has(st.index) or _gui_blocks(st.position):
			return
		_touches[st.index] = st.position
		if _touches.size() == 1:
			_touch_origin = st.position
			_touch_last = st.position
			_pan_us = Time.get_ticks_usec()
			_pan_acc = Vector3.ZERO
			_pan_acc_t = 0.0
		elif _gesture:
			_rebase_pinch()
			drag_moved = true
		else:
			_begin_pinch()
	else:
		if not _touches.has(st.index):
			return
		_touches.erase(st.index)
		if _touches.is_empty():
			if _gesture:
				_check_two_finger_tap()
			elif _touch_drag:
				_release_pan()
			_gesture = false
			_touch_drag = false
		elif _touches.size() >= 2:
			_rebase_pinch()
		# One finger left after a pinch stays inert until every finger is up, so the
		# gesture can never turn into a pan or a click.


func _on_screen_drag(sd: InputEventScreenDrag) -> void:
	if _cine_on or not is_processing_unhandled_input():
		_clear_input()
		return
	if not _touches.has(sd.index):
		return
	_touches[sd.index] = sd.position
	if _gesture:
		if _touches.size() >= 2:
			var pair := _touch_pair()
			_on_pinch(pair[0], pair[1])
		return
	# One finger: pan once the finger has travelled TOUCH_PX.
	if not _touch_drag:
		if _touch_origin.distance_to(sd.position) <= TOUCH_PX:
			return
		_touch_drag = true
		drag_moved = true
		_touch_last = _touch_origin
	_pan_screen(_touch_last, sd.position)
	_touch_last = sd.position


func _begin_pinch() -> void:
	_gesture = true
	_touch_drag = false
	drag_moved = true
	_glide_vel = Vector3.ZERO
	_rebase_pinch()
	_gesture_mid0 = _pinch_mid
	_gesture_dist0 = _pinch_dist
	_gesture_moved = 0.0
	_gesture_ms = Time.get_ticks_msec()


## Midpoint and spread of the first two fingers.
func _touch_pair() -> Array:
	var keys := _touches.keys()
	var a: Vector2 = _touches[keys[0]]
	var b: Vector2 = _touches[keys[1]]
	return [(a + b) * 0.5, a.distance_to(b)]


## Resets the pinch baseline without moving the camera (used when fingers change).
func _rebase_pinch() -> void:
	var pair := _touch_pair()
	_pinch_mid = pair[0]
	_pinch_dist = pair[1]


## One pinch step: the world under the midpoint follows it (two-finger pan), and the
## spread changes the zoom, anchored on the midpoint. Snapped, not eased, so the
## fingers stay locked to the world.
func _on_pinch(mid: Vector2, dist: float) -> void:
	if _pinch_dist >= 2.0 and dist >= 2.0:
		_pan_by(_ground_delta(_pinch_mid, mid))
		var nz := clampf(zoom * (_pinch_dist / dist), ZOOM_MIN, ZOOM_MAX)
		var before = _ground_at(mid, focus, zoom)
		var after = _ground_at(mid, focus, nz)
		if before != null and after != null:
			var dz: Vector3 = before - after
			dz.y = 0.0
			_pan_by(dz)
		zoom = nz
		_zoom_target = nz
		_clamp_focus()
		_gesture_moved = maxf(_gesture_moved, maxf(mid.distance_to(_gesture_mid0), absf(dist - _gesture_dist0)))
	_pinch_mid = mid
	_pinch_dist = dist


func _check_two_finger_tap() -> void:
	var now := Time.get_ticks_msec()
	var is_tap := now - _gesture_ms < TAP_MAX_MS and _gesture_moved < TAP_MAX_PX
	if is_tap and now - _last_tap_ms < DOUBLE_TAP_MS:
		_last_tap_ms = -100000
		_reset_framing()
	elif is_tap:
		_last_tap_ms = now
	else:
		_last_tap_ms = -100000


func _reset_framing() -> void:
	_focus_target = Vector3.ZERO
	_zoom_target = 1.0
	_glide_vel = Vector3.ZERO


## Drops every in-progress press, drag and glide (used when the cinematic starts).
func _clear_input() -> void:
	_mouse_btn = 0
	_mouse_drag = false
	_touches.clear()
	_touch_drag = false
	_gesture = false
	_glide_vel = Vector3.ZERO
	_pan_vel = Vector3.ZERO
	_pan_acc = Vector3.ZERO
	_pan_acc_t = 0.0


## True if a Control with a STOP filter sits under `pos` (the HUD). A touch that starts
## there must not pan the world.
func _gui_blocks(pos: Vector2) -> bool:
	return _gui_hit(get_viewport(), pos)


func _gui_hit(node: Node, pos: Vector2) -> bool:
	for c in node.get_children():
		if c is Control:
			var ctl := c as Control
			if ctl.mouse_filter == Control.MOUSE_FILTER_STOP and ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(pos):
				return true
		if _gui_hit(c, pos):
			return true
	return false


## True while a press or gesture is in progress or a glide is running. game.gd can use
## it at press time: a second finger already down, or a drag under way.
func press_is_gesture() -> bool:
	return _touches.size() >= 2 or _gesture or _touch_drag or _mouse_drag


# ------------------------------------------------------------------ framing

## Focus range at zoom `z`. The focus may reach the board edge plus a quarter board
## (or half the visible width, whichever is smaller), so the board always stays partly
## on screen while its edges can still be centred when zoomed in.
func _focus_limit(z: float) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var dist := _base_dist * z
	var tv := tan(deg_to_rad(fov * 0.5))
	var half := Vector2(dist * tv * vp.x / maxf(vp.y, 1.0), dist * tv / absf(sin(PITCH)))
	var slack := Vector2(minf(half.x * 0.5, bounds.x * 0.25), minf(half.y * 0.5, bounds.y * 0.25))
	return bounds + slack


func _clamp_focus() -> void:
	var lim := _focus_limit(_zoom_target)
	_focus_target.x = clampf(_focus_target.x, -lim.x, lim.x)
	_focus_target.z = clampf(_focus_target.z, -lim.y, lim.y)
	focus.x = clampf(focus.x, -lim.x, lim.x)
	focus.z = clampf(focus.z, -lim.y, lim.y)


## Moves focus and its target together, so a drag is not delayed by smoothing.
func _pan_by(d: Vector3) -> void:
	focus += d
	_focus_target += d
	_clamp_focus()


## Zooms to `new_zoom`, keeping the ground point under `screen` where it was.
func _zoom_at(screen: Vector2, new_zoom: float) -> void:
	var nz := clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	var before = _ground_at(screen, _focus_target, _zoom_target)
	var after = _ground_at(screen, _focus_target, nz)
	_zoom_target = nz
	if before != null and after != null:
		var d: Vector3 = before - after
		d.y = 0.0
		_focus_target += d
	_clamp_focus()


## Finger-locked pan: the world point under `from` ends up under `to`. Falls back to
## the old fixed scale if either point misses the ground.
func _ground_delta(from: Vector2, to: Vector2) -> Vector3:
	var a = _ground_at(from, focus, zoom)
	var b = _ground_at(to, focus, zoom)
	if a == null or b == null:
		var k := 0.045 * zoom
		var rel := to - from
		return Vector3(-rel.x * k, 0.0, -rel.y * k * 1.3)
	var d: Vector3 = a - b
	d.y = 0.0
	return d


## Pans with the pointer or finger and records velocity for the glide.
func _pan_screen(from: Vector2, to: Vector2) -> void:
	var d := _ground_delta(from, to)
	_pan_by(d)
	var now := Time.get_ticks_usec()
	var dt := (now - _pan_us) / 1000000.0
	_pan_us = now
	if dt > 0.1:
		_pan_acc = Vector3.ZERO
		_pan_acc_t = 0.0
	else:
		_pan_acc += d
		_pan_acc_t += dt
		if _pan_acc_t >= 0.016:
			_pan_vel = _pan_acc / _pan_acc_t
			_pan_acc = Vector3.ZERO
			_pan_acc_t = 0.0


## Starts the glide if the drag was still moving when released.
func _release_pan() -> void:
	if Time.get_ticks_usec() - _pan_us < 100000 and _pan_vel.length() > 0.3:
		_glide_vel = _pan_vel.limit_length(GLIDE_MAX)
	else:
		_glide_vel = Vector3.ZERO
	_pan_vel = Vector3.ZERO


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_t += real_delta
	if _cine_on:
		# The shot owns framing; input and glides stop. Keep aiming at the boss's
		# current head. If it was freed, glide back from the last face framing.
		_clear_input()
		if _face_live:
			if is_instance_valid(_face_boss):
				_face_xf = _face_transform(_face_boss)
			else:
				_face_live = false
				end_cinematic()
	else:
		# A release that was eaten by a HUD control never reaches us; end the drag once
		# the button is seen to be up.
		if _mouse_btn != 0 and not Input.is_mouse_button_pressed(_mouse_btn):
			_end_mouse_drag()
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
		var zdir := 0.0
		if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS) or Input.is_key_pressed(KEY_KP_ADD):
			zdir -= 1.0
		if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
			zdir += 1.0
		if zdir != 0.0:
			_zoom_at(get_viewport().get_visible_rect().size * 0.5, _zoom_target * exp(zdir * real_delta * KEY_ZOOM_RATE))
		if _glide_vel != Vector3.ZERO:
			_focus_target += _glide_vel * real_delta
			_glide_vel *= exp(-real_delta / GLIDE_TAU)
			if _glide_vel.length() < 0.01:
				_glide_vel = Vector3.ZERO
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


## Where the ground point under `screen` would be for a camera at focus `focus_v` and
## zoom `zoom_v`. The ray direction depends only on the fixed pitch, so this can be
## evaluated for a target state without moving the camera.
func _ground_at(screen: Vector2, focus_v: Vector3, zoom_v: float) -> Variant:
	var dir := project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return null
	var cam := focus_v + _center + Vector3(0, -sin(PITCH), cos(PITCH)) * _base_dist * zoom_v
	var t := -cam.y / dir.y
	if t < 0.0:
		return null
	return cam + dir * t
