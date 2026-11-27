// Fretboard Master – tło okna: kolor jednolity, gradient, desenie proceduralne albo własny obraz.
// Jeden przebieg na klatkę (rysowany tylko, gdy okno się odświeża). Desenie są liczone w shaderze –
// bez tekstur, więc nie zajmują pamięci i skalują się bez utraty jakości.
// Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform int mode = 0;            // 0 jednolite, 1 gradient, 2 deseń, 3 obraz
uniform int pattern = 0;         // 0 drewno, 1 karbon, 2 skóra, 3 filc, 4 nuty, 5 geometryczny
uniform vec4 color1 : source_color = vec4(0.03, 0.04, 0.08, 1.0);
uniform vec4 color2 : source_color = vec4(0.11, 0.16, 0.33, 1.0);
uniform float angle = 135.0;     // kierunek gradientu (stopnie)
uniform float intensity = 0.5;   // siła deseniu
uniform float pattern_scale = 1.0;
uniform float dim = 0.0;         // przyciemnienie 0–1
uniform float blur = 0.0;        // rozmycie obrazu 0–1
uniform float time_speed = 0.0;  // 0 = tło nieruchome
uniform float fade = 1.0;        // 0 = czarne (ekran startowy), 1 = tło docelowe
uniform vec2 size = vec2(1920.0, 1080.0);
uniform vec2 image_size = vec2(1.0, 1.0);
uniform sampler2D image : source_color, filter_linear_mipmap, repeat_disable;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

// Deski: długie słoje wzdłuż osi X, drobne włókna i szczeliny między deskami.
float wood(vec2 p) {
	float plank = floor(p.y / 170.0);
	vec2 q = vec2(p.x + hash(vec2(plank, 7.0)) * 900.0, p.y);
	float n = fbm(vec2(q.x * 0.0012, q.y * 0.02 + plank * 3.7));
	float rings = fract(q.y * 0.018 + n * 2.6);
	float ring = smoothstep(0.55, 1.0, rings) * 0.6;
	float fibre = fbm(vec2(q.x * 0.006, q.y * 1.1)) * 0.45;
	float seam = 1.0 - smoothstep(0.0, 2.0, abs(mod(p.y, 170.0) - 1.0));
	return clamp(ring + fibre * 0.8 + seam * 0.8 + hash(vec2(plank, 1.0)) * 0.15, 0.0, 1.0);
}

float carbon(vec2 p) {
	vec2 c = floor(p / 10.0);
	vec2 f = fract(p / 10.0);
	bool dir = mod(c.x + floor(c.y * 0.5) * 2.0 + c.y, 4.0) < 2.0;
	float t = dir ? sin(f.y * 3.14159) : sin(f.x * 3.14159);
	return t * 0.8 + 0.1;
}

float leather(vec2 p) {
	vec2 g = p / 26.0;
	vec2 i = floor(g), f = fract(g);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		float d = length(o + hash2(i + o) - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	float crease = smoothstep(0.0, 0.18, d2 - d1);
	return crease * (0.65 + 0.35 * noise(p * 0.08));
}

float felt(vec2 p) {
	return clamp(fbm(p * 0.09) * 0.75 + hash(floor(p)) * 0.35, 0.0, 1.0);
}

// Ósemka: główka (elipsa) + laska + chorągiewka, w losowo obsadzonych komórkach siatki.
float notes(vec2 p) {
	float cell = 110.0;
	vec2 i = floor(p / cell);
	if (hash(i) < 0.45) return 0.0;
	vec2 f = (fract(p / cell) - 0.5) * cell;
	float r = (hash(i + 3.1) - 0.5) * 0.6;
	f = mat2(vec2(cos(r), sin(r)), vec2(-sin(r), cos(r))) * f;
	f += (hash2(i) - 0.5) * 30.0;
	vec2 h = f - vec2(-6.0, 16.0);
	h = mat2(vec2(0.87, 0.5), vec2(-0.5, 0.87)) * h;
	float head = length(h / vec2(11.0, 7.5)) < 1.0 ? 1.0 : 0.0;
	float stem = (f.x > 3.0 && f.x < 6.0 && f.y > -26.0 && f.y < 16.0) ? 1.0 : 0.0;
	float flag = (f.x > 5.0 && f.x < 5.0 + 13.0 * (1.0 - (f.y + 26.0) / 22.0) && f.y > -26.0 && f.y < -6.0) ? 1.0 : 0.0;
	return max(head, max(stem, flag));
}

float hexgrid(vec2 p) {
	vec2 s = vec2(1.0, 1.7320508);
	p /= 34.0;
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	float edge = 0.5 - max(dot(q, s * 0.5), q.x);
	return 1.0 - smoothstep(0.0, 0.05, edge);
}

void fragment() {
	vec2 px = UV * size;
	float t = TIME * time_speed;
	vec3 col = color1.rgb;
	if (mode == 1) {
		float a = radians(angle + t * 6.0);
		vec2 d = vec2(cos(a), sin(a));
		vec2 c = (UV - 0.5) * vec2(size.x / size.y, 1.0);
		float k = clamp(dot(c, d) / (0.5 * (abs(d.x) * size.x / size.y + abs(d.y))) * 0.5 + 0.5, 0.0, 1.0);
		col = mix(color1.rgb, color2.rgb, k);
	} else if (mode == 2) {
		vec2 p = px / pattern_scale + vec2(t * 14.0, t * 5.0);
		float v = 0.0;
		if (pattern == 0) v = wood(p);
		else if (pattern == 1) v = carbon(p);
		else if (pattern == 2) v = leather(p);
		else if (pattern == 3) v = felt(p);
		else if (pattern == 4) v = notes(p);
		else v = hexgrid(p);
		col = mix(color1.rgb, color2.rgb, v * intensity);
	} else if (mode == 3) {
		// Obraz wypełnia okno z zachowaniem proporcji (przycięcie nadmiaru).
		float sa = size.x / size.y, ia = image_size.x / image_size.y;
		vec2 uv = UV;
		if (sa > ia) uv.y = (uv.y - 0.5) * ia / sa + 0.5; else uv.x = (uv.x - 0.5) * sa / ia + 0.5;
		uv += vec2(sin(t * 0.2), cos(t * 0.17)) * 0.01;
		col = textureLod(image, uv, blur * 7.0).rgb;
	}
	col *= 1.0 - dim;
	COLOR = vec4(col * fade, 1.0);
}
