# Fretboard Master – ikona z jednego znaku czcionki symboli, wyśrodkowana według faktycznego
# obrysu glifu (a nie metryk czcionki, które dla symboli muzycznych bywają przesunięte).
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name IconGlyph
extends Control

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure()


# Czcionka, która faktycznie zawiera znak (główna lub zapasowa), i obrys glifu z konturów.
func _measure() -> void:
	if glyph.is_empty() or not is_inside_tree():
		return
	var base := ThemeManager.font_symbols
	_font = base
	for f in [base] + Array(base.fallbacks):
		if (f as Font).has_char(glyph.unicode_at(0)):
			_font = f
			break
	_ink = Rect2()
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = _font.get_rids()[0]
	var index := ts.font_get_glyph_index(rid, font_size, glyph.unicode_at(0), 0)
	var contours: Dictionary = ts.font_get_glyph_contours(rid, font_size, index)
	var points: PackedVector3Array = contours.get("points", PackedVector3Array())
	if not points.is_empty():
		var lo := Vector2(points[0].x, points[0].y)
		var hi := lo
		for p in points:
			lo = lo.min(Vector2(p.x, p.y))
			hi = hi.max(Vector2(p.x, p.y))
		_ink = Rect2(lo, hi - lo)
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	if _ink.size == Vector2.ZERO:
		var w := _font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_char(_font, Vector2((size.x - w.x) * 0.5, (size.y + _font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5), glyph, font_size, color)
		return
	var origin := size * 0.5 - _ink.get_center()
	draw_char(_font, origin, glyph, font_size, color)
