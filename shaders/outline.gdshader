shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, specular_disabled;
// Inverted-hull outline with a constant on-screen width.
// Use it on the hull mesh from Toon.smooth_mesh(): normals are smoothed and the
// triangle winding is reversed, so ordinary back-face culling leaves only the
// shell behind the model (more reliable than cull_front across renderers).

uniform vec4 outline_color : source_color = vec4(0.16, 0.11, 0.2, 1.0);
uniform float width_px = 2.5;
uniform float depth_bias = 0.0004;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 n_clip = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy;
	float len = length(n_clip);
	if (len > 0.0001) {
		clip.xy += (n_clip / len) * width_px * 2.0 * clip.w / VIEWPORT_SIZE;
	}
	// nudge the shell slightly away from the camera so it can never z-fight
	// with the model's own faces (Godot uses reversed-Z: smaller z = farther)
	clip.z -= depth_bias * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
