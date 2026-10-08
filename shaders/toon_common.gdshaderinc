// Cel shading: two crisp light bands, coloured shadows, a soft rim and a toon
// highlight. Works in the Compatibility renderer, so it runs on the web.
// Kept in an include so variants can share it. (Per-instance uniforms are
// deliberately not used: they render black on some WebGL 2 implementations.)

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform float vertex_color_amount = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.56, 0.5, 0.78, 1.0);
uniform float band_threshold = 0.08;
uniform float band_softness = 0.05;
uniform float mid_band = 0.55;
uniform float rim_strength = 0.22;
uniform float light_scale = 0.62;
uniform float specular_strength = 0.18;

uniform float flash = 0.0;

void fragment() {
	vec3 col = texture(albedo_tex, UV).rgb * tint.rgb;
	vec3 vc = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	col *= mix(vec3(1.0), vc, vertex_color_amount);
	ALBEDO = col;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.62, 0.72, fres) * rim_strength;
	EMISSION = col * rim + vec3(flash);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(band_threshold, band_threshold + band_softness, ndl);
	float shadow = smoothstep(0.45, 0.55, ATTENUATION);
	lit *= shadow;
	// a lighter mid band keeps big flat faces from looking dead
	float mid = smoothstep(mid_band, mid_band + band_softness, ndl) * shadow;
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit * 0.82 + mid * 0.18);
	DIFFUSE_LIGHT += LIGHT_COLOR * shade * light_scale / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float spec = smoothstep(0.965, 0.975, dot(NORMAL, h)) * lit;
	SPECULAR_LIGHT += LIGHT_COLOR * spec * specular_strength / PI;
}
