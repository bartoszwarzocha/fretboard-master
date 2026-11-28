# Fretboard Master – Encyklopedia według zaakceptowanej makiety: u góry gryf z opisem dźwięków
# (dźwięki, interwały, stopnie, palcowanie) i zakresem progów, niżej katalog skal, arpeggiów
# i akordów z wyszukiwarką, karta wybranej pozycji (tonika, budowa, dźwięki, akordy w skali)
# oraz pięciolinia w tonacji – ze znakami przykluczowymi i pisownią literową (Theory).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends ModuleScreen

const MODES := [["names", "Pitches"], ["intervals", "Intervals"], ["degrees", "Degrees"], ["fingers", "Fingering"]]
const KINDS := [["scale", "Scales"], ["arpeggio", "Arpeggios"], ["chord", "Chords"], ["interval", "Intervals"]]
# Interwały (w obrębie oktawy) – wpisy jak akordy: dwa stopnie, nazwy w językach programu.
const INTERVALS := [
	{"id": "m2", "degrees": ["1", "b2"], "name": {"en": "minor second", "pl": "sekunda mała", "de": "kleine Sekunde", "es": "segunda menor", "ru": "малая секунда"}},
	{"id": "M2", "degrees": ["1", "2"], "name": {"en": "major second", "pl": "sekunda wielka", "de": "große Sekunde", "es": "segunda mayor", "ru": "большая секунда"}},
	{"id": "m3", "degrees": ["1", "b3"], "name": {"en": "minor third", "pl": "tercja mała", "de": "kleine Terz", "es": "tercera menor", "ru": "малая терция"}},
	{"id": "M3", "degrees": ["1", "3"], "name": {"en": "major third", "pl": "tercja wielka", "de": "große Terz", "es": "tercera mayor", "ru": "большая терция"}},
	{"id": "P4", "degrees": ["1", "4"], "name": {"en": "perfect fourth", "pl": "kwarta czysta", "de": "reine Quarte", "es": "cuarta justa", "ru": "чистая кварта"}},
	{"id": "A4", "degrees": ["1", "#4"], "name": {"en": "augmented fourth (tritone)", "pl": "kwarta zwiększona (tryton)", "de": "übermäßige Quarte (Tritonus)", "es": "cuarta aumentada (tritono)", "ru": "увеличенная кварта (тритон)"}},
	{"id": "P5", "degrees": ["1", "5"], "name": {"en": "perfect fifth", "pl": "kwinta czysta", "de": "reine Quinte", "es": "quinta justa", "ru": "чистая квинта"}},
	{"id": "m6", "degrees": ["1", "b6"], "name": {"en": "minor sixth", "pl": "seksta mała", "de": "kleine Sexte", "es": "sexta menor", "ru": "малая секста"}},
	{"id": "M6", "degrees": ["1", "6"], "name": {"en": "major sixth", "pl": "seksta wielka", "de": "große Sexte", "es": "sexta mayor", "ru": "большая секста"}},
	{"id": "m7", "degrees": ["1", "b7"], "name": {"en": "minor seventh", "pl": "septyma mała", "de": "kleine Septime", "es": "séptima menor", "ru": "малая септима"}},
	{"id": "M7", "degrees": ["1", "7"], "name": {"en": "major seventh", "pl": "septyma wielka", "de": "große Septime", "es": "séptima mayor", "ru": "большая септима"}},
	{"id": "P8", "degrees": ["1", "8"], "name": {"en": "octave", "pl": "oktawa czysta", "de": "Oktave", "es": "octava justa", "ru": "чистая октава"}},
]
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII"]
const STEP_BASE := 30          # E4 = 4·7 + 2 – dolna linia pięciolinii
const NOTE_GAP := 0.42         # s – odstęp dźwięków przy odsłuchu

var _kind := "scale"
var _entry: Dictionary = {}
var _pc := 2                   # tonika (wysokość 0–11)
var _tonic: Dictionary = {}    # tonika zapisana literowo
var _notes: Array = []         # dźwięki skali/akordu w pisowni literowej
var _degrees: Array = []
var _mode := "names"
var _from := 5
var _to := 9
var _query := ""
var _variants: Array = []     # superpozycje w zakresie (Superposition) – od najwygodniejszej
var _variant := 0
var _style := ""              # "3nps" po gotowym zakresie „3 dźwięki na strunę”
var _shapes := false          # superpozycje włączone (przełącznik) – warianty, przesunięcia ręki
var _octaves := true          # superpozycje tylko w pełnych oktawach (od toniki do toniki)
var _barre := true            # chwyty akordów: belka barré na gryfie
var _hear_timer: Timer
# Fragmenty interfejsu wskazywane w samouczku.
var _catalog_card: Control
var _tonic_row: Control
var _listen_btn: Control
var _big := false               # tryb „Duży gryf”: panel gryfu na całą wysokość, dół zwinięty do paska
var _big_btn: Button
var _bottom: Control
var _morph: LayoutMorph
var _detail_card: Control
var _need := {false: 0.0, true: 0.0}
var _fit_tween: Tween
var _fitted := false   # wysokość rzędu potrzebna treści karty (zwykły / duży gryf)
var _staff_holder: Control      # pięciolinia w obudowie z przycięciem – szerokość animowana do zera
var _staff_box: Control
var _range_box: Control
var _tutorial: TutorialOverlay
var _tracker := PitchTracker.new()   # bramka, pominięcie ataku, histereza, wygładzanie odczytu

var _fb: FretboardView
var _title: Label
var _range_text: Label
var _modes_box: HBoxContainer
var _variants_box: HBoxContainer
var _shapes_box: HBoxContainer
var _from_label: Label
var _to_label: Label
var _search: LineEdit
var _kinds_box: HBoxContainer
var _list: ItemList
var _detail: VBoxContainer
var _staff: StaffView
var _clef: OptionButton

var _play_seq: Array = []      # [[midi…], indeks nuty na pięciolinii]
var _play_i := 0
var _play_timer: Timer


func _init() -> void:
	module_id = &"encyclopedia"
	content_margin = Vector2(32, 20)
	help = _start_tutorial


func _build_content() -> void:
	content.add_theme_constant_override("separation", 18)
	_load_state()
	_play_timer = Timer.new()
	_play_timer.one_shot = false
	_play_timer.wait_time = NOTE_GAP
	_play_timer.timeout.connect(_play_step)
	add_child(_play_timer)
	# Granie na gitarze: odczyt wysokości z wejścia audio (rdzeń tunera) co 40 ms – Timer zamiast _process.
	_hear_timer = Timer.new()
	_hear_timer.wait_time = HEAR_POLL
	_hear_timer.timeout.connect(_hear)
	add_child(_hear_timer)
	# Otwarcie urządzenia audio po pokazaniu ekranu – bez przestoju przy wejściu do Encyklopedii.
	get_tree().create_timer(0.25).timeout.connect(_open_input)

	# --- Gryf ---
	var neck_card := PanelContainer.new()
	neck_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var nb := ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("border"), 18)
	nb.content_margin_left = 22
	nb.content_margin_right = 22
	neck_card.add_theme_stylebox_override("panel", nb)
	content.add_child(neck_card)
	var neck_col := VBoxContainer.new()
	neck_col.add_theme_constant_override("separation", 8)
	neck_card.add_child(neck_col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	neck_col.add_child(head)
	_title = _label("", 26, ThemeManager.color("text"), ThemeManager.font_heading)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.add_child(_title)
	_range_text = _label("", 15, ThemeManager.color("muted"))
	_range_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_range_text.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_range_text)
	head.add_child(_spacer())
	_shapes_box = HBoxContainer.new()
	head.add_child(_shapes_box)
	_variants_box = HBoxContainer.new()
	_variants_box.add_theme_constant_override("separation", 8)
	# Stała szerokość – przełączniki obok nie zmieniają miejsca przy innej liczbie wariantów.
	_variants_box.custom_minimum_size.x = 400
	head.add_child(_variants_box)
	var g := Control.new()
	g.custom_minimum_size.x = 10
	head.add_child(g)
	_modes_box = HBoxContainer.new()
	head.add_child(_modes_box)
	# Przełącznik „Duży gryf” – ikona pełnego ekranu w rogu panelu gryfu.
	_big_btn = _chip_button("", false)
	_big_btn.custom_minimum_size = Vector2(42, 38)
	_big_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_big_btn.add_theme_constant_override("icon_max_width", int(ICON))
	_big_btn.expand_icon = false
	_big_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_btn.pressed.connect(func(): _set_big(not _big))
	head.add_child(_big_btn)

	_fb = FretboardView.new()
	_fb.interactive = true
	_fb.ruler = true
	_fb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fb.custom_minimum_size.y = 250
	_fb.note_picked.connect(_on_note_picked)
	_fb.fret_clicked.connect(_on_fret_clicked)
	neck_col.add_child(_fb)
	_range_box = _range_row()
	neck_col.add_child(_range_box)

	# --- Katalog, karta, pięciolinia ---
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 18)
	bottom.custom_minimum_size.y = 430
	content.add_child(bottom)
	_bottom = bottom
	_catalog_card = _catalog()
	bottom.add_child(_catalog_card)
	# Karta i pięciolinia w jednym rzędzie bez odstępu – odstęp jest w obudowie pięciolinii, więc przy
	# jej zwijaniu karta rośnie płynnie aż do krawędzi.
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(right)
	var card := _card(22)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(card)
	_detail_card = card
	card.resized.connect(func() -> void: _fit_bottom())
	# Treść karty w obudowie z przycięciem: jej wysokość nie blokuje animacji rzędu.
	var clip := Control.new()
	clip.clip_contents = true
	card.add_child(clip)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 12)
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_child(_detail)
	_staff_holder = Control.new()
	_staff_holder.clip_contents = true
	_staff_holder.custom_minimum_size.x = STAFF_W + 18.0
	right.add_child(_staff_holder)
	_staff_box = _staff_card()
	_staff_holder.add_child(_staff_box)
	_staff_box.anchor_bottom = 1.0
	_staff_box.offset_left = 18.0
	_staff_box.offset_right = 18.0 + STAFF_W

	_big = bool(App.setting(&"enc_big_neck"))
	_refresh_all()
	_apply_big(false)
	if "--morph-test" in OS.get_cmdline_user_args():
		_morph_test()


