# Fretboard Master – gryf: widok realistyczny 3D albo schematyczny, wg ustawień (Gitara → Wygląd
# gryfu, Grafika → Gryf 3D). Wspólny element dla Encyklopedii, Ćwiczeń i podglądu w ustawieniach.
#  • 3D: scena Neck3D w jednym SubViewporcie rysowanym tylko po zmianie; obraz pokazuje TextureRect
#    (odbity w poziomie dla leworęcznych). Napisy na znacznikach, nazwy strun i numery progów
#    rysuje ten węzeł – jedno _draw, bez węzłów tekstu w scenie 3D.
#  • Schematy: rysowana tabela, kąty proste, kształt gryfu – w całości w _draw.
# Dźwięki: set_notes([{s, f, text, root, dim}]) – s: struna (0 = najwyższa), f: próg (0 = pusta).
# Sterowanie myszą (interactive = true – Encyklopedia, Ćwiczenia; podgląd w ustawieniach zawsze pokazuje
# cały gryf): LPM – kliknięcie zaznacza dźwięk (sygnał note_picked), przeciągnięcie przesuwa
# przybliżony gryf; kółko – zoom do kursora; PPM – nachylenie na boki i wzdłuż osi gryfu (w zakresie
# z ustawień); dwuklik – widok domyślny. Zoom, nachylenie i przesuwanie dotyczą widoku 3D.
# Zakres ćwiczenia (Encyklopedia): fret_range przyciemnia gryf poza zakresem, a ruler = true rysuje
# pod gryfem linijkę progów z zaznaczonym zakresem (kliknięcie progu – sygnał fret_clicked).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name FretboardView
extends Control

signal note_picked(string_index: int, fret: int)
signal fret_clicked(fret: int)

# Ustawienia, których zmiana przebudowuje gryf.
const KEYS := [&"neck_view", &"fretboard_wood", &"fret_metal", &"string_color", &"inlays", &"strings",
		&"frets", &"tuning", &"instrument", &"bass_strings", &"bass_tuning", &"left_handed", &"neck_tilt_range", &"neck_zoom_max", &"neck_fov", &"shadows", &"msaa", &"notation",
		&"marker_color", &"marker_root_color", &"marker_text_color", &"marker_rim", &"marker_rim_color"]
const GUTTER := 56.0        # kolumna nazw strun
const TOP := 30.0           # wiersz numerów progów
const PAD := 10.0
const SS := 2.0             # nadpróbkowanie obrazu 3D (2× w każdą stronę) – gładkie struny i krawędzie
# Najwięcej pikseli obrazu 3D: większy gryf (np. tryb „Duży gryf”) dostaje mniejsze nadpróbkowanie,
# żeby bufor (i pamięć karty) nie rósł ponad zwykły widok Encyklopedii.
const SS_PIXELS := 2500000.0
const THICK := [1.0, 1.3, 1.7, 2.2, 2.7, 3.2, 3.7, 4.2]
const RULER_H := 62.0       # linijka progów pod gryfem (tryb ruler)
const SHADE := Color(0.02, 0.03, 0.07, 0.62)   # przyciemnienie poza zakresem

var spec: NeckSpec
var interactive := false    # sterowanie myszą (Encyklopedia, Ćwiczenia)
var selected := Vector2i(-1, -1)   # zaznaczony dźwięk: (struna, próg)
var playing := Vector2i(-1, -1)    # dźwięk odtwarzany (Encyklopedia – odsłuch) – podświetlenie
var demo := false           # przykładowa skala (podgląd w ustawieniach) – odtwarzana po każdej zmianie
var ruler := false          # linijka progów z zakresem pod gryfem (zamiast numerów progów nad nim)
var fret_range := Vector2i(-1, -1)   # zakres progów (od, do); (-1, -1) – cały gryf bez przyciemnienia
var heard := Vector2i(-1, -1)      # dźwięk zagrany na gitarze (Encyklopedia) – podświetlenie z poświatą
var heard_ok := true               # w skali (zielony) albo poza nią (pomarańczowy)
var heard_text := ""
var _heard_r := 10.0
var shifts: Array = []      # przesunięcia ręki (superpozycje): [[Vector2i z, Vector2i do]] – strzałki
var _notes: Array = []
var _view := ""
var _lefty := false
var _vp: SubViewport
var _tex: TextureRect
var _neck: Neck3D
var _zoom := 1.0
var _pitch := 0.0
var _yaw := 0.0
var _pan := Vector2.ZERO
var _press := Vector2.ZERO
var _dragging := false
var _cells := {}            # Vector2i(struna, próg) → środek pola na ekranie (do zaznaczania)


