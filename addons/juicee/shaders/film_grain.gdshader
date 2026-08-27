// Animated film grain noise overlay.
// strength:  grain intensity (0 = off, 0.15 = cinematic, 0.5 = heavy VHS noise).
// speed:     frames per second the grain texture cycles through (15 = film-like).
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0)  = 0.15;
uniform float speed    : hint_range(1.0, 60.0) = 15.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Quantize time so grain updates at `speed` fps, not every render frame.
	float t = floor(TIME * speed);
	// Hash-based pseudo-random noise - cheap and uniform.
	float noise = fract(sin(dot(SCREEN_UV * 319.7 + t * 0.1, vec2(127.1, 311.7))) * 43758.5453);
	// Center the noise around 0 so we both brighten and darken pixels equally.
	float grain = (noise - 0.5) * 2.0 * strength;
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);
	COLOR = vec4(clamp(screen.rgb + grain, 0.0, 1.0), screen.a);
}
