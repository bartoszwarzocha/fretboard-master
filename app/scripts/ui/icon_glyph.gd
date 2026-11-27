# Fretboard Master – ikona z jednego znaku czcionki symboli, wyśrodkowana według faktycznego
# obrysu glifu (a nie metryk czcionki, które dla symboli muzycznych bywają przesunięte).
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name IconGlyph
extends Control

const MUSIC_HEIGHT := 0.8   # wysokość glifu Bravury względem font_size

var glyph := "":
	set(v):
		glyph = v
		_measure()
var font_size := 28:
	set(v):
		font_size = v
		_measure()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()

var _font: Font
var _ink := Rect2()   # obrys glifu względem punktu bazowego
var _size := 28      # rozmiar rysowania (dla Bravury – przeskalowany)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure()


# Czcionka, która faktycznie zawiera znak (symbole muzyczne – Bravura, reszta – Noto), i obrys glifu.
# Glify Bravury mają rozmiary nutowe (np. klucz wiolinowy jest dużo wyższy od krzyżyka), więc są
# skalowane do wspólnej wysokości – ikony modułów mają wtedy podobną wielkość.
func _measure() -> void:
	if glyph.is_empty() or not is_inside_tree():
		return
	_font = font_for(glyph)
	_size = font_size
	_ink = glyph_ink(_font, glyph, _size)
	if _font == ThemeManager.font_music and _ink.size.y > 0.0:
		_size = maxi(roundi(font_size * MUSIC_HEIGHT * font_size / _ink.size.y), 1)
		_ink = glyph_ink(_font, glyph, _size)
	queue_redraw()


static func font_for(text: String) -> Font:
	var c := text.unicode_at(0)
	if ThemeManager.font_music.has_char(c):
		return ThemeManager.font_music
	var base := ThemeManager.font_symbols
	for f in [base] + Array(base.fallbacks):
		if (f as Font).has_char(c):
			return f
	return base


## Obrys glifu (względem punktu bazowego) z konturów czcionki – niezależny od metryk i nadpróbkowania.
static func glyph_ink(font: Font, text: String, px: int) -> Rect2:
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var index := ts.font_get_glyph_index(rid, px, text.unicode_at(0), 0)
	var contours: Dictionary = ts.font_get_glyph_contours(rid, px, index)
	var points: PackedVector3Array = contours.get("points", PackedVector3Array())
	if points.is_empty():
		return Rect2()
	var lo := Vector2(points[0].x, points[0].y)
	var hi := lo
	for p in points:
		lo = lo.min(Vector2(p.x, p.y))
		hi = hi.max(Vector2(p.x, p.y))
	return Rect2(lo, hi - lo)


func _draw() -> void:
	if _font == null:
		return
	if _ink.size == Vector2.ZERO:
		var w := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, _size)
		draw_char(_font, Vector2((size.x - w.x) * 0.5, (size.y + _font.get_ascent(_size) - _font.get_descent(_size)) * 0.5), glyph, _size, color)
		return
	var origin := size * 0.5 - _ink.get_center()
	draw_char(_font, origin, glyph, _size, color)
