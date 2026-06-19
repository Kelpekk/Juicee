// Radial (zoom) blur emanating from a center point.
// center_uv:  blur origin in screen UV space (0.5, 0.5 = screen center).
// strength:   max displacement per sample step (0.02 = subtle, 0.08 = intense).
// samples:    number of accumulated samples (more = smoother, heavier on GPU).
shader_type canvas_item;

// NOTE: hint_range is only valid on float/int uniforms, not vec2 — it makes the
// shader fail to compile. center_uv is driven per-frame from GDScript anyway.
uniform vec2  center_uv = vec2(0.5, 0.5);
uniform float strength  : hint_range(0.0, 0.15) = 0.02;
uniform int   samples   : hint_range(4, 16)      = 8;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 dir = SCREEN_UV - center_uv;
	float s = float(samples);
	vec4 color = vec4(0.0);
	for (int i = 0; i < samples; i++) {
		float t = float(i) / s;
		color += texture(SCREEN_TEXTURE, SCREEN_UV - dir * strength * t);
	}
	COLOR = color / s;
}
