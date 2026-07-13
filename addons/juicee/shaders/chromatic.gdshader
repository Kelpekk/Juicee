shader_type canvas_item;

// Splits the red and blue channels apart horizontally, the lens-fringe look.
//
// The offset is in PIXELS, via SCREEN_PIXEL_SIZE, not in UV. Offsetting by raw UV
// makes the effect's strength depend on the resolution: the same intensity was a
// visible fringe at 1080p and nothing at all in a small viewport.
uniform float intensity : hint_range(0.0, 20.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 off = vec2(intensity * SCREEN_PIXEL_SIZE.x, 0.0);
	float r = texture(SCREEN_TEXTURE, uv + off).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - off).b;
	COLOR = vec4(r, g, b, 1.0);
}
