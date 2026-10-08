extends CanvasLayer
## Cat-eye iris wipe between scenes.

const SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 aspect = vec2(1.777, 1.0);
uniform vec4 tint : source_color = vec4(0.137, 0.106, 0.157, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * aspect;
	// a vertical cat-eye slit: squash x so the opening is an almond shape
	p.x *= mix(1.0, 2.2, progress);
	float r = (1.0 - progress) * 1.25;
	float d = length(p);
	float a = smoothstep(r - 0.01, r + 0.01, d);
	COLOR = vec4(tint.rgb, a * tint.a);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	_set_progress(0.0)
	get_viewport().size_changed.connect(_update_aspect)
	_update_aspect()


func _update_aspect() -> void:
	var s := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", Vector2(s.x / max(s.y, 1.0), 1.0))


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
	_rect.visible = v > 0.001
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP if v > 0.001 else Control.MOUSE_FILTER_IGNORE


func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_method(_set_progress, 1.0, 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	busy = false
