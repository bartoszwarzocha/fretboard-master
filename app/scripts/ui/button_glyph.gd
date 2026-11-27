# Fretboard Master – ikonki przycisków (trójkąt „odtwarzaj”, kwadrat „zatrzymaj”, kropka) rysowane
# w kodzie – czcionki interfejsu nie mają tych znaków (zamiast nich pojawiał się prostokąt z kodem).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ButtonGlyph
extends RefCounted

static var _cache := {}


## kind: "play", "stop" albo "dot"; px – rozmiar w pikselach makiety (skalowany jak czcionki).
static func icon(kind: String, color: Color, px := 18) -> ImageTexture:
	var size := ThemeManager.fs(px)
	var key := "%s|%s|%d" % [kind, color.to_html(), size]
	if _cache.has(key):
		return _cache[key]
	var n := size * 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			var inside := false
			match kind:
				"play":
					inside = u > 0.18 and u < 0.86 and absf(v - 0.5) < (0.86 - u) * 0.62
				"stop":
					inside = u > 0.2 and u < 0.8 and v > 0.2 and v < 0.8
				_:
					inside = Vector2(u - 0.5, v - 0.5).length() < 0.32
			img.set_pixel(x, y, color if inside else Color(color, 0.0))
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
