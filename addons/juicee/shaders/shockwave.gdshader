// Expanding radial distortion ring — classic shockwave ripple.
// origin_uv:  normalized screen-space origin (0..1 range, set per-frame by the effect).
// radius:     current ring radius (0 = at origin, 1 = at screen edge). Animated by GDScript.
// width:      thickness of the distortion band (0.02–0.08 looks good).
// strength:   max UV displacement at the ring centre.
// falloff:    how sharply the ring edge drops off (higher = sharper).
shader_type canvas_item;

// NOTE: hint_range is only valid on float/int uniforms, not vec2 — it makes the
// shader fail to compile. origin_uv is driven per-frame from GDScript anyway.
uniform vec2  origin_uv  = vec2(0.5, 0.5);
uniform float radius     : hint_range(0.0, 2.0)  = 0.0;
uniform float width      : hint_range(0.0, 0.3)  = 0.04;
uniform float strength   : hint_range(0.0, 0.1)  = 0.025;
uniform float falloff    : hint_range(1.0, 32.0) = 6.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Correct for non-square screens (height-normalised coordinates → circular ring).
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0);
	vec2 offset = (SCREEN_UV - origin_uv) * aspect;
	float dist = length(offset);

	float ring_dist = abs(dist - radius);
	float wave = exp(-pow(ring_dist / (width * 0.5), falloff));

	vec2 dir = (dist > 0.0001) ? normalize(offset) : vec2(0.0);
	vec2 displaced_uv = SCREEN_UV + dir * wave * strength;

	COLOR = texture(SCREEN_TEXTURE, displaced_uv);
}