func _exit_tree() -> void:
	if _play_timer:
		_play_timer.stop()
	if _hear_timer:
		_hear_timer.stop()


# --- Stan ----------------------------------------------------------------------------

func _load_state() -> void:
	_kind = str(App.setting(&"enc_kind"))
	_pc = posmod(int(App.setting(&"enc_tonic")), 12)
	_mode = str(App.setting(&"enc_mode"))
	_from = int(App.setting(&"enc_from"))
	_to = int(App.setting(&"enc_to"))
	_shapes = bool(App.setting(&"enc_shapes"))
	_octaves = bool(App.setting(&"enc_octaves"))
	_barre = bool(App.setting(&"enc_barre"))
	_entry = _entry_for_kind(_kind)


func _entry_for_kind(kind: String) -> Dictionary:
	if kind == "interval":
		return _interval(str(App.setting(&"enc_interval")))
	if kind == "scale":
		var e := Theory.scale(str(App.setting(&"enc_scale")))
		return e if not e.is_empty() else Theory.scales()[0]
	var c := Theory.chord(str(App.setting(&"enc_chord")))
	if c.is_empty() or (kind == "arpeggio" and not c.get("arpeggio", false)):
		for x in Theory.chords():
			if kind == "chord" or x.get("arpeggio", false):
				return x
	return c


func _save_state() -> void:
	var v := {&"enc_kind": _kind, &"enc_tonic": _pc, &"enc_mode": _mode, &"enc_from": _from, &"enc_to": _to}
	v[{"scale": &"enc_scale", "interval": &"enc_interval"}.get(_kind, &"enc_chord")] = str(_entry.id)
	App.set_settings(v)


func _select(kind: String, entry: Dictionary, pc := -1) -> void:
	_kind = kind
	_entry = entry
	if pc >= 0:
		_pc = pc
	_variant = 0
	_save_state()
	_stop_playing()
	_refresh_all()


# Pisownia toniki i dźwięków bieżącej pozycji.
func _interval(id: String) -> Dictionary:
	for e in INTERVALS:
		if e.id == id:
			return e
	return INTERVALS[2]


# Interwał: miejsca na gryfie w zakresie – pryma i drugi dźwięk na tej samej albo wyższej strunie,
# w zasięgu ręki (≤ 4 progi); od najniższej prymy, najwyżej 8.
func _interval_pairs(spec: NeckSpec) -> Array:
	var semis: int = Theory.parse_degree(str(_degrees[1]))[2]
	var out := []
	for s1 in range(spec.strings - 1, -1, -1):
		for f1 in range(_from, _to + 1):
			var m1: int = spec.open_midi[s1] + f1
			if posmod(m1, 12) != _pc:
				continue
			for s2 in range(s1, -1, -1):
				var f2: int = m1 + semis - spec.open_midi[s2]
				if f2 < _from or f2 > _to or (s2 == s1 and semis == 0):
					continue
				if f1 > 0 and f2 > 0 and absi(f2 - f1) > 4:
					continue
				out.append([m1, s1, [{"s": s1, "f": f1, "midi": m1, "pos": 0}, {"s": s2, "f": f2, "midi": m1 + semis, "pos": 0}]])
	out.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] > b[1]))
	var v := []
	for x in out.slice(0, 8):
		v.append(x[2])
	return v


func _compute() -> void:
	_degrees = _entry.get("degrees", [])
	_tonic = Theory.best_tonic(_pc, _entry) if _kind == "scale" else Theory.best_root(_pc, _entry)
	_notes = Theory.spell_all(_tonic, _degrees)


func _refresh_all() -> void:
	_compute()
	_build_modes()
	_build_kinds()
	_fill_list()
	_build_detail()
	_update_neck()


# --- Gryf ----------------------------------------------------------------------------

func _update_neck() -> void:
	var spec := _fb.spec
	if spec == null:
		return
	_from = clampi(_from, 0, spec.frets)
	_to = clampi(_to, _from, spec.frets)
	_fb.set_range(_from, _to)
	var by_pc := {}
	for i in _notes.size():
		var p := Theory.pc(_notes[i])
		if not by_pc.has(p):
			by_pc[p] = i
	# Superpozycje w zakresie (akordy – chwyty na całym gryfie, od najniższej pozycji); dźwięki skali
	# w zakresie spoza wybranego wariantu – przyciemnione.
	var shape := {}
	if _shapes and _kind == "chord":
		var fifth := -1
		for i in _degrees.size():
			if str(_degrees[i]) == "5":
				fifth = Theory.pc(_notes[i])
		var chord_shapes := ChordShapes.shapes(spec.open_midi, spec.frets, by_pc, _pc, fifth)
		_variant = clampi(_variant, 0, maxi(chord_shapes.size() - 1, 0))
		_variants = []
		for sh in chord_shapes:
			var v := []
			for c in sh.cells:
				v.append({"s": c.s, "f": c.f, "midi": c.midi, "pos": 0, "finger": c.finger})
			_variants.append(v)
		if not chord_shapes.is_empty():
			shape = chord_shapes[_variant]
			# Zakres – pozycja ręki chwytu (przy siodełku: progi 0–4).
			var lo: int = shape.fret
			_from = lo
			_to = mini(lo + 4 if lo == 0 else lo + ChordShapes.SPAN, spec.frets)
			_fb.set_range(_from, _to)
	elif _kind == "interval":
		_variants = _interval_pairs(spec) if _shapes else []
	else:
		_variants = Superposition.variants(spec.open_midi, by_pc, _from, _to, _style,
				_pc if _octaves else -1) if _shapes else []
	_variant = clampi(_variant, 0, maxi(_variants.size() - 1, 0))
	_fb.set_barre(shape.get("barre", {}) if _barre else {})
	# Wariant: komórki, pozycje ręki (najniższy próg z palcem w każdej pozycji) i przesunięcia ręki.
	var chosen := {}
	var fingers := {}             # chwyty akordów – palce z ułożenia ręki
	var hands := {}
	var shifts := []
	if not _variants.is_empty():
		var v: Array = _variants[_variant]
		for i in v.size():
			var n: Dictionary = v[i]
			chosen[Vector2i(n.s, n.f)] = n.pos
			if n.has("finger"):
				fingers[Vector2i(n.s, n.f)] = n.finger
			if n.f > 0:
				hands[n.pos] = mini(hands.get(n.pos, 99), n.f)
			if i > 0 and n.pos != v[i - 1].pos:
				shifts.append([Vector2i(v[i - 1].s, v[i - 1].f), Vector2i(n.s, n.f)])
	_fb.set_shifts(shifts)
	var out := []
	for s in spec.strings:
		for f in spec.frets + 1:
			var p := posmod(spec.open_midi[s] + f, 12)
			if not by_pc.has(p):
				continue
			var i: int = by_pc[p]
			var in_range := f >= _from and f <= _to
			var in_var := chosen.has(Vector2i(s, f)) or (chosen.is_empty() and in_range)
			var text := ""
			match _mode:
				"names": text = Theory.note_name(_notes[i], App.notation())
				"intervals": text = _degree_label(str(_degrees[i]))
				"degrees": text = ROMAN[(Theory.parse_degree(str(_degrees[i]))[0] - 1) % 7]
				"fingers":
					if in_var:
						var h: int = hands.get(chosen.get(Vector2i(s, f), -1), maxi(_from, 1))
						text = "0" if f == 0 else str(fingers.get(Vector2i(s, f), clampi(f - h + 1, 1, 4)))
			out.append({"s": s, "f": f, "text": text, "root": i == 0, "dim": in_range and not in_var})
	# Struny wytłumione w chwycie – „×” przy siodełku.
	for ms in shape.get("muted", []):
		var found := false
		for n in out:
			if n.s == ms and n.f == 0:
				n.text = "×"
				n.dim = true
				n.root = false
				found = true
		if not found:
			out.append({"s": ms, "f": 0, "text": "×", "root": false, "dim": true})
	_fb.set_notes(out)
	_title.text = _title_text()
	_range_text.text = tr("practice range: frets %d–%d, all strings") % [_from, _to]
	if _from_label:
		_from_label.text = str(_from)
		_to_label.text = str(_to)
	_build_shapes()
	_build_variants()
	_stop_playing()
	_update_staff()