func _ready() -> void:
	clip_contents = true
	resized.connect(_on_resized)
	App.settings_changed.connect(func(key: StringName) -> void:
		if key in KEYS:
			_rebuild())
	_rebuild()
	if interactive:
		_hint = _MouseHint.new()
		_hint.modulate.a = 0.0
		add_child(_hint)
		_place_hint()
		mouse_entered.connect(_fade_hint.bind(1.0))
		mouse_exited.connect(_fade_hint.bind(0.0))


# Podpowiedź sterowania myszą (Encyklopedia, Ćwiczenia): w prawym górnym rogu gryfu, pojawia się
# płynnie po najechaniu na gryf. Osobny węzeł – zanikanie zmienia tylko jego modulate.
var _hint: Control
var _ss := SS
var _hint_tween: Tween


func _fade_hint(a: float) -> void:
	if _hint == null:
		return
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", a, 0.25)


func _place_hint() -> void:
	if _hint:
		var hs := _hint.get_combined_minimum_size()
		_hint.size = hs
		_hint.position = Vector2(size.x - hs.x - 12.0, 6.0)


class _MouseHint extends Control:
	const ITEMS := [["wheel", "zoom"], ["left", "move"], ["right", "rotate"]]
	const W := 17.0               # ikona myszy (logicznie), proporcje rysunku SVG 24 × 34
	const H := 24.0
	const FONT := 13
	const INK := Color("#E8ECF6")
	# Mysz wektorowo (SVG): zaokrąglony korpus, dwa przyciski z linią podziału, kółko pośrodku;
	# wyróżniony element – kolorem akcentu. Rysunek renderowany do tekstury w rozmiarze ekranowym
	# (ostry przy każdej skali), raz na kolor i rozmiar.
	const SVG := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 34" width="{w}" height="{h}">
