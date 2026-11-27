# Fretboard Master – gryf: widok realistyczny 3D albo schematyczny, wg ustawień (Gitara → Wygląd
# gryfu, Grafika → Gryf 3D). Wspólny element dla Encyklopedii, Ćwiczeń i podglądu w ustawieniach.
#  • 3D: scena Neck3D w jednym SubViewporcie rysowanym tylko po zmianie; obraz pokazuje TextureRect
#    (odbity w poziomie dla leworęcznych). Napisy na znacznikach, nazwy strun i numery progów
#    rysuje ten węzeł – jedno _draw, bez węzłów tekstu w scenie 3D.
#  • Schematy: rysowana tabela, kąty proste, kształt gryfu – w całości w _draw.
# Dźwięki: set_notes([{s, f, text, root, dim}]) – s: struna (0 = najwyższa), f: próg (0 = pusta).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name FretboardView
extends Control

# Ustawienia, których zmiana przebudowuje gryf.
const KEYS := [&"neck_view", &"fretboard_wood", &"fret_metal", &"string_color", &"inlays", &"strings",
		&"frets", &"tuning", &"left_handed", &"neck_tilt", &"neck_fov", &"shadows", &"msaa", &"notation"]
const GUTTER := 56.0        # kolumna nazw strun
const TOP := 30.0           # wiersz numerów progów
const PAD := 10.0
const THICK := [1.0, 1.3, 1.7, 2.2, 2.7, 3.2, 3.7, 4.2]
const INLAY_SINGLE := [3, 5, 7, 9, 15, 17, 19, 21]

var spec: NeckSpec
var demo := false           # przykładowa skala (podgląd w ustawieniach) – odtwarzana po każdej zmianie
var _notes: Array = []
var _view := ""
var _lefty := false
var _vp: SubViewport
var _tex: TextureRect
var _neck: Neck3D
var _dirty := true


func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)
	App.settings_changed.connect(func(key: StringName) -> void:
		if key in KEYS:
			_rebuild())
	_rebuild()


func set_notes(notes: Array) -> void:
	_notes = notes
	if _neck:
		_neck.set_notes(_notes)
		_render()
	queue_redraw()


# Przykład do podglądu: skala dorycka od D na całym gryfie (tonika wyróżniona).
static func demo_notes(neck: NeckSpec) -> Array:
	var root := 2
	var steps := [0, 2, 3, 5, 7, 9, 10]
	var out := []
	for s in neck.strings:
		for f in neck.frets + 1:
			var midi: int = neck.open_midi[s] + f
			if posmod(midi - root, 12) in steps:
				out.append({"s": s, "f": f, "text": NoteNames.note_name(midi, App.notation()),
					"root": posmod(midi, 12) == root})
	return out


func _rebuild() -> void:
	spec = NeckSpec.from_settings()
	_view = str(App.setting(&"neck_view"))
	_lefty = bool(App.setting(&"left_handed"))
	if demo:
		_notes = demo_notes(spec)
	if _vp:
		_vp.queue_free()
		_tex.queue_free()
		_vp = null
		_tex = null
		_neck = null
	if NeckSpec.is_3d(_view):
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.msaa_3d = mini(Graphics.msaa_mode(), Viewport.MSAA_4X) as Viewport.MSAA
		_vp.positional_shadow_atlas_size = 0
		_vp.audio_listener_enable_3d = false
		_vp.gui_disable_input = true
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_vp)
		_neck = Neck3D.new()
		_vp.add_child(_neck)
		_neck.build(spec)
		_neck.set_notes(_notes)
		_tex = TextureRect.new()
		_tex.texture = _vp.get_texture()
		_tex.flip_h = _lefty
		_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tex.show_behind_parent = true
		add_child(_tex)
	_on_resized()


func _on_resized() -> void:
	if _vp and size.x > 1 and size.y > 1:
		_vp.size = Vector2i(size)
		_neck.fit_camera(size, _region_3d(), float(App.setting(&"neck_tilt")), float(App.setting(&"neck_fov")))
		_render()
	queue_redraw()


func _render() -> void:
	if _vp:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# Prostokąt gryfu w obrazie 3D (bez kolumny nazw strun i wiersza numerów progów); u leworęcznych
# obraz jest odbity, więc kolumna nazw – po drugiej stronie.
func _region_3d() -> Rect2:
	var r := Rect2(GUTTER, TOP, size.x - GUTTER - PAD, size.y - TOP - PAD)
	if _lefty:
		r.position.x = size.x - r.end.x
	return r


# Odbicie współrzędnej x dla leworęcznych.
func _mx(x: float) -> float:
	return size.x - x if _lefty else x


func _p3(p: Vector3) -> Vector2:
	var v := _neck.project(p)
	return Vector2(_mx(v.x), v.y)


# --- Rysowanie ----------------------------------------------------------------

func _draw() -> void:
	if spec == null or size.x < 10:
		return
	match _view:
		"table": _draw_table()
		"grid": _draw_grid()
		"neck_shape": _draw_shape()
		_:
			if _neck:
				_draw_3d()