# Przełącznik superpozycji: włączenie od razu zawęża zakres do jednej pozycji (5 progów).
func _build_shapes() -> void:
	_clear(_shapes_box)
	var b := _chip_button(tr({"chord": "Chord shapes", "interval": "Positions"}.get(_kind, "Scale shapes")), _shapes)
	b.custom_minimum_size.y = 38
	b.pressed.connect(func():
		_shapes = not _shapes
		App.set_setting(&"enc_shapes", _shapes)
		if _shapes and _kind != "chord" and _kind != "interval":
			_preset(4, "")
		else:
			_style = ""
			_update_neck())
	_shapes_box.add_child(b)
	if _shapes and _kind == "chord":
		var bb := _chip_button(tr("Barre"), _barre)
		bb.custom_minimum_size.y = 38
		bb.pressed.connect(func():
			_barre = not _barre
			App.set_setting(&"enc_barre", _barre)
			_update_neck())
		_shapes_box.add_child(bb)
	elif _shapes and _kind != "interval":
		var o := _chip_button(tr("Full octaves"), _octaves)
		o.custom_minimum_size.y = 38
		o.pressed.connect(func():
			_octaves = not _octaves
			App.set_setting(&"enc_octaves", _octaves)
			_variant = 0
			_update_neck())
		_shapes_box.add_child(o)


func _build_variants() -> void:
	_clear(_variants_box)
	if _variants.is_empty():
		return
	_variants_box.add_child(_small_label("Variants:" if _kind in ["scale", "arpeggio"] else "Positions:"))
	var items := []
	for i in _variants.size():
		items.append([str(i), str(i + 1)])
	_variants_box.add_child(_segmented(items, str(_variant), func(v):
		_variant = int(v)
		_update_neck()))


func _set_range(a: int, b: int) -> void:
	var last := _fb.spec.frets if _fb.spec else 24
	_from = clampi(a, 0, last)
	_to = clampi(b, _from, last)
	_variant = 0
	App.set_settings({&"enc_from": _from, &"enc_to": _to})
	_update_neck()


func _on_fret_clicked(f: int) -> void:
	_style = ""
	if absi(f - _from) <= absi(f - _to):
		_set_range(mini(f, _to), _to)
	else:
		_set_range(_from, maxi(f, _from))


func _on_note_picked(s: int, f: int) -> void:
	var c := AudioEngine.ensure_open()
	if c:
		c.play_note(Instrument.midi_program(), _fb.spec.open_midi[s] + f, 0.85, 1.4)


func _range_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lead := Control.new()
	lead.custom_minimum_size.x = FretboardView.GUTTER - 10
	row.add_child(lead)
	row.add_child(_small_label("From fret"))
	row.add_child(_arrow_button(-1, func(): _manual_range(_from - 1, _to)))
	_from_label = _value_label()
	row.add_child(_from_label)
	row.add_child(_arrow_button(1, func(): _manual_range(mini(_from + 1, _to), _to)))
	var g := Control.new()
	g.custom_minimum_size.x = 14
	row.add_child(g)
	row.add_child(_small_label("To fret"))
	row.add_child(_arrow_button(-1, func(): _manual_range(_from, maxi(_to - 1, _from))))
	_to_label = _value_label()
	row.add_child(_to_label)
	row.add_child(_arrow_button(1, func(): _manual_range(_from, _to + 1)))
	var g2 := Control.new()
	g2.custom_minimum_size.x = 14
	row.add_child(g2)
	var sl := _pill_button(tr("shift range"), _shift.bind(-1), 8)
	sl.icon = _triangle_icon(-1, ThemeManager.color("text"))
	row.add_child(sl)
	var sr := _pill_button(tr("shift range"), _shift.bind(1), 8)
	sr.icon = _triangle_icon(1, ThemeManager.color("text"))
	sr.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(sr)
	row.add_child(_spacer())
	row.add_child(_small_label("Preset ranges:"))
	row.add_child(_pill_button(tr("Position"), func(): _preset(4, "")))
	row.add_child(_pill_button(tr("CAGED"), func(): _preset(3, "")))
	row.add_child(_pill_button(tr("3 notes per string"), func(): _preset(6, "3nps", true)))
	row.add_child(_pill_button(tr("Three octaves"), _three_octaves))
	row.add_child(_pill_button(tr("Whole neck"), func(): _manual_range(0, _fb.spec.frets)))
	return row


func _shift(d: int) -> void:
	if _from + d >= 0 and _to + d <= _fb.spec.frets:
		_set_range(_from + d, _to + d)


# Gotowe zakresy jak w makiecie: od progu przed toniką na najniższej strunie, o zadanej szerokości.
func _manual_range(a: int, b: int) -> void:
	_style = ""
	_set_range(a, b)


func _preset(width: int, style: String, shapes := false) -> void:
	_style = style
	_enable_shapes(shapes)
	var spec := _fb.spec
	var e := posmod(_pc - spec.open_midi[spec.strings - 1], 12)
	var a := maxi(e - 1, 0)
	_set_range(a, a + width)


# Trzy oktawy od toniki na najniższej strunie: progi od toniki do toniki + 12, z przesunięciami ręki.
func _three_octaves() -> void:
	_style = ""
	_enable_shapes(true)
	var spec := _fb.spec
	var e := posmod(_pc - spec.open_midi[spec.strings - 1], 12)
	_set_range(e, e + 12)


func _enable_shapes(on: bool) -> void:
	if on and not _shapes:
		_shapes = true
		App.set_setting(&"enc_shapes", true)


# --- Opis dźwięków na gryfie --------------------------------------------------------

func _build_modes() -> void:
	_clear(_modes_box)
	var items := []
	for m in MODES:
		items.append([m[0], tr(m[1])])
	_modes_box.add_child(_segmented(items, _mode, func(v):
		_mode = v
		App.set_setting(&"enc_mode", _mode)
		_build_modes()
		_update_neck()))


# --- Katalog -------------------------------------------------------------------------

