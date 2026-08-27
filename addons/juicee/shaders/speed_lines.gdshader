// Anime "speed lines" - radial streaks converging on the screen centre. Sells
// bursts of speed, dashes, focus/impact moments, shock reactions.
// density:       angular streak count (higher = more, thinner lines).
// strength:      overall opacity of the streaks.
// center_clear:  radius (0..1) of the clear zone in the middle (no lines).
// line_color:    streak colour (white = speed, black = shock/focus).
// speed:         animation rate - subtle shimmer of the streaks (0 = static).
shader_type canvas_item;

uniform float density      : hint_range(20.0, 400.0) = 140.0;
uniform float strength     : hint_range(0.0, 1.0)    = 0.5;
uniform float center_clear : hint_range(0.0, 0.9)    = 0.35;
uniform vec4  line_color   : source_color            = vec4(1.0);
uniform float speed        : hint_range(0.0, 20.0)   = 6.0;

void fragment() {
	vec2 d = SCREEN_UV - vec2(0.5);
	float r = length(d);
	float ang = atan(d.y, d.x);
	// Radial streaks: a high-frequency function of angle, gently animated.
	float streak = abs(sin(ang * density * 0.5 + sin(TIME * speed) * 0.5));
	streak = pow(streak, 6.0); // sharpen into thin lines
	// Lines only appear beyond the clear centre, ramping to full at the edge.
	float mask = smoothstep(center_clear, 1.0, r);
	float a = streak * mask * strength * line_color.a;
	COLOR = vec4(line_color.rgb, clamp(a, 0.0, 1.0));
}