func _font() -> Font:
	return ThemeManager.font_body_bold


func _text_c(pos: Vector2, t: String, fs: int, col: Color) -> void:
	var f := _font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, pos + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _fret_label(pos: Vector2, n: int) -> void:
	_text_c(pos, str(n), 13, NeckSpec.ORANGE if n == 12 else ThemeManager.color("faint"))


func _string_label(y: float, s: int) -> void:
	_text_c(Vector2(_mx(GUTTER * 0.5), y), spec.string_label(s), 14, ThemeManager.color("muted"))


func _draw_3d() -> void:
	for n in range(1, spec.frets + 1):
		var cx := (spec.xf(n - 1) + spec.xf(n)) * 0.5
		var p := _p3(Vector3(cx, 0, -spec.half_w(cx) - 3.0))
		_fret_label(Vector2(p.x, p.y - 8.0), n)
	for s in spec.strings:
		_string_label(_p3(Vector3(0, spec.string_y(s, 0.0), spec.string_z(s, 0.0))).y, s)
	for m in _neck.markers():
		var c := _p3(m.pos + Vector3(0, m.r * 0.42, 0))
		var edge := _p3(m.pos + Vector3(m.r, m.r * 0.22, 0))
		var r_px := absf(edge.x - c.x)
		var root: bool = m.note.get("root", false)
		var col := Color("#1A1204") if root else Color("#04201E")
		if m.note.get("dim", false):
			col.a = 0.5
		_text_c(c, str(m.note.get("text", "")), maxi(int(r_px * 1.15), 6), col)


# Znacznik w schematach: płaski krążek z ciemną obwódką.
func _marker(c: Vector2, r: float, note: Dictionary) -> void:
	var root: bool = note.get("root", false)
	var base := NeckSpec.ORANGE if root else NeckSpec.TEAL
	var fg := Color("#1A1204") if root else Color("#04201E")
	if note.get("dim", false):
		base = base.lerp(Color("#1A1F2E"), 0.7)
		fg.a = 0.5
	draw_circle(c, r + 1.6, Color("#070A14"))
	draw_circle(c, r, base)
	_text_c(c, str(note.get("text", "")), maxi(int(r * 1.15), 6), fg)


func _schema_notes(pos_fn: Callable, r_fn: Callable) -> void:
	for n in _notes:
		if n.s >= 0 and n.s < spec.strings and n.f >= 0 and n.f <= spec.frets:
			_marker(pos_fn.call(n.s, n.f), r_fn.call(n.f), n)


func _inlay_cells() -> Array:
	return INLAY_SINGLE.filter(func(f: int) -> bool: return f <= spec.frets) + \
			[12, 24].filter(func(f: int) -> bool: return f <= spec.frets)


# 1) Rysowana tabela – równe komórki, wiersze = struny.
func _draw_table() -> void:
	var x0 := GUTTER
	var c0 := 52.0
	var cw := (size.x - x0 - c0 - PAD) / spec.frets
	var rh := (size.y - TOP - PAD) / spec.strings
	var line := ThemeManager.color("border").lerp(Color("#2A3558"), 0.5)
	var y0 := TOP
	var w := c0 + cw * spec.frets
	draw_rect(Rect2(_lx(x0, w), y0, w, rh * spec.strings), Color("#0F1528"))
	for f in _inlay_cells():
		draw_rect(Rect2(_lx(x0 + c0 + cw * (f - 1), cw), y0, cw, rh * spec.strings), Color("#141C36"))
	for n in range(1, spec.frets + 1):
		_fret_label(Vector2(_mx(x0 + c0 + cw * (n - 0.5)), y0 - 12), n)
	for s in spec.strings + 1:
		draw_line(Vector2(_mx(x0), y0 + rh * s), Vector2(_mx(x0 + w), y0 + rh * s), line, 1.0)
	draw_line(Vector2(_mx(x0), y0), Vector2(_mx(x0), y0 + rh * spec.strings), line, 1.0)
	for n in spec.frets + 1:
		var x := _mx(x0 + c0 + cw * n)
		draw_line(Vector2(x, y0), Vector2(x, y0 + rh * spec.strings), Color("#C9C2B0") if n == 0 else line, 4.0 if n == 0 else 1.0)
	for s in spec.strings:
		_string_label(y0 + rh * (s + 0.5), s)
	var r := minf(rh * 0.36, cw * 0.4)
	_schema_notes(func(s, f): return Vector2(_mx(x0 + (c0 * 0.5 if f == 0 else c0 + cw * (f - 0.5))), y0 + rh * (s + 0.5)),
		func(_f): return r)


# Lewy brzeg prostokąta o szerokości w (po odbiciu dla leworęcznych).
func _lx(x: float, w: float) -> float:
	return size.x - x - w if _lefty else x


# Kolory obu schematów linii (kąty proste i kształt gryfu) – wspólne.
const SCH_BOARD := Color("#161D33")
const SCH_FRET := Color("#8D97B3")
const SCH_NUT := Color("#E8ECF6")
const SCH_STRING := Color("#C9CFDF")
const SCH_INLAY := Color("#3A4566")