func _catalog() -> Control:
	var card := _card(16)
	card.custom_minimum_size.x = 300
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	col.add_child(_small_label("Search for a scale, chord or notes"))
	_search = LineEdit.new()
	_search.placeholder_text = tr("e.g. Dorian or C E G B")
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(t: String):
		_query = t.strip_edges()
		_build_kinds()
		_fill_list())
	col.add_child(_search)
	_kinds_box = HBoxContainer.new()
	col.add_child(_kinds_box)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.focus_mode = Control.FOCUS_NONE
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Zaznaczenie – cały wiersz tłem w kolorze akcentu (bez paska z lewej, który zasłaniał nazwę).
	var sel := ThemeManager.box(Color(ThemeManager.color("accent"), 0.24), Color(ThemeManager.color("accent"), 0.55), 8, 1, 10, 4)
	for k in ["selected", "selected_focus"]:
		_list.add_theme_stylebox_override(k, sel)
	_list.add_theme_stylebox_override("hovered", ThemeManager.box(ThemeManager.color("surface_2"), Color.TRANSPARENT, 8, 0, 10, 4))
	_list.add_theme_stylebox_override("hovered_selected", sel)
	_list.add_theme_stylebox_override("hovered_selected_focus", sel)
	_list.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	_list.add_theme_color_override("font_color", ThemeManager.color("muted"))
	_list.add_theme_color_override("font_hovered_color", ThemeManager.color("text"))
	_list.add_theme_color_override("font_selected_color", ThemeManager.color("text"))
	_list.add_theme_color_override("font_hovered_selected_color", ThemeManager.color("text"))
	_list.add_theme_font_size_override("font_size", ThemeManager.fs(16))
	_list.add_theme_constant_override("v_separation", 6)
	_list.add_theme_color_override("guide_color", Color.TRANSPARENT)
	_list.item_selected.connect(_on_item)
	col.add_child(_list)
	return card


func _build_kinds() -> void:
	_clear(_kinds_box)
	if not _query.is_empty():
		return
	var items := []
	for k in KINDS:
		items.append([k[0], tr(k[1])])
	var seg := _segmented(items, _kind, func(v):
		_select(v, _entry_for_kind(v)))
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kinds_box.add_child(seg)


# Lista: kategorie (nagłówki – nie do wybrania) i pozycje; przy wyszukiwaniu – wyniki.
func _fill_list() -> void:
	_list.clear()
	var selected := -1
	if _query.is_empty():
		var is_scale := _kind == "scale"
		if _kind == "interval":
			_header(tr("Intervals").to_upper())
			for e in INTERVALS:
				var i := _list.add_item(Theory.local_name(e))
				_list.set_item_metadata(i, {"kind": "interval", "id": e.id, "pc": -1})
				if e.id == _entry.get("id"):
					selected = i
			if selected >= 0:
				_list.select(selected)
			return
		var cats: Array = Theory.data().get("scale_categories" if is_scale else "chord_categories", [])
		var entries: Array = Theory.scales() if is_scale else Theory.chords()
		for cat in cats:
			var rows := entries.filter(func(e): return e.cat == cat.id and (_kind != "arpeggio" or e.get("arpeggio", false)))
			if rows.is_empty():
				continue
			_header(Theory.local_name(cat).to_upper())
			for e in rows:
				var i := _list.add_item(_entry_label(e, -1))
				_list.set_item_metadata(i, {"kind": _kind, "id": e.id, "pc": -1})
				if e.id == _entry.get("id") :
					selected = i
	else:
		for r in _search_results(_query):
			if r.has("header"):
				_header(r.header)
				continue
			var i := _list.add_item(r.label)
			_list.set_item_metadata(i, r)
			if r.kind == _kind and r.id == _entry.get("id") and (r.pc < 0 or r.pc == _pc):
				selected = i
		if _list.item_count == 0:
			_header(tr("Nothing found"))
	if selected >= 0:
		_list.select(selected)
		_list.ensure_current_is_visible()


func _header(text: String) -> void:
	var i := _list.add_item(text, null, false)
	_list.set_item_disabled(i, true)
	_list.set_item_custom_fg_color(i, ThemeManager.color("hint"))
	_list.set_item_tooltip_enabled(i, false)


func _entry_label(e: Dictionary, root_pc: int) -> String:
	var name := Theory.local_name(e)
	if e.has("symbol"):
		var sym := str(e.symbol)
		if root_pc >= 0:
			var r := Theory.best_root(root_pc, e)
			return Theory.note_name(r, App.notation()) + sym + "  ·  " + name
		return name if sym.is_empty() else sym + "  ·  " + name
	if root_pc >= 0:
		return Theory.note_name(Theory.best_tonic(root_pc, e), App.notation()) + "  ·  " + name
	return name


func _on_item(i: int) -> void:
	var m = _list.get_item_metadata(i)
	if m == null:
		return
	var kind: String = m.kind
	var e := Theory.scale(m.id) if kind == "scale" else (_interval(m.id) if kind == "interval" else Theory.chord(m.id))
	if e.is_empty():
		return
	_select(kind, e, int(m.pc))


# --- Wyszukiwanie ----------------------------------------------------------------------
# Nazwa (we wszystkich językach i synonimach) albo dźwięki: „C E G B” – akordy o dokładnie tych
# dźwiękach (od każdej z podanych podstaw) i skale od pierwszego dźwięku, które je zawierają.

func _search_results(q: String) -> Array:
	var out := []
	var pcs := _parse_notes(q)
	if pcs.size() >= 2:
		var set_q := {}
		for p in pcs:
			set_q[p] = true
		var chords := []
		for c in Theory.chords():
			for root in pcs:
				if _pc_set(root, c.degrees) == _sorted_keys(set_q):
					chords.append({"kind": "chord", "id": c.id, "pc": root, "label": _entry_label(c, root)})
		var scales := []
		for s in Theory.scales():
			var have := _pc_set(pcs[0], s.degrees)
			if pcs.all(func(p): return p in have):
				scales.append({"kind": "scale", "id": s.id, "pc": pcs[0], "label": _entry_label(s, pcs[0])})
		if not chords.is_empty():
			out.append({"header": tr("Chords").to_upper()})
			out.append_array(chords)
		if not scales.is_empty():
			out.append({"header": tr("Scales").to_upper()})
			out.append_array(scales)
		return out
	var needle := _norm(q)
	var scales := []
	for s in Theory.scales():
		if _matches(s, needle):
			scales.append({"kind": "scale", "id": s.id, "pc": -1, "label": _entry_label(s, -1)})
	var chords := []
	for c in Theory.chords():
		if _matches(c, needle):
			chords.append({"kind": "chord", "id": c.id, "pc": -1, "label": _entry_label(c, -1)})
	if not scales.is_empty():
		out.append({"header": tr("Scales").to_upper()})
		out.append_array(scales)
	if not chords.is_empty():
		out.append({"header": tr("Chords").to_upper()})
		out.append_array(chords)
	return out


func _norm(t: String) -> String:
	return t.to_lower().replace("♭", "b").replace("♯", "#").replace("♮", "").strip_edges()


func _matches(e: Dictionary, needle: String) -> bool:
	var hay := [Theory.local_name(e, "en")]
	for lang in ["pl", "de", "es", "ru"]:
		hay.append(Theory.local_name(e, lang))
	for a in e.get("aliases", []):
		for lang in ["en", "pl", "de", "es", "ru"]:
			hay.append(Theory.local_name(a, lang))
	for h in hay:
		if _norm(str(h)).contains(needle):
			return true
	return e.has("symbol") and _norm(str(e.symbol)) == needle


func _pc_set(root: int, degrees: Array) -> Array:
	var d := {}
	for deg in degrees:
		d[posmod(root + Theory.parse_degree(str(deg))[2], 12)] = true
	return _sorted_keys(d)


func _sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


# Dźwięki z zapytania w każdym zapisie: C, C#, Cis, Db, Des, H, B (w zapisie niemieckim B = B♭), Do Re Mi…
func _parse_notes(q: String) -> Array:
	var out := []
	for tok in q.replace(",", " ").split(" ", false):
		var p := _parse_note(_norm(tok))
		if p < 0:
			return []
		if not p in out:
			out.append(p)
	return out


