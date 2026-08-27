// CRT scanlines overlay. Dark horizontal bands simulate a cathode-ray tube screen.
// line_count:    number of scanlines across the screen height (300 = classic CRT density).
// strength:      how dark each band gets (0 = invisible, 1 = fully black bands).
// scroll_speed:  vertical scroll rate in cycles per second (0 = static, 0.1 = subtle drift).
shader_type canvas_item;

uniform float line_count   : hint_range(50.0, 1000.0) = 300.0;
uniform float strength     : hint_range(0.0,  1.0)    = 0.25;
uniform float scroll_speed : hint_range(0.0,  5.0)    = 0.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);
	float line = mod((SCREEN_UV.y + TIME * scroll_speed) * line_count, 1.0);
	// step(0.5, line) alternates 0/1 each half-line -> every other band is darkened.
	float band = step(0.5, line);
	screen.rgb *= mix(1.0, 1.0 - strength, band);
	COLOR = screen;
}