# 2) Kąty proste – struny jako linie, równe odstępy progów.
func _draw_grid() -> void:
	var x0 := GUTTER + 44.0
	var cw := (size.x - x0 - PAD) / spec.frets
	var top := TOP + 12.0
	var sp := (size.y - top - PAD - 12.0) / (spec.strings - 1)
	var h := sp * (spec.strings - 1)
	draw_rect(Rect2(_lx(x0, cw * spec.frets), top - 12, cw * spec.frets, h + 24), SCH_BOARD)
	var mid := h * 0.5
	for f in INLAY_SINGLE:
		if f <= spec.frets:
			draw_circle(Vector2(_mx(x0 + cw * (f - 0.5)), top + mid), 5.0, SCH_INLAY)
	for f in [12, 24]:
		if f <= spec.frets:
			for z in [mid - sp, mid + sp]:
				draw_circle(Vector2(_mx(x0 + cw * (f - 0.5)), top + z), 5.0, SCH_INLAY)
	for n in range(1, spec.frets + 1):
		draw_line(Vector2(_mx(x0 + cw * n), top - 12), Vector2(_mx(x0 + cw * n), top + h + 12), SCH_FRET, 2.0)
		_fret_label(Vector2(_mx(x0 + cw * (n - 0.5)), top - 24), n)
	draw_rect(Rect2(_lx(x0 - 6, 6), top - 12, 6, h + 24), SCH_NUT)
	for s in spec.strings:
		var y := top + sp * s
		draw_line(Vector2(_mx(x0 - 40), y), Vector2(_mx(x0 + cw * spec.frets), y), SCH_STRING, THICK[s])
		_string_label(y, s)
	var r := minf(sp * 0.36, cw * 0.4)
	_schema_notes(func(s, f): return Vector2(_mx(x0 - 26 if f == 0 else x0 + cw * (f - 0.5)), top + sp * s),
		func(_f): return r)


# 3) Kształt gryfu – płaski rysunek z prawdziwą menzurą i zwężeniem (kolory jak „kąty proste”).
func _draw_shape() -> void:
	var x0 := GUTTER + 44.0
	var xend := spec.x_end
	var k := minf((size.x - x0 - PAD) / xend, (size.y - TOP - PAD - 6.0) / (2.0 * spec.half_w(xend)))
	var yc := TOP + 6.0 + spec.half_w(xend) * k
	var X := func(x: float) -> float: return _mx(x0 + x * k)
	var Z := func(z: float) -> float: return yc + z * k
	draw_colored_polygon(PackedVector2Array([
		Vector2(X.call(0.0), Z.call(-spec.half_w(0.0))), Vector2(X.call(xend), Z.call(-spec.half_w(xend))),
		Vector2(X.call(xend), Z.call(spec.half_w(xend))), Vector2(X.call(0.0), Z.call(spec.half_w(0.0)))]), SCH_BOARD)
	for f in INLAY_SINGLE:
		if f <= spec.frets:
			draw_circle(Vector2(X.call((spec.xf(f - 1) + spec.xf(f)) * 0.5), yc), 5.0, SCH_INLAY)
	var mid := spec.strings / 2
	for f in [12, 24]:
		if f <= spec.frets:
			var c := (spec.xf(f - 1) + spec.xf(f)) * 0.5
			for s in [mid - 2, mid]:
				var z := (spec.string_z(s, c) + spec.string_z(s + 1, c)) * 0.5
				draw_circle(Vector2(X.call(c), Z.call(z)), 5.0, SCH_INLAY)
	for n in range(1, spec.frets + 1):
		var x := spec.xf(n)
		draw_line(Vector2(X.call(x), Z.call(-spec.half_w(x))), Vector2(X.call(x), Z.call(spec.half_w(x))), SCH_FRET, 2.0, true)
		_fret_label(Vector2(X.call((spec.xf(n - 1) + x) * 0.5), Z.call(-spec.half_w(x)) - 12), n)
	var nx: float = X.call(0.0)
	draw_rect(Rect2(nx - 7 if not _lefty else nx, Z.call(-spec.half_w(0.0)), 7, spec.half_w(0.0) * 2.0 * k), SCH_NUT)
	for s in spec.strings:
		draw_line(Vector2(X.call(0.0), Z.call(spec.string_z(s, 0.0))), Vector2(X.call(xend), Z.call(spec.string_z(s, xend))),
			SCH_STRING, THICK[s], true)
		_string_label(Z.call(spec.string_z(s, 0.0)), s)
	var rpx := spec.marker_r * k
	_schema_notes(func(s, f):
			var x := spec.marker_x(f) if f > 0 else 0.0
			var px: float = X.call(x)
			if f == 0:
				px = _mx(x0 - rpx - 10.0)
			return Vector2(px, Z.call(spec.string_z(s, maxf(x, 0.0)))),
		func(f): return spec.marker_radius(f) * k if f > 0 else rpx)