func _parse_note(t: String) -> int:
	const SOLF := {"do": 0, "re": 2, "mi": 4, "fa": 5, "sol": 7, "la": 9, "si": 11}
	var base := -1
	var rest := ""
	for k in ["sol", "do", "re", "mi", "fa", "la", "si"]:
		if t.begins_with(k):
			base = SOLF[k]
			rest = t.substr(k.length())
			break
	if base < 0:
		if t.is_empty():
			return -1
		var letters := {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "h": 11,
				"b": 10 if App.notation() == NoteNames.GERMAN else 11}
		if not letters.has(t[0]):
			return -1
		base = letters[t[0]]
		rest = t.substr(1)
		if t[0] in ["e", "a"] and rest.begins_with("s") and not rest.begins_with("sharp"):
			rest = "es" + rest.substr(1)   # Es, As
	var acc := 0
	while not rest.is_empty():
		if rest.begins_with("is"):
			acc += 1
			rest = rest.substr(2)
		elif rest.begins_with("es"):
			acc -= 1
			rest = rest.substr(2)
		elif rest[0] == "#":
			acc += 1
			rest = rest.substr(1)
		elif rest[0] == "b":
			acc -= 1
			rest = rest.substr(1)
		else:
			return -1
	return posmod(base + acc, 12)


# --- Karta pozycji -------------------------------------------------------------------

func _build_detail() -> void:
	_clear(_detail)
	_fit_bottom.call_deferred()
	# Tryb „Duży gryf”: karta w dwóch kolumnach (tonika, nazwa, przyciski | budowa, dźwięki, akordy),
	# bez opisu rodziny i listy ćwiczeń – niska, na szerokość po pięciolinii.
	var left: Control = _detail
	var right: Control = _detail
	if _big:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 28)
		_detail.add_child(cols)
		left = VBoxContainer.new()
		left.add_theme_constant_override("separation", 12)
		cols.add_child(left)
		right = VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(right)
	# Tonika – przyciski jak w makiecie (zapis z jednym znakiem; właściwa pisownia w tytule).
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 5)
	left.add_child(trow)
	_tonic_row = trow
	var tl := _small_label("Tonic" if _kind == "scale" else "Root")
	tl.custom_minimum_size.x = 80
	trow.add_child(tl)
	for p in 12:
		var t := {"l": 0, "a": 0}
		for sp in Theory.spellings_of(p):
			if sp.a == Theory.PREFERRED_ACC[p]:
				t = sp
		var b := _chip_button(Theory.note_name(t, App.notation()), p == _pc)
		b.custom_minimum_size = Vector2(44, 38)
		b.pressed.connect(func(): _select(_kind, _entry, p))
		trow.add_child(b)

	var title := _label(_title_text(), 30, ThemeManager.color("text"), ThemeManager.font_heading)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	left.add_child(title)
	var fam := _label(_family_text(), 15, ThemeManager.color("muted"))
	fam.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	fam.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _big:
		_detail.add_child(fam)
	else:
		fam.queue_free()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	right.add_child(grid)
	var l1 := _small_label("Formula")
	l1.custom_minimum_size.x = 120
	grid.add_child(l1)
	var frow := _flow()
	for i in _degrees.size():
		frow.add_child(_tag(_degree_label(str(_degrees[i])), i == 0, true))
	grid.add_child(frow)
	grid.add_child(_small_label("Pitches"))
	var nrow := _flow()
	for i in _notes.size():
		nrow.add_child(_tag(Theory.note_name(_notes[i], App.notation()), i == 0, false))
	grid.add_child(nrow)
	var chords := _scale_chords()
	if not chords.is_empty():
		grid.add_child(_small_label("Chords in the scale"))
		var crow := _flow()
		for c in chords:
			crow.add_child(_chord_chip(c))
		grid.add_child(crow)

	if not _big:
		var fill := Control.new()
		fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail.add_child(fill)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	left.add_child(actions)
	var practise_text: String = {"scale": "Practise this scale", "arpeggio": "Practise this arpeggio",
			"chord": "Practise this chord", "interval": "Practise this interval"}[_kind]
	var practise := Button.new()
	practise.theme_type_variation = &"AccentButton"
	practise.text = tr(practise_text)
	practise.icon = _triangle_icon(1, ThemeManager.color("accent_text"))
	practise.add_theme_constant_override("h_separation", 10)
	practise.custom_minimum_size.y = 50
	practise.disabled = true
	var dim_accent := Color(ThemeManager.color("accent"), 0.45)
	practise.add_theme_stylebox_override("disabled", ThemeManager.box(dim_accent))
	practise.add_theme_color_override("font_disabled_color", Color(ThemeManager.color("accent_text"), 0.75))
	practise.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.75))
	practise.tooltip_text = tr("Available with the Exercises module.")
	actions.add_child(practise)
	var listen := _action_button("Listen")
	listen.pressed.connect(_listen)
	_listen_btn = listen
	actions.add_child(listen)
	var plan := _action_button("+ Add to plan")
	plan.disabled = true
	plan.tooltip_text = tr("Available with the Practice plan module.")
	actions.add_child(plan)

	if _big:
		return
	var trow2 := _flow()
	trow2.add_child(_small_label({"scale": "Exercises for this scale:", "interval": "Exercises for this interval:"}.get(_kind, "Exercises for this chord:")))
	var names: Array = ["Scale in range", "Sequences", "Find the note", "Intervals on the neck", "Note reading"] \
			if _kind == "scale" else (["Intervals on the neck", "Find the note", "Note reading"] if _kind == "interval" \
			else ["Arpeggio in range", "Recognise the chord", "Find the note", "Note reading"])
	for n in names:
		trow2.add_child(_trainer_chip(tr(n)))
	_detail.add_child(trow2)


func _title_text() -> String:
	var t := Theory.note_name(_tonic, App.notation())
	if _kind == "interval":
		return t + " – " + Theory.local_name(_entry)
	if _kind != "scale":
		return t + str(_entry.get("symbol", ""))
	var name := Theory.local_name(_entry)
	match TranslationServer.get_locale().substr(0, 2):
		"pl":
			return t + " – " + (name if name.begins_with("pentatonika") or name.begins_with("heksatonika") else "skala " + name)
		"es":
			return t + " – " + (name if name.begins_with("pentatónica") or name.begins_with("hexatónica") else "escala " + name)
		"ru":
			return t + " – " + name
		_:
			return t + " " + name


func _family_text() -> String:
	var parts := PackedStringArray()
	var n := _notes.size()
	if _kind == "interval":
		var st: int = Theory.parse_degree(str(_degrees[1]))[2]
		if st == 1:
			return tr("1 semitone")
		return (tr("%d semitones (2–4)") if st % 10 in [2, 3, 4] and not st in [12, 13, 14] else tr("%d semitones")) % st
	if _kind == "scale":
		parts.append(Theory.local_name(_category(_entry, "scale_categories")))
	else:
		parts.append(tr("%s chord") % Theory.local_name(_entry))
		if _kind == "arpeggio":
			parts.append(tr("arpeggio"))
	parts.append((tr("%d notes (2–4)") if n % 10 in [2, 3, 4] and not n in [12, 13, 14] else tr("%d notes")) % n)
	var aliases: Array = _entry.get("aliases", [])
	if not aliases.is_empty():
		var a := PackedStringArray()
		for x in aliases:
			a.append(Theory.local_name(x))
		parts.append(tr("also: %s") % ", ".join(a))
	return "  ·  ".join(parts)


func _category(e: Dictionary, key: String) -> Dictionary:
	for c in Theory.data().get(key, []):
		if c.id == e.get("cat"):
			return c
	return {}


# Akordy czterodźwiękowe na stopniach skali siedmiodźwiękowej (tercjami), z funkcją: ♭III maj7 itd.
func _scale_chords() -> Array:
	if _kind != "scale" or _notes.size() != 7:
		return []
	var by_set := {}
	for size in [4, 3]:
		for c in Theory.chords():
			var d: Array = c.degrees
			if d.size() != size:
				continue
			var k := str(_pc_set(0, d))
			if not by_set.has(k):
				by_set[k] = c
	var out := []
	for i in 7:
		var root: Dictionary = _notes[i]
		var rp := Theory.pc(root)
		var set4 := {}
		var set3 := {}
		for j in 4:
			var p := posmod(Theory.pc(_notes[(i + 2 * j) % 7]) - rp, 12)
			set4[p] = true
			if j < 3:
				set3[p] = true
		var c: Dictionary = by_set.get(str(_sorted_keys(set4)), by_set.get(str(_sorted_keys(set3)), {}))
		var deg := Theory.parse_degree(str(_degrees[i]))
		var acc := "♭".repeat(-deg[1]) if deg[1] < 0 else "♯".repeat(deg[1])
		var sym := str(c.get("symbol", "?"))
		out.append({"roman": acc + ROMAN[i] + sym, "name": Theory.note_name(root, App.notation()) + sym,
				"chord": c, "pc": rp})
	return out