<defs><clipPath id="b"><rect x="2" y="2" width="20" height="30" rx="10" ry="10"/></clipPath></defs>
<g clip-path="url(#b)">{fill}</g>
<rect x="2" y="2" width="20" height="30" rx="10" ry="10" fill="none" stroke="{ink}" stroke-width="1.8"/>
<path d="M2 13.5H22M12 2V13.5" fill="none" stroke="{ink}" stroke-width="1.6"/>
<rect x="9.75" y="5" width="4.5" height="7.5" rx="2.25" ry="2.25" fill="{wheel}" stroke="{ink}" stroke-width="1.3"/>
</svg>"""
	var _cache := {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		var f := ThemeManager.font_body
		var w := 0.0
		for it in ITEMS:
			w += W + 7.0 + f.get_string_size(tr(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x + 18.0
		return Vector2(w + 14.0, H + 14.0)

	func _icon(kind: String, acc: Color, px: Vector2i) -> Texture2D:
		var key := "%s|%s|%s" % [kind, acc.to_html(), px]
		if _cache.has(key):
			return _cache[key]
		var a := "#" + acc.to_html(false)
		var fill := ""
		match kind:
			"left": fill = '<rect x="0" y="0" width="12" height="13.5" fill="%s"/>' % a
			"right": fill = '<rect x="12" y="0" width="12" height="13.5" fill="%s"/>' % a
		var svg := SVG.format({"w": 24, "h": 34, "ink": "#" + INK.to_html(false), "fill": fill,
				"wheel": a if kind == "wheel" else "none"})
		var img := Image.new()
		img.load_svg_from_string(svg, float(px.y) / 34.0)
		var tex := ImageTexture.create_from_image(img)
		_cache[key] = tex
		return tex

	func _draw() -> void:
		var f := ThemeManager.font_body
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#070A14", 0.86)
		sb.set_corner_radius_all(9)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var acc := ThemeManager.color("accent")
		# Rozmiar ikony w pikselach ekranu – tekstura 1:1, bez rozmywania.
		var k := get_global_transform_with_canvas().get_scale().y
		var px := Vector2i(roundi(W * k), roundi(H * k))
		var x := 9.0
		var y := 7.0
		for it in ITEMS:
			draw_texture_rect(_icon(it[0], acc, px), Rect2(x, y, W, H), false)
			var t: String = tr(it[1])
			draw_string(f, Vector2(x + W + 7.0, y + H * 0.5 + FONT * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT, Color(INK, 0.92))
			x += W + 7.0 + f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x + 18.0


func set_notes(notes: Array) -> void:
	_notes = notes
	if _neck:
		_neck.set_notes(_notes)
		_render()
	queue_redraw()


func set_range(from: int, to: int) -> void:
	fret_range = Vector2i(from, to)
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


# Grubość linii struny na schematach; struny basu – grubsze, wg średnicy.
func _thick(s: int) -> float:
	return 1.4 + spec.gauge(s) * 1.1 if spec.bass else THICK[mini(s, THICK.size() - 1)]


func _rebuild() -> void:
	spec = NeckSpec.from_settings()
	_view = str(App.setting(&"neck_view"))
	_lefty = bool(App.setting(&"left_handed"))
	if demo:
		_notes = demo_notes(spec)
	_drop_3d()
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
		_neck = _take_neck(spec)
		_vp.add_child(_neck)
		_neck.set_notes(_notes)
		_tex = TextureRect.new()
		_tex.texture = _vp.get_texture()
		_tex.flip_h = _lefty
		_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tex.stretch_mode = TextureRect.STRETCH_SCALE
		_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tex.show_behind_parent = true
		add_child(_tex)
	_on_resized()


func _exit_tree() -> void:
	_drop_3d()


func _drop_3d() -> void:
	if _vp:
		_release_neck(_neck)
		_vp.queue_free()
		_tex.queue_free()
		_vp = null
		_tex = null
		_neck = null


# --- Gryf 3D w pamięci ---------------------------------------------------------------
# Zbudowana scena gryfu jest przechowywana po zamknięciu widoku i używana ponownie, gdy ustawienia
# się nie zmieniły (budowa siatek w GDScripcie trwa kilkadziesiąt ms). Rozgrzewka na ekranie
# startowym buduje ją z wyprzedzeniem i rysuje raz, żeby skompilować shadery.

static var _cached_neck: Neck3D
static var _cached_key := ""


static func _neck_key() -> String:
	var parts := PackedStringArray()
	for k in KEYS:
		parts.append(str(App.setting(k)))
	return "|".join(parts)


static func _take_neck(neck_spec: NeckSpec) -> Neck3D:
	var key := _neck_key()
	if is_instance_valid(_cached_neck) and _cached_key == key and _cached_neck.get_parent() == null:
		return _cached_neck
	if is_instance_valid(_cached_neck) and _cached_neck.get_parent() == null:
		_cached_neck.free()
	var n := Neck3D.new()
	n.build(neck_spec)
	_cached_neck = n
	_cached_key = key
	return n


static func _release_neck(n: Neck3D) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n == _cached_neck and _cached_key == _neck_key():
		n.get_parent().remove_child(n)     # zostaje w pamięci do następnego otwarcia
	elif n == _cached_neck:
		_cached_neck = null


# Zwolnienie przechowywanej sceny przy zamykaniu programu (bez wycieków zasobów renderera).
static func free_cache() -> void:
	if is_instance_valid(_cached_neck) and _cached_neck.get_parent() == null:
		_cached_neck.free()
	_cached_neck = null


# Rozgrzewka (ekran startowy): budowa gryfu wg bieżących ustawień i jedno narysowanie poza ekranem.
static func warm_up(host: Node) -> void:
	var neck_spec := NeckSpec.from_settings()
	if not NeckSpec.is_3d(str(App.setting(&"neck_view"))):
		return
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(640, 160)
	vp.msaa_3d = mini(Graphics.msaa_mode(), Viewport.MSAA_4X) as Viewport.MSAA
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(vp)
	var n := _take_neck(neck_spec)
	vp.add_child(n)
	n.set_notes(demo_notes(neck_spec))
	n.fit_camera(Vector2(vp.size), Rect2(40, 20, 590, 130), float(App.setting(&"neck_fov")))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.remove_child(n)
	vp.queue_free()


func _on_resized() -> void:
	_place_hint()
	if _vp and size.x > 1 and size.y > 1:
		_ss = clampf(sqrt(SS_PIXELS / maxf(size.x * size.y, 1.0)), 1.4, SS)
		_vp.size = Vector2i(size * _ss)
		# Duży obraz (Encyklopedia – gryf na całą szerokość): nadpróbkowanie 2× już wygładza krawędzie,
		# więc MSAA najwyżej 2× – bufor wielopróbkowy 4× zająłby kilkadziesiąt MB pamięci karty.
		var cap := Viewport.MSAA_2X if _vp.size.x * _vp.size.y > 1500000 else Viewport.MSAA_4X
		_vp.msaa_3d = mini(Graphics.msaa_mode(), cap) as Viewport.MSAA
		_apply_camera()
	queue_redraw()


func _apply_camera() -> void:
	var r := _region_3d()
	var lim := _neck.pan_limit(_zoom)
	_pan = _pan.clamp(-lim, lim)
	_neck.fit_camera(size * _ss, Rect2(r.position * _ss, r.size * _ss), float(App.setting(&"neck_fov")),
			_zoom, _pitch, _yaw, _pan)
	_render()
	queue_redraw()


func reset_view() -> void:
	_zoom = 1.0
	_pitch = 0.0
	_yaw = 0.0
	_pan = Vector2.ZERO
	if _neck:
		_apply_camera()


# --- Mysz ------------------------------------------------------------------------

# Piksel obrazu 3D pod punktem widoku (nadpróbkowanie, odbicie dla leworęcznych).
func _vp_px(p: Vector2) -> Vector2:
	return Vector2(_mx(p.x), p.y) * _ss


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if ruler and mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.position.y >= size.y - RULER_H:
		var f := _ruler_fret(mb.position.x)
		if f >= 0:
			fret_clicked.emit(f)
		accept_event()
		return
	if not interactive:
		return
	if mb:
		if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			reset_view()
			accept_event()
			return
		if _neck and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := _neck.board_point(_vp_px(mb.position))
			var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			_zoom = clampf(_zoom * f, 1.0, float(App.setting(&"neck_zoom_max")))
			_apply_camera()
			var after := _neck.board_point(_vp_px(mb.position))
			_pan += Vector2(before.x - after.x, before.z - after.z)
			_apply_camera()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_dragging = false
			elif not _dragging:
				_pick(mb.position)
			accept_event()
		return
	var mm := event as InputEventMouseMotion
	if mm and _neck:
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _dragging and mm.position.distance_to(_press) > 4.0:
				_dragging = true
			if _dragging and _zoom > 1.0:
				var a := _neck.board_point(_vp_px(mm.position - mm.relative))
				var b := _neck.board_point(_vp_px(mm.position))
				_pan += Vector2(a.x - b.x, a.z - b.z)
				_apply_camera()
			accept_event()
		elif mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			var lim := float(App.setting(&"neck_tilt_range"))
			_yaw = clampf(_yaw + mm.relative.x * 0.2 * (-1.0 if _lefty else 1.0), -lim, lim)
			_pitch = clampf(_pitch + mm.relative.y * 0.2, -lim, lim)
			_apply_camera()
			accept_event()


# Kliknięcie: najbliższe pole (struna, próg) – zaznaczenie albo odznaczenie.
func _pick(p: Vector2) -> void:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for k in _cells:
		var d: float = (_cells[k] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = k
	if best.x < 0 or best_d > 40.0:
		return
	selected = Vector2i(-1, -1) if selected == best else best
	queue_redraw()
	if selected.x >= 0:
		note_picked.emit(selected.x, selected.y)


# Pola wszystkich strun i progów na ekranie (pos_fn jak dla znaczników) + obwódka zaznaczenia.
func _store_cells(pos_fn: Callable, r: float) -> void:
	_heard_r = r
	_cells.clear()
	for s in spec.strings:
		for f in spec.frets + 1:
			_cells[Vector2i(s, f)] = pos_fn.call(s, f)
	if not barre.is_empty():
		_draw_barre(r)
	if not shifts.is_empty():
		_draw_shifts(r)
	if selected.x >= 0 and _cells.has(selected):
		draw_arc(_cells[selected], r + 4.0, 0, TAU, 40, ThemeManager.color("text"), 2.5, true)
	if playing.x >= 0 and _cells.has(playing):
		var c: Vector2 = _cells[playing]
		draw_circle(c, r + 9.0, Color(ThemeManager.color("focus"), 0.22))
		draw_arc(c, r + 5.0, 0, TAU, 40, ThemeManager.color("focus"), 3.5, true)


func set_heard(p: Vector2i, ok: bool, text := "") -> void:
	if heard != p or (p.x >= 0 and (heard_ok != ok or heard_text != text)):
		heard = p
		heard_ok = ok
		heard_text = text
		queue_redraw()


var barre := {}     # belka barré chwytu: {f, from_s, to_s}


func set_barre(b: Dictionary) -> void:
	if barre != b:
		barre = b
		queue_redraw()


# Belka barré: półprzezroczysty pasek z zaokrąglonymi końcami w poprzek strun na progu chwytu.
func _draw_barre(r: float) -> void:
	var a := Vector2i(barre.from_s, barre.f)
	var b := Vector2i(barre.to_s, barre.f)
	if not (_cells.has(a) and _cells.has(b)):
		return
	var pa: Vector2 = _cells[a]
	var pb: Vector2 = _cells[b]
	var d := (pb - pa).normalized()
	var w := r * 1.5
	var col := Color("#E8ECF6", 0.38)
	draw_line(pa - d * r, pb + d * r, col, w * 2.0, true)


func set_shifts(p: Array) -> void:
	shifts = p
	queue_redraw()


# Strzałka przesunięcia ręki: od krawędzi znacznika do krawędzi następnego, łukiem.
func _draw_shifts(r: float) -> void:
	var col := ThemeManager.color("focus")
	var arcs := []                       # łuki – po jednej łamanej (draw_multiline rozbija na setki obiektów)
	var heads := PackedVector2Array()    # groty – trójkąty w jednym wywołaniu
	for sh in shifts:
		if not (_cells.has(sh[0]) and _cells.has(sh[1])):
			continue
		var a: Vector2 = _cells[sh[0]]
		var b: Vector2 = _cells[sh[1]]
		var d := b - a
		if d.length() < r * 2.5:
			continue
		# Łuk wygięty do środka gryfu – przy skrajnych strunach nie wychodzi poza widok.
		var n := Vector2(d.y, -d.x).normalized()
		var mid := (a + b) * 0.5
		var inner: Vector2 = _cells.get(Vector2i(spec.strings / 2, sh[1].y), mid)
		if n.dot(inner - mid) < 0.0:
			n = -n
		var bend := n * minf(d.length() * 0.18, r * 1.1)
		# Łuk obcięty do krawędzi znaczników.
		var keep := PackedVector2Array()
		for i in 21:
			var t := i / 20.0
			var q := a.lerp(b, t) + bend * 4.0 * t * (1.0 - t)
			if q.distance_to(a) > r + 3.0 and q.distance_to(b) > r + 6.0:
				keep.append(q)
		if keep.size() < 2:
			continue
		arcs.append(keep)
		var tip := keep[keep.size() - 1]
		var dir := (tip - keep[keep.size() - 2]).normalized()
		var side := Vector2(-dir.y, dir.x)
		heads.append_array([tip + dir * 7.0, tip - dir * 4.0 + side * 6.0, tip - dir * 4.0 - side * 6.0])
	if arcs.is_empty():
		return
	for k in arcs:
		draw_polyline(k, Color("#070A14", 0.6), 5.5, true)
	for k in arcs:
		draw_polyline(k, col, 3.0, true)
	var cols := PackedColorArray()
	cols.resize(heads.size())
	cols.fill(col)
	var idx := PackedInt32Array()
	for i in heads.size():
		idx.append(i)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, heads, cols)


# Dźwięk zagrany na gitarze – na wierzchu, po przyciemnieniu zakresu.
func _draw_heard(r: float) -> void:
	if heard.x < 0 or not _cells.has(heard):
		return
	# Pełne koło z poświatą w miejscu dźwięku (promień z odstępu strun w tym miejscu – działa też
	# w perspektywie 3D) i nazwa dźwięku na wierzchu.
	var hc: Vector2 = _cells[heard]
	var g := Color("#4CD964") if heard_ok else Color("#FF9A3C")
	var rr := r * 1.12
	var nb := Vector2i(heard.x + (1 if heard.x == 0 else -1), heard.y)
	if _cells.has(nb):
		rr = maxf(rr, (_cells[nb] - hc).length() * 0.46)
	for k in 4:
		draw_circle(hc, rr + 4.0 + k * 4.0, Color(g, 0.18 - k * 0.04))
	draw_circle(hc, rr + 1.0, g)
	_text_c(hc, heard_text, maxi(int(rr * 1.05), 8), Color("#08130B") if heard_ok else Color("#1E0F02"))


# Podświetlenie odtwarzanego dźwięku – tylko nakładka 2D, bez ponownego rysowania sceny 3D.
func set_playing(p: Vector2i) -> void:
	if playing != p:
		playing = p
		queue_redraw()


func _render() -> void:
	if _vp:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# Prostokąt gryfu w obrazie 3D (bez kolumny nazw strun i wiersza numerów progów). U leworęcznych
# obraz jest odbity w poziomie, więc ten sam prostokąt trafia na ekranie na drugą stronę kolumny nazw.
func _region_3d() -> Rect2:
	return Rect2(GUTTER, _top(), size.x - GUTTER - PAD, _bottom() - _top())


# Górna i dolna krawędź pola gryfu (bez numerów progów u góry albo bez linijki u dołu).
func _top() -> float:
	return PAD + 6.0 if ruler else TOP


func _bottom() -> float:
	return size.y - PAD - (RULER_H if ruler else 0.0)


# Odbicie współrzędnej x dla leworęcznych.
func _mx(x: float) -> float:
	return size.x - x if _lefty else x


func _p3(p: Vector3) -> Vector2:
	var v := _neck.project(p) / _ss
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
	if _cells.is_empty():
		return
	_draw_range_shade()
	if ruler:
		_draw_ruler()
	_draw_heard(_heard_r)


func _font() -> Font:
	return ThemeManager.font_body_bold


func _text_c(pos: Vector2, t: String, fs: int, col: Color) -> void:
	var f := _font()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, pos + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _fret_label(pos: Vector2, n: int) -> void:
	if ruler:
		return
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
		# Środek wierzchu płaskiego krążka (wysokość 0,16 r) – tekst dokładnie na środku.
		var c := _p3(m.pos + Vector3(0, m.r * 0.16, 0))
		var edge := _p3(m.pos + Vector3(m.r, m.r * 0.16, 0))
		var r_px := absf(edge.x - c.x)
		var root: bool = m.note.get("root", false)
		var col := NeckSpec.text_color(root)
		if m.note.get("dim", false):
			col.a = 0.3
		_text_c(c, str(m.note.get("text", "")), maxi(int(r_px * (1.0 if m.note.get("dim", false) else 1.3)), 6), col)
	var r0 := absf(_p3(Vector3(spec.marker_x(1) + spec.marker_r, 0, 0)).x - _p3(Vector3(spec.marker_x(1), 0, 0)).x)
	_store_cells(func(s, f):
		var x := spec.marker_x(f)
		var xs := maxf(x, 0.0)
		return _p3(Vector3(x, spec.string_y(s, xs), spec.string_z(s, xs))), r0)


# Znaczniki w schematach: płaskie krążki z ciemną obwódką. Najpierw wszystkie krążki, potem wszystkie
# napisy – kolejne polecenia tego samego rodzaju łączą się w partie (mniej draw calli niż na przemian).
const DISC_SEGS := 28


func _disc(pts: PackedVector2Array, cols: PackedColorArray, c: Vector2, r: float, col: Color) -> void:
	var prev := c + Vector2(r, 0)
	for i in range(1, DISC_SEGS + 1):
		var a := TAU * i / DISC_SEGS
		var q := c + Vector2(cos(a), sin(a)) * r
		pts.append_array([c, prev, q])
		cols.append_array([col, col, col])
		prev = q


func _schema_notes(pos_fn: Callable, r_fn: Callable) -> void:
	var shown := []
	for n in _notes:
		if n.s >= 0 and n.s < spec.strings and n.f >= 0 and n.f <= spec.frets:
			shown.append([n, pos_fn.call(n.s, n.f), r_fn.call(n.f)])
	# Wszystkie krążki (obwódki i wypełnienia) jako jedna siatka trójkątów – jedno wywołanie.
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	# Aktywne: jasna obwódka i pełny krążek; nieaktywne: mniejsze, ciemne, bez obwódki.
	var rim := NeckSpec.rim_color()
	for m in (shown if NeckSpec.rim_visible() else []):
		var dim: bool = m[0].get("dim", false)
		_disc(pts, cols, m[1], m[2] * (0.8 if dim else 1.12) + 2.0, NeckSpec.RIM_DIM if dim else rim)
	for m in shown:
		var dim: bool = m[0].get("dim", false)
		var base := NeckSpec.note_color(m[0].get("root", false))
		_disc(pts, cols, m[1], m[2] * (0.8 if dim else 1.12), NeckSpec.dim_color(base) if dim else base)
	if not pts.is_empty():
		var idx := PackedInt32Array()
		idx.resize(pts.size())
		for i in pts.size():
			idx[i] = i
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
	for m in shown:
		var fg := NeckSpec.text_color(m[0].get("root", false))
		if m[0].get("dim", false):
			fg.a = 0.3
		_text_c(m[1], str(m[0].get("text", "")), maxi(int(m[2] * (0.9 if m[0].get("dim", false) else 1.15)), 6), fg)
	_store_cells(pos_fn, r_fn.call(1))


func _inlay_cells() -> Array:
	if spec.inlays == "none":
		return []
	return spec.inlay_frets() + spec.double_dot_frets()


# Wkładki w schematach wg ustawienia: kropki (podwójne na 12./24.), prostokąty albo trapezy.
# cx: środek pola progu f; cell: szerokość pola; yc: środek gryfu; hh: połowa wysokości wkładki;
# dbl: dwa położenia y podwójnej kropki.
func _schema_inlays(cx: Callable, cell: Callable, yc: float, hh: float, dbl: Array) -> void:
	match spec.inlays:
		"none":
			return
		"dots":
			for f in spec.inlay_frets():
				draw_circle(Vector2(cx.call(f), yc), 5.0, SCH_INLAY)
			for f in spec.double_dot_frets():
				for y in dbl:
					draw_circle(Vector2(cx.call(f), y), 5.0, SCH_INLAY)
		_:
			var waist := 0.0 if spec.inlays == "blocks" else 0.22
			for f in spec.inlay_frets():
				var c: float = cx.call(f)
				var w := minf(absf(cell.call(f)) * 0.30, 24.0)
				var n := w * (1.0 - waist)
				draw_colored_polygon(PackedVector2Array([Vector2(c - w, yc - hh), Vector2(c + w, yc - hh),
					Vector2(c + n, yc), Vector2(c + w, yc + hh), Vector2(c - w, yc + hh), Vector2(c - n, yc)]), SCH_INLAY)


# 1) Rysowana tabela – równe komórki, wiersze = struny.
func _draw_table() -> void:
	var x0 := GUTTER
	var c0 := 52.0
	var cw := (size.x - x0 - c0 - PAD) / spec.frets
	var rh := (_bottom() - _top()) / spec.strings
	var line := ThemeManager.color("border").lerp(Color("#2A3558"), 0.5)
	var y0 := _top()
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
	var top := _top() + 12.0
	var sp := (_bottom() - top - 12.0) / (spec.strings - 1)
	var h := sp * (spec.strings - 1)
	draw_rect(Rect2(_lx(x0, cw * spec.frets), top - 12, cw * spec.frets, h + 24), SCH_BOARD)
	var mid := h * 0.5
	_schema_inlays(func(f): return _mx(x0 + cw * (f - 0.5)), func(_f): return cw, top + mid, h * 0.33,
		[top + mid - sp, top + mid + sp])
	for n in range(1, spec.frets + 1):
		draw_line(Vector2(_mx(x0 + cw * n), top - 12), Vector2(_mx(x0 + cw * n), top + h + 12), SCH_FRET, 2.0)
	draw_rect(Rect2(_lx(x0 - 6, 6), top - 12, 6, h + 24), SCH_NUT)
	for s in spec.strings:
		var y := top + sp * s
		draw_line(Vector2(_mx(x0 - 40), y), Vector2(_mx(x0 + cw * spec.frets), y), SCH_STRING, _thick(s))
	# Napisy po liniach – w jednej partii.
	for n in range(1, spec.frets + 1):
		_fret_label(Vector2(_mx(x0 + cw * (n - 0.5)), top - 24), n)
	for s in spec.strings:
		_string_label(top + sp * s, s)
	var r := minf(sp * 0.36, cw * 0.4)
	_schema_notes(func(s, f): return Vector2(_mx(x0 - 26 if f == 0 else x0 + cw * (f - 0.5)), top + sp * s),
		func(_f): return r)


# 3) Kształt gryfu – płaski rysunek z prawdziwą menzurą i zwężeniem (kolory jak „kąty proste”).
func _draw_shape() -> void:
	var x0 := GUTTER + 44.0
	var xend := spec.x_end
	var k := minf((size.x - x0 - PAD) / xend, (_bottom() - _top() - 6.0) / (2.0 * spec.half_w(xend)))
	var yc := _top() + 6.0 + spec.half_w(xend) * k
	var X := func(x: float) -> float: return _mx(x0 + x * k)
	var Z := func(z: float) -> float: return yc + z * k
	draw_colored_polygon(PackedVector2Array([
		Vector2(X.call(0.0), Z.call(-spec.half_w(0.0))), Vector2(X.call(xend), Z.call(-spec.half_w(xend))),
		Vector2(X.call(xend), Z.call(spec.half_w(xend))), Vector2(X.call(0.0), Z.call(spec.half_w(0.0)))]), SCH_BOARD)
	var mid := spec.strings / 2
	var c12 := (spec.xf(11) + spec.xf(12)) * 0.5
	var dbl := []
	for s in [mid - 2, mid]:
		dbl.append(Z.call((spec.string_z(s, c12) + spec.string_z(s + 1, c12)) * 0.5))
	_schema_inlays(func(f): return X.call((spec.xf(f - 1) + spec.xf(f)) * 0.5),
		func(f): return (spec.xf(f) - spec.xf(f - 1)) * k, yc, spec.half_w(c12) * k * 0.66, dbl)
	for n in range(1, spec.frets + 1):
		var x := spec.xf(n)
		draw_line(Vector2(X.call(x), Z.call(-spec.half_w(x))), Vector2(X.call(x), Z.call(spec.half_w(x))), SCH_FRET, 2.0, true)
	var nx: float = X.call(0.0)
	draw_rect(Rect2(nx - 7 if not _lefty else nx, Z.call(-spec.half_w(0.0)), 7, spec.half_w(0.0) * 2.0 * k), SCH_NUT)
	for s in spec.strings:
		draw_line(Vector2(X.call(0.0), Z.call(spec.string_z(s, 0.0))), Vector2(X.call(xend), Z.call(spec.string_z(s, xend))),
			SCH_STRING, _thick(s), true)
	# Napisy po liniach – w jednej partii.
	for n in range(1, spec.frets + 1):
		var x := spec.xf(n)
		_fret_label(Vector2(X.call((spec.xf(n - 1) + x) * 0.5), Z.call(-spec.half_w(x)) - 12), n)
	for s in spec.strings:
		_string_label(Z.call(spec.string_z(s, 0.0)), s)
	var rpx := spec.marker_r * k
	_schema_notes(func(s, f):
			var x := spec.marker_x(f) if f > 0 else 0.0
			var px: float = X.call(x)
			if f == 0:
				px = _mx(x0 - rpx - 10.0)
			return Vector2(px, Z.call(spec.string_z(s, maxf(x, 0.0)))),
		func(f): return spec.marker_radius(f) * k if f > 0 else rpx)


# --- Zakres i linijka progów ------------------------------------------------------------
# Granice pól liczone ze środków pól (_cells), więc działają tak samo w 3D (perspektywa, zoom,
# nachylenie) i w schematach.

# Punkt na granicy pól f i f + 1 na strunie s (f = -1: lewa krawędź pustej struny).
func _edge(s: int, f: int) -> Vector2:
	var last := spec.frets
	if f < 0:
		var a: Vector2 = _cells[Vector2i(s, 0)]
		return a - (_cells[Vector2i(s, 1)] - a) * 0.5
	if f >= last:
		var b: Vector2 = _cells[Vector2i(s, last)]
		return b + (b - _cells[Vector2i(s, last - 1)]) * 0.5
	return (_cells[Vector2i(s, f)] + _cells[Vector2i(s, f + 1)]) * 0.5


# Wielokąt pól od progu a do b (włącznie) na całej szerokości gryfu.
func _span_poly(a: int, b: int) -> PackedVector2Array:
	var n := spec.strings - 1
	var up: Vector2 = (_cells[Vector2i(0, a)] - _cells[Vector2i(1, a)]) * 0.62
	var down: Vector2 = (_cells[Vector2i(n, a)] - _cells[Vector2i(n - 1, a)]) * 0.62
	var up2: Vector2 = (_cells[Vector2i(0, b)] - _cells[Vector2i(1, b)]) * 0.62
	var down2: Vector2 = (_cells[Vector2i(n, b)] - _cells[Vector2i(n - 1, b)]) * 0.62
	return PackedVector2Array([_edge(0, a - 1) + up, _edge(0, b) + up2, _edge(n, b) + down2, _edge(n, a - 1) + down])


func _draw_range_shade() -> void:
	if fret_range.x < 0:
		return
	var a := clampi(fret_range.x, 0, spec.frets)
	var b := clampi(fret_range.y, a, spec.frets)
	draw_colored_polygon(_span_poly(a, b), Color(1.0, 0.75, 0.43, 0.07))   # ciepła poświata zakresu (makieta)
	if a > 0:
		draw_colored_polygon(_span_poly(0, a - 1), SHADE)
	if b < spec.frets:
		draw_colored_polygon(_span_poly(b + 1, spec.frets), SHADE)


# Próg pod współrzędną x linijki (-1 poza gryfem).
func _ruler_fret(x: float) -> int:
	if _cells.is_empty():
		return -1
	var n := spec.strings - 1
	for f in spec.frets + 1:
		var l := _edge(n, f - 1).x
		var r := _edge(n, f).x
		if x >= minf(l, r) and x <= maxf(l, r):
			return f
	return -1


func _draw_ruler() -> void:
	var n := spec.strings - 1
	var y0 := size.y - RULER_H + 4.0
	var h := RULER_H - 10.0
	var accent := ThemeManager.color("accent")
	var inlays := [3, 5, 7, 9, 15, 17, 19, 21]   # kropki jak na boku gryfu – niezależnie od wkładek
	var doubles := [12, 24]
	_text_c(Vector2(_mx(GUTTER * 0.5), y0 + 24.0), tr("fret"), 12, ThemeManager.color("hint"))
	for f in spec.frets + 1:
		var l := _edge(n, f - 1).x
		var r := _edge(n, f).x
		var x0 := minf(l, r)
		var w := absf(r - l)
		if x0 + w < GUTTER * 0.5 or x0 > size.x:
			continue
		var on := fret_range.x >= 0 and f >= fret_range.x and f <= fret_range.y
		if on:
			draw_rect(Rect2(x0, y0, w, h), Color(accent, 0.16))
		draw_rect(Rect2(x0, y0 + h - 3.0, w, 3.0), accent if on else ThemeManager.color("border"))
		var cx := x0 + w * 0.5
		if fret_range.x >= 0 and (f == fret_range.x or f == fret_range.y):
			_triangle(Vector2(cx, y0 + 8.0), 5.0, accent)
		_text_c(Vector2(cx, y0 + 24.0), str(f), 13, accent.lightened(0.35) if on else ThemeManager.color("hint"))
		var dot := ThemeManager.color("dim")
		if f in doubles:
			draw_circle(Vector2(cx - 4.0, y0 + 38.0), 2.2, dot)
			draw_circle(Vector2(cx + 4.0, y0 + 38.0), 2.2, dot)
		elif f in inlays:
			draw_circle(Vector2(cx, y0 + 38.0), 2.2, dot)


func _triangle(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), col)
