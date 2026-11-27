// Fretboard Master – korekcja obrazu: jasność, kontrast, gamma. Warstwa istnieje tylko wtedy,
// gdy któraś wartość różni się od domyślnej (inaczej nie kosztuje nic).
// Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float gamma = 1.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	COLOR = vec4(c, 1.0);
}