func _chord_chip(c: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(66, 56)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, ThemeManager.box(ThemeManager.color("surface_2") if st == "normal" else ThemeManager.color("border"),
				ThemeManager.color("border_strong"), 10, 1, 8, 4))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var r := _label(c.roman, 12, ThemeManager.color("hint"), ThemeManager.font_body_bold)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(r)
	var n := _label(c.name, 17, ThemeManager.color("text"), ThemeManager.font_body_bold)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(n)
	var w := maxf(ThemeManager.font_body_bold.get_string_size(c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeManager.fs(17)).x,
			ThemeManager.font_body_bold.get_string_size(c.roman, HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeManager.fs(12)).x)
	b.custom_minimum_size.x = maxf(66, w + 20)
	if not c.chord.is_empty():
		b.pressed.connect(func(): _select("chord", c.chord, c.pc))
	return b


# --- Pięciolinia ----------------------------------------------------------------------

func _staff_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = STAFF_W
	card.add_theme_stylebox_override("panel", ThemeManager.box(Color("F4F1EA"), Color.TRANSPARENT, ThemeManager.radius_card(), 0, 18, 14))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(_label(tr("Staff"), 14, Color("3A3A48"), ThemeManager.font_body_bold))
	head.add_child(_spacer())
	_clef = OptionButton.new()
	_clef.focus_mode = Control.FOCUS_NONE
	_clef.flat = true
	# Klucze: gitara – wiolinowy (także z ósemką), bas – basowy (także z ósemką); każdy instrument
	# pamięta swój wybór.
	var bass := Instrument.is_bass()
	var clef_key := &"enc_clef_bass" if bass else &"enc_clef"
	var clefs := ["bass", "bass_8vb"] if bass else ["treble", "treble_8vb"]
	if bass:
		_clef.add_item(tr("bass clef"))
		_clef.add_item(tr("bass clef, octave lower (bass guitar)"))
	else:
		_clef.add_item(tr("treble clef"))
		_clef.add_item(tr("treble clef, octave lower (guitar)"))
	var clef := str(App.setting(clef_key))
	if not clef in clefs:
		clef = clefs[0]
	_clef.select(clefs.find(clef))
	_clef.add_theme_color_override("font_color", Color("4A4A58"))
	_clef.add_theme_color_override("font_hover_color", Color("1A1A22"))
	_clef.add_theme_font_size_override("font_size", ThemeManager.fs(14))
	for st in ["normal", "hover", "pressed", "focus"]:
		_clef.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_clef.item_selected.connect(func(i: int):
		App.set_setting(clef_key, clefs[i])
		_staff.clef = clefs[i])
	head.add_child(_clef)
	_staff = StaffView.new()
	_staff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_staff.clef = clef
	col.add_child(_staff)
	return card


# Nuty do pięciolinii i do odsłuchu. Z superpozycją – jej dźwięki w prawdziwej wysokości (zapis
# gitarowy: oktawę wyżej niż brzmi), odsłuch w górę i w dół z podświetleniem na gryfie i pięciolinii.
# Bez superpozycji (zakres za szeroki lub pusty): skala od toniki w oktawie razkreślnej z toniką
# oktawę wyżej. Akord – dodatkowo kreska taktowa i współbrzmienie.
# _play_seq: [[midi…], indeks nuty na pięciolinii, pole gryfu (struna, próg)]
func _update_staff() -> void:
	var tl: int = _tonic.l
	var by_pc := {}
	for i in _notes.size():
		if not by_pc.has(Theory.pc(_notes[i])):
			by_pc[Theory.pc(_notes[i])] = i
	var fifths := Theory.key_fifths(_entry, _tonic) if _kind == "scale" else 0
	var notes := []    # [{step, note, root, midi, cell}]
	if not _variants.is_empty():
		for n in _variants[_variant]:
			var i: int = by_pc[posmod(n.midi, 12)]
			var w := _written_midi(_notes[i], n.midi, i == 0)
			w["cell"] = Vector2i(n.s, n.f)
			notes.append(w)
	else:
		for i in _notes.size():
			var num: int = Theory.parse_degree(str(_degrees[i]))[0]
			notes.append(_written(_notes[i], _octave_base() * 7 + tl + num - 1, i == 0))
		if _kind != "chord" and _kind != "interval":
			notes.append(_written(_tonic, _octave_base() * 7 + tl + 7, true))
	var items := []
	var seq := []
	var accs := _measure_accidentals(notes, fifths)
	for i in notes.size():
		var n: Dictionary = notes[i]
		items.append({"heads": [{"step": n.step, "acc": accs[i], "root": n.root}],
				"label": Theory.note_name(n.note, App.notation())})
		seq.append([[n.midi], i, n.get("cell", Vector2i(-1, -1))])
	var down_from := notes.size() - 2
	if _kind == "chord" or _kind == "interval":
		# Współbrzmienie: dźwięki chwytu (przy chwytach) albo akord w położeniu zasadniczym.
		var written := []
		if not _variants.is_empty():
			written = notes
		else:
			for i in _notes.size():
				var num: int = Theory.parse_degree(str(_degrees[i]))[0]
				written.append(_written(_notes[i], _octave_base() * 7 + tl + num - 1, i == 0))
		items.append({"bar": true})
		var stack_acc := _measure_accidentals(written, 0)
		var heads := []
		var all := []
		for i in written.size():
			heads.append({"step": written[i].step, "acc": stack_acc[i], "root": written[i].root})
			all.append(written[i].midi)
		var lbl := str(_entry.id) if _kind == "interval" else Theory.note_name(_tonic, App.notation()) + str(_entry.get("symbol", ""))
		items.append({"heads": heads, "label": lbl})
		seq.append([all, items.size() - 1, Vector2i(-1, -1)])
		down_from = -1
	for i in range(down_from, -1, -1):
		seq.append([[notes[i].midi], i, notes[i].get("cell", Vector2i(-1, -1))])
	_play_seq = seq
	_staff.set_data(items, fifths)


# Dźwięk o danej wysokości (MIDI brzmiące) w pisowni skali; zapis gitarowy – oktawę wyżej.
func _written_midi(note: Dictionary, midi: int, root: bool) -> Dictionary:
	var w := midi + 12
	var octave: int = (w - Theory.LETTER_PC[note.l] - int(note.a)) / 12 - 1
	return {"step": octave * 7 + int(note.l) - STEP_BASE, "note": note, "root": root, "midi": midi}


# Oktawa zapisu przykładu bez superpozycji: gitara – razkreślna, bas – mała (zapis basowy).
func _octave_base() -> int:
	return 3 if Instrument.is_bass() else 4


func _written(note: Dictionary, diatonic: int, root: bool) -> Dictionary:
	var octave := diatonic / 7
	var midi: int = 12 * (octave + 1) + Theory.LETTER_PC[note.l] + int(note.a)
	return {"step": diatonic - STEP_BASE, "note": note, "root": root, "midi": midi - 12}


# Znaki przygodne w obrębie taktu: znak przy nucie, gdy różni się od obowiązującego dla tej litery
# i oktawy (przykluczowe albo wcześniejszy znak w takcie) – z kasownikiem włącznie.
func _measure_accidentals(notes: Array, fifths: int) -> Array:
	var state := {}
	var out := []
	for n in notes:
		var l: int = n.note.l
		var key: int = n.step
		var cur: int = state.get(key, Theory.key_accidental(fifths, l))
		var a: int = n.note.a
		if a == cur:
			out.append(null)
		else:
			out.append(a)
			state[key] = a
	return out


# --- Samouczek (przycisk „?” w nagłówku) ---------------------------------------------
# Krok po kroku na przykładzie: C dorycka w superpozycji od 8. progu.

