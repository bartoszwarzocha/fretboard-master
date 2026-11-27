# Fretboard Master – pięciolinia (Encyklopedia): klucz, znaki przykluczowe i nuty rysowane krojem
# Bravura (SMuFL) w jednym _draw. Nuty w zapisie gitarowym (klucz wiolinowy, dźwięk o oktawę niżej).
# Pozycja nuty: step – stopień diatoniczny względem E4 (dolna linia = 0, każda linia/pole = 1).
# items: [{heads: [{step, acc (null = bez znaku, 0 = kasownik, ±1, ±2), root}], label, bar}] –
# jedna główka = nuta pojedyncza, kilka – akord; bar = true – kreska taktowa.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name StaffView
extends Control

const G_CLEF := 0xE050
const G_CLEF_8VB := 0xE052
const HEAD_WHOLE := 0xE0A2
const ACC_GLYPH := {-2: 0xE264, -1: 0xE260, 0: 0xE261, 1: 0xE262, 2: 0xE263}
# Miejsca znaków przykluczowych w kluczu wiolinowym (stopnie od E4): krzyżyki F C G D A E H, bemole H E A D G C F.
const SHARP_STEPS := [8, 5, 9, 6, 3, 7, 4]
const FLAT_STEPS := [4, 7, 3, 6, 2, 5, 1]
const INK := Color("1A1A22")
const ROOT_INK := Color("B9770E")
const LABEL := Color("4A4A58")
const ROOT_LABEL := Color("8A5A08")
const PLAYING := Color("118C86")

var items: Array = []
var fifths := 0
var clef_8vb := false
var playing := -1           # indeks odtwarzanej nuty (podświetlenie)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_data(p_items: Array, p_fifths: int) -> void:
	items = p_items
	fifths = p_fifths
	playing = -1
	queue_redraw()


func set_playing(i: int) -> void:
	if playing != i:
		playing = i
		queue_redraw()


func _glyph(cp: int, pos: Vector2, sp: float, col: Color) -> void:
	draw_string(ThemeManager.font_music, pos, String.chr(cp), HORIZONTAL_ALIGNMENT_LEFT, -1, int(sp * 4.0), col)


func _glyph_w(cp: int, sp: float) -> float:
	return ThemeManager.font_music.get_string_size(String.chr(cp), HORIZONTAL_ALIGNMENT_LEFT, -1, int(sp * 4.0)).x


func _draw() -> void:
	if size.x < 40 or size.y < 40:
		return
	# Odstęp linii: wysokość mieści dwie linie dodane nad i pod pięciolinią oraz podpisy.
	# – oraz szerokość: klucz, znaki przykluczowe i ok. 3,4 odstępu linii na nutę (ze znakiem przygodnym).
	var units := 5.5 + mini(absi(fifths), 7) * 1.1 + maxi(items.size(), 8) * 3.7
	var sp := clampf(minf(size.y / 15.0, size.x / units), 6.0, 17.0)
	var bottom := size.y * 0.5 + sp * 2.6     # dolna linia (E4)
	var y_of := func(step: int) -> float: return bottom - step * sp * 0.5
	var x0 := sp * 0.6
	var x1 := size.x - sp * 0.6
	var line_w := maxf(sp * 0.1, 1.0)
	for i in 5:
		var y := bottom - i * sp
		draw_line(Vector2(x0, y), Vector2(x1, y), INK, line_w, true)
	# Klucz (linia G4 = step 2).
	var x := x0 + sp * 0.4
	_glyph(G_CLEF_8VB if clef_8vb else G_CLEF, Vector2(x, y_of.call(2)), sp, INK)
	x += _glyph_w(G_CLEF, sp) + sp * 0.8
	# Znaki przykluczowe.
	var n := absi(fifths)
	for i in mini(n, 7):
		var step: int = SHARP_STEPS[i] if fifths > 0 else FLAT_STEPS[i]
		var cp: int = ACC_GLYPH[1] if fifths > 0 else ACC_GLYPH[-1]
		_glyph(cp, Vector2(x, y_of.call(step)), sp, INK)
		x += _glyph_w(cp, sp) + sp * 0.15
	x += sp * 1.2
	if items.is_empty():
		return
	# Nuty – równe odstępy na pozostałej szerokości (z miejscem na znaki przygodne).
	var head_w := _glyph_w(HEAD_WHOLE, sp)
	var slot := minf((x1 - x - sp) / items.size(), sp * 5.0)
	var font := ThemeManager.font_body_bold
	var fsz := maxi(int(sp * 1.05), 10)
	for i in items.size():
		var it: Dictionary = items[i]
		var cx := x + slot * (i + 0.62)
		if it.get("bar", false):
			draw_line(Vector2(cx, bottom), Vector2(cx, bottom - 4 * sp), INK, line_w * 1.2, true)
			continue
		var heads: Array = it.heads.duplicate()
		heads.sort_custom(func(a, b): return a.step < b.step)
		var col_on := i == playing
		# Główki: sekunda w akordzie – górna nuta przesunięta w prawo.
		var shifted := []
		var prev_step := -100
		var prev_shift := false
		for h in heads:
			var sh: bool = h.step - prev_step == 1 and not prev_shift
			shifted.append(sh)
			prev_step = h.step
			prev_shift = sh
		var hx := cx - head_w * 0.5
		# Linie dodane.
		var lo: int = heads[0].step
		var hi: int = heads[heads.size() - 1].step
		var any_shift := true in shifted
		var lx0 := hx - sp * 0.4
		var lx1 := hx + head_w * (2.0 if any_shift else 1.0) + sp * 0.4
		var s := -2
		while s >= lo:
			draw_line(Vector2(lx0, y_of.call(s)), Vector2(lx1, y_of.call(s)), INK, line_w, true)
			s -= 2
		s = 10
		while s <= hi:
			draw_line(Vector2(lx0, y_of.call(s)), Vector2(lx1, y_of.call(s)), INK, line_w, true)
			s += 2
		# Znaki przygodne – kolumny od góry, gdy znaki są bliżej niż seksta.
		var acc_cols := []    # [step ostatniego znaku w kolumnie]
		for j in range(heads.size() - 1, -1, -1):
			var h: Dictionary = heads[j]
			if h.acc == null:
				continue
			var c := 0
			while c < acc_cols.size() and acc_cols[c] - h.step < 6:
				c += 1
			if c == acc_cols.size():
				acc_cols.append(h.step)
			else:
				acc_cols[c] = h.step
			var cp: int = ACC_GLYPH.get(int(h.acc), ACC_GLYPH[0])
			var aw := _glyph_w(cp, sp)
			var ink := PLAYING if col_on else (ROOT_INK if h.root else INK)
			_glyph(cp, Vector2(hx - aw - sp * 0.6 - c * (aw + sp * 0.2), y_of.call(h.step)), sp, ink)
		for j in heads.size():
			var h: Dictionary = heads[j]
			var ink := PLAYING if col_on else (ROOT_INK if h.root else INK)
			_glyph(HEAD_WHOLE, Vector2(hx + (head_w if shifted[j] else 0.0), y_of.call(h.step)), sp, ink)
		var label: String = it.get("label", "")
		if not label.is_empty():
			var root: bool = heads[0].root
			var lc := PLAYING if col_on else (ROOT_LABEL if root else LABEL)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			draw_string(font, Vector2(cx - w * 0.5, bottom + sp * 3.6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, lc)