func _start_tutorial() -> void:
	if _tutorial and is_instance_valid(_tutorial):
		return
	_stop_playing()
	_set_big(false)   # samouczek pokazuje też katalog, kartę i pięciolinię
	_tutorial = TutorialOverlay.new()
	_tutorial.steps = [
		{"title": "Welcome to the Encyclopedia",
			"text": "In a few steps you will learn how to find a scale and practise it on the neck. Example: the C Dorian scale in a position from the 8th fret."},
		{"title": "1. Choose a scale",
			"text": "Pick the type (scales, arpeggios or chords) and an item from the list – here: Dorian. You can also search by name or by notes, e.g. „C D Eb F”.",
			"target": func(): return _catalog_card,
			"action": func(): _tutorial_select()},
		{"title": "2. Choose the tonic",
			"text": "The tonic is the note the scale starts from – here: C. The card below shows the formula, the notes and the chords in the scale.",
			"target": func(): return _tonic_row},
		{"title": "3. The neck",
			"text": "The neck shows every note of the scale. The tonic is red. Use the mouse: wheel – zoom, left button – move, right button – rotate.",
			"target": func(): return _fb},
		{"title": "4. Set the fret range",
			"text": "Set the range with the arrows, by clicking the ruler under the neck, or with a preset. Here: frets 8–12 – one position of the hand.",
			"target": func(): return _range_box,
			"action": func(): _manual_range(8, 12)},
		{"title": "5. Scale shapes",
			"text": "„Scale shapes” lays the scale out so that every pitch is played once, from the lowest to the highest. „Full octaves” keeps it from tonic to tonic. Wider ranges show hand shifts with arrows.",
			"target": func(): return _shapes_box,
			"action": func(): _tutorial_shapes()},
		{"title": "6. Variants",
			"text": "The same notes can be played in several ways. Variant 1 is the most comfortable; try the others.",
			"target": func(): return _variants_box},
		{"title": "7. What the markers show",
			"text": "Choose the labels: pitches, intervals, scale degrees or fingering (1 – index finger … 4 – little finger). Here: fingering.",
			"target": func(): return _modes_box,
			"action": func(): _tutorial_mode("fingers")},
		{"title": "8. Listen",
			"text": "„Listen” plays the variant up and down. The notes light up one by one on the neck and on the staff.",
			"target": func(): return _listen_btn},
		{"title": "9. The staff",
			"text": "The staff shows the scale in its key, with the key signature and the note names.",
			"target": func(): return _staff_box},
		{"title": "10. Play along",
			"text": "Play single notes on your guitar: the note you play lights up on the neck – green when it belongs to the scale, orange when it does not.",
			"target": func(): return _fb},
		{"title": "That's it!",
			"text": "You can bring this guide back at any time with the „?” button at the top of the window."},
	]
	add_child(_tutorial)


func _tutorial_select() -> void:
	var e := Theory.scale("dorian")
	if not e.is_empty():
		_select("scale", e, 0)


func _tutorial_shapes() -> void:
	_shapes = true
	_octaves = true
	_style = ""
	App.set_settings({&"enc_shapes": true, &"enc_octaves": true})
	_variant = 0
	_update_neck()


func _tutorial_mode(m: String) -> void:
	_mode = m
	App.set_setting(&"enc_mode", _mode)
	_build_modes()
	_update_neck()


# --- Granie na gitarze ---------------------------------------------------------------

const HEAR_POLL := 0.04
const HEAR_HOLD := 0.3        # podświetlenie trwa jeszcze chwilę po wybrzmieniu


func _open_input() -> void:
	if not is_inside_tree():
		return
	var core := AudioEngine.ensure_open()
	if core and core.input_ok():
		_hear_timer.start()


func _hear() -> void:
	var core := AudioEngine.ensure_open()
	var now := Time.get_ticks_msec() / 1000.0
	if core == null or not core.input_ok() or _play_timer.time_left > 0.0:
		_tracker.reset()
		_fb.set_heard(Vector2i(-1, -1), [], false, "")
		return
	_tracker.set_a4(clampf(float(App.setting(&"a4")), 400.0, 480.0))
	if _tracker.feed(core.pitch(), now):
		var midi := _tracker.note
		var in_scale := false
		for n in _notes:
			if Theory.pc(n) == posmod(midi, 12):
				in_scale = true
		var cells := _heard_cells(midi)
		_fb.set_heard(cells[0], cells[1], in_scale, NoteNames.note_name(midi, App.notation()))
	elif _tracker.note >= 0 and now - _tracker.last_time() > HEAR_HOLD:
		_tracker.reset()
		_fb.set_heard(Vector2i(-1, -1), [], false, "")


# Miejsca zagranego dźwięku (ta sama wysokość, nie tylko nazwa): wszystkie w zakresie progów (pusta
# struna tylko wtedy, gdy zakres zaczyna się od progu 0). Główne: z bieżącego wariantu superpozycji,
# inaczej najbliżej środka zakresu. Wynik: [główne, [pozostałe]].
func _heard_cells(midi: int) -> Array:
	var spec := _fb.spec
	var all: Array = []
	for s in spec.strings:
		var f: int = midi - spec.open_midi[s]
		if f >= 0 and f <= spec.frets and f >= _from and f <= _to:
			all.append(Vector2i(s, f))
	var main := Vector2i(-1, -1)
	if not _variants.is_empty():
		for n in _variants[_variant]:
			if n.midi == midi:
				main = Vector2i(n.s, n.f)
	if main.x < 0:
		var dist := 1e9
		var mid := (_from + _to) * 0.5
		for c in all:
			var d := absf(c.y - mid)
			if d < dist:
				dist = d
				main = c
	if main.x < 0:
		# Poza zakresem – najbliższe miejsce na całym gryfie.
		var dist := 1e9
		for s in spec.strings:
			var f: int = midi - spec.open_midi[s]
			if f >= 0 and f <= spec.frets and absf(f - (_from + _to) * 0.5) < dist:
				dist = absf(f - (_from + _to) * 0.5)
				main = Vector2i(s, f)
	all.erase(main)
	return [main, all]


# --- Odsłuch -------------------------------------------------------------------------

func _listen() -> void:
	_stop_playing()
	if AudioEngine.ensure_open() == null or _play_seq.is_empty():
		return
	_play_i = 0
	_play_step()
	_play_timer.start()


func _play_step() -> void:
	if _play_i >= _play_seq.size():
		_stop_playing()
		return
	var c := AudioEngine.ensure_open()
	var step: Array = _play_seq[_play_i]
	var last := _play_i == _play_seq.size() - 1
	if c:
		for m in step[0]:
			c.play_note(Instrument.midi_program(), int(m), 0.8, 2.0 if last or step[0].size() > 1 else 0.9)
	_staff.set_playing(step[1])
	_fb.set_playing(step[2])
	_play_i += 1


func _stop_playing() -> void:
	if _play_timer:
		_play_timer.stop()
	if _staff:
		_staff.set_playing(-1)
	if _fb:
		_fb.set_playing(Vector2i(-1, -1))


# --- Elementy -------------------------------------------------------------------------

func _degree_label(deg: String) -> String:
	return deg.replace("bb", "𝄫").replace("##", "𝄪").replace("b", "♭").replace("#", "♯")


func _card(pad: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("border"), pad))
	return card


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 7)
	f.add_theme_constant_override("v_separation", 7)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


func _label(text: String, px: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", ThemeManager.fs(px))
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _small_label(text: String) -> Label:
	var l := _label(text, 15, ThemeManager.color("muted"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _value_label() -> Label:
	var l := _label("", 21, ThemeManager.color("accent"), ThemeManager.font_heading)
	l.custom_minimum_size.x = 32
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


func _arrow_button(dir: int, on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(38, 38)
	b.icon = _triangle_icon(dir, ThemeManager.color("accent"))
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, ThemeManager.box(ThemeManager.color("surface_2") if st == "normal" else ThemeManager.color("border"),
				ThemeManager.color("border_strong"), 8, 1, 0, 0))
	b.pressed.connect(on_press)
	return b


# Trójkąt ◀/▶ jako ikona (krój interfejsu nie ma tych znaków).
func _triangle_icon(dir: int, col: Color) -> Texture2D:
	var pts := "4,2 13,8 4,14" if dir > 0 else "12,2 3,8 12,14"
	return ThemeManager._svg_icon('<polygon points="%s" fill="#%s"/>' % [pts, col.to_html(false)], 16)


func _pill_button(text: String, on_press: Callable, radius := 19) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size.y = 38
	b.add_theme_font_size_override("font_size", ThemeManager.fs(15))
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, ThemeManager.box(ThemeManager.color("surface_2") if st == "normal" else ThemeManager.color("border"),
				ThemeManager.color("border_strong"), radius, 1, 14, 4))
	b.pressed.connect(on_press)
	return b


# --- Tryb „Duży gryf” ------------------------------------------------------------------

func _set_big(on: bool) -> void:
	if _big == on:
		return
	_big = on
	App.set_setting(&"enc_big_neck", on)
	_apply_big(true)


# Duży gryf: pięciolinia znika, dolny rząd (lista i karta) płynnie obniża się do zwartego układu,
# a gryf zajmuje zwolnione miejsce; powrót – odwrotnie.
const ICON := 18.0             # ikona przełącznika „Duży gryf” (px przy skali 1)
const STAFF_W := 680.0
const BOTTOM_H := 430.0
const BOTTOM_H_BIG := 262.0


func _apply_big(animate: bool) -> void:
	_big_btn.icon = _frame_icon(_big)
	_big_btn.tooltip_text = tr("Normal view") if _big else tr("Large neck")
	if _morph:
		_morph.kill()
	var h := _target_h(_big)
	var w := 0.0 if _big else STAFF_W + 18.0
	if not animate:
		_bottom.custom_minimum_size.y = h
		_staff_holder.custom_minimum_size.x = w
		_staff_box.modulate.a = 0.0 if _big else 1.0
		_build_detail()
		return
	# Jedna animacja: rząd paneli niżej/wyżej, pięciolinia zwija się w prawo i gaśnie, karta rośnie
	# w jej miejsce, a treść karty zmienia układ, gdy jest wygaszona. Gryf zajmuje zwolnione miejsce.
	_morph = LayoutMorph.new(self).hold(_fb, Vector2(0, _bottom.custom_minimum_size.y - h)) \
			.height(_bottom, h).width(_staff_holder, w) \
			.fade(_staff_box, 0.0 if _big else 1.0).swap(_detail, _build_detail).then(_fit_bottom)
	_morph.play()


# Wysokość rzędu z kartą: stała z makiety albo więcej, gdy treść karty jej potrzebuje (dłuższe napisy
# w innym języku, większa czcionka, węższe okno – zawijane wiersze). Treść nigdy nie jest ucinana.
func _target_h(big: bool) -> float:
	return maxf(BOTTOM_H_BIG if big else BOTTOM_H, _need[big])


func _fit_bottom() -> void:
	if not is_inside_tree() or (_morph and _morph.running()):
		return
	await get_tree().process_frame   # minimalne rozmiary po przebudowie treści
	if not is_inside_tree() or (_morph and _morph.running()):
		return
	var pad := _detail_card.get_theme_stylebox(&"panel").get_minimum_size().y if _detail_card else 44.0
	_need[_big] = ceilf(_detail.get_combined_minimum_size().y + pad)
	var h := _target_h(_big)
	if absf(_bottom.custom_minimum_size.y - h) <= 0.5:
		return
	if _fit_tween:
		_fit_tween.kill()
	if not _fitted or App.animations() == "off":
		_bottom.custom_minimum_size.y = h
	else:
		_fit_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fit_tween.tween_property(_bottom, "custom_minimum_size:y", h, 0.2)
	_fitted = true


# Test płynności (argument „--morph-test --morph-log”): cztery przełączenia co sekundę, potem koniec.
func _morph_test() -> void:
	for i in 4:
		await get_tree().create_timer(1.0).timeout
		_set_big(not _big)
	await get_tree().create_timer(1.0).timeout
	_set_big(false)
	get_tree().quit()


# Ikona przełącznika (SVG, ostra przy każdej skali): cztery narożniki na zewnątrz – „pełny ekran”,
# do środka – „zwiń”.
var _icons := {}


func _frame_icon(collapse: bool) -> Texture2D:
	# Siatka 18 × 18, linie grubości 2 na całych pikselach, narożniki prostokątne (miter) – cztery
	# jednakowe narożniki o ramionach 4 px; tekstura dokładnie w rozmiarze ekranowym.
	var k := get_viewport().get_final_transform().get_scale().y if is_inside_tree() else 1.0
	var px := maxi(roundi(ICON * k), 8)
	var ink := ThemeManager.color("text")
	var key := "%s|%d|%s" % [collapse, px, ink.to_html()]
	if _icons.has(key):
		return _icons[key]
	var d := "M6 2V6H2M12 2V6H16M6 16V12H2M12 16V12H16" if collapse \
			else "M2 6V2H6M12 2H16V6M2 12V16H6M16 12V16H12"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" width="18" height="18">' \
			+ '<path d="%s" fill="none" stroke="#%s" stroke-width="2" stroke-linecap="square" stroke-linejoin="miter"/></svg>' \
			% [d, ink.to_html(false)]
	var img := Image.new()
	img.load_svg_from_string(svg, float(px) / 18.0)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


func _action_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 50
	b.add_theme_font_override("font", ThemeManager.font_body_bold)
	return b


func _chip_button(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_override("font", ThemeManager.font_body_bold)
	b.add_theme_font_size_override("font_size", ThemeManager.fs(15))
	var bg: Color = ThemeManager.color("accent") if on else ThemeManager.color("surface_2")
	var fg: Color = ThemeManager.color("accent_text") if on else ThemeManager.color("text")
	for st in ["normal", "hover", "pressed"]:
		var c := bg if st == "normal" or on else ThemeManager.color("border")
		b.add_theme_stylebox_override(st, ThemeManager.box(c, ThemeManager.color("accent") if on else ThemeManager.color("border_strong"), 8, 1, 4, 2))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)
	return b


# Kafelek stopnia lub dźwięku (tonika wyróżniona kolorem akcentu).
func _tag(text: String, root: bool, filled: bool) -> Control:
	var p := PanelContainer.new()
	var accent: Color = ThemeManager.color("accent")
	var focus: Color = ThemeManager.color("focus")
	var sb: StyleBoxFlat
	if filled:
		sb = ThemeManager.box(Color(accent if root else focus, 0.18 if root else 0.13), Color.TRANSPARENT, 8, 0, 10, 4)
	else:
		sb = ThemeManager.box(Color.TRANSPARENT, accent if root else ThemeManager.color("border_strong"), 8, 1, 10, 4)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(42, 36)
	var l := _label(text, 16, (accent.lightened(0.25) if root else focus.lightened(0.3)) if filled else ThemeManager.color("text"),
			ThemeManager.font_body_bold)
	if filled and ThemeManager.palette_id() == &"light":
		l.add_theme_color_override("font_color", accent.darkened(0.2) if root else focus.darkened(0.15))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	p.add_child(l)
	return p


func _trainer_chip(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.disabled = true
	b.tooltip_text = tr("Available with the Exercises module.")
	b.add_theme_font_size_override("font_size", ThemeManager.fs(14))
	b.add_theme_font_override("font", ThemeManager.font_body_bold)
	var focus: Color = ThemeManager.color("focus")
	b.add_theme_color_override("font_disabled_color", Color(focus, 0.75))
	b.add_theme_stylebox_override("disabled", ThemeManager.box(Color(focus, 0.08), Color(focus, 0.35), 16, 1, 12, 4))
	return b


func _segmented(items: Array, current: String, on_pick: Callable) -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border"), 10, 1, 3, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	frame.add_child(row)
	for it in items:
		var b := Button.new()
		b.text = it[1]
		b.focus_mode = Control.FOCUS_NONE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var on: bool = it[0] == current
		b.add_theme_font_override("font", ThemeManager.font_body_bold if on else ThemeManager.font_body_medium)
		b.add_theme_font_size_override("font_size", ThemeManager.fs(15))
		var bg: Color = ThemeManager.color("border_strong") if on else Color.TRANSPARENT
		b.add_theme_stylebox_override("normal", ThemeManager.box(bg, Color.TRANSPARENT, 8, 0, 14, 6))
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border_strong") if on else ThemeManager.color("border"), Color.TRANSPARENT, 8, 0, 14, 6))
		b.add_theme_stylebox_override("pressed", ThemeManager.box(ThemeManager.color("border_strong"), Color.TRANSPARENT, 8, 0, 14, 6))
		b.add_theme_color_override("font_color", ThemeManager.color("text") if on else ThemeManager.color("muted"))
		if not on:
			b.pressed.connect(on_pick.bind(it[0]))
		row.add_child(b)
	return frame
