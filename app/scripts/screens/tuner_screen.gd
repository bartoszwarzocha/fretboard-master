# Fretboard Master – Tuner według zaakceptowanej makiety: rozpoznawanie struny albo wybrana struna,
# widoki liniowy, analogowy i cyfrowy, stroje, strój odniesienia A4 i kamerton (dźwięk wzorcowy A4
# albo wybranej struny). Wejście gitary i rozpoznawanie wysokości (MPM) – rdzeń audio w C++ (FbmAudio);
# ekran ok. 30 razy na sekundę odczytuje rozpoznany dźwięk i tylko go pokazuje.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends ModuleScreen

# Stroje z makiety: identyfikator ustawienia „Strój”, nazwa, dźwięki pustych strun (MIDI, od 6. struny).
const TUNINGS := [
	["standard", "Standard", [40, 45, 50, 55, 59, 64]],
	["drop_d", "Drop D", [38, 45, 50, 55, 59, 64]],
	["half_down", "Half step down", [39, 44, 49, 54, 58, 63]],
	["dadgad", "DADGAD", [38, 45, 50, 55, 57, 62]],
	["open_g", "Open G", [38, 43, 50, 55, 59, 62]],
	["open_d", "Open D", [38, 45, 50, 54, 57, 62]],
]
const FLATS := [
	["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"],
	["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B", "H"],
	["Do", "Re♭", "Re", "Mi♭", "Mi", "Fa", "Sol♭", "Sol", "La♭", "La", "Si♭", "Si"],
]
const GREEN := Color("7BD88F")
const YELLOW := Color("F2D15C")
const ORANGE := Color("FF7A59")
const FAINT := Color("8C96B3")
const IN_TUNE := 5.0          # ± centów uznawane za nastrojenie
const POLL := 1.0 / 30.0
const HOLD := 1.5             # s – jak długo pokazywać ostatni odczyt po wybrzmieniu
const A4_MIN := 415
const A4_MAX := 466

var _core: Object
var _main: VBoxContainer
var _aside: VBoxContainer
var _subtitle: Label
var _note: Label
var _octave: Label
var _freq: RichTextLabel
var _digital_cents: Label
var _digital_freq: Label
var _advice: Label
var _meter: Control           # LinearMeter, AnalogDial albo DigitalLeds
var _flat: Arrow
var _sharp: Arrow
var _strings_row: HBoxContainer
var _ref_label: Label
var _tone_button: Button
var _tone_on := false

var _poll_t := 0.0
var _hz_history: Array[float] = []
var _last_seen := -100.0
var _has_reading := false
var _target := 0              # MIDI dźwięku odniesienia bieżącego odczytu
var _target_string := -1      # struna (0 = 6. struna) albo -1 przy dźwięku spoza stroju
var _hz := 0.0
var _cents := 0.0
var _shown_cents := 0.0       # wskazówka – płynnie dochodzi do _cents
var _string_cents: Array = [null, null, null, null, null, null]


func _init() -> void:
	module_id = &"tuning"
	content_margin = Vector2(38, 29)


func _build_content() -> void:
	_core = AudioEngine.ensure_open()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("border"), 43)
	box.content_margin_top = 34
	box.content_margin_bottom = 34
	card.add_theme_stylebox_override("panel", box)
	body.add_child(card)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 0)
	card.add_child(_main)
	_aside = VBoxContainer.new()
	_aside.custom_minimum_size.x = 396
	_aside.add_theme_constant_override("separation", 24)
	body.add_child(_aside)
	_rebuild()
	set_process(true)


func _exit_tree() -> void:
	if _tone_on and _core:
		_core.set_tone(440.0, 0.0)


# --- Budowa ekranu -----------------------------------------------------------------

func _rebuild() -> void:
	for c in _main.get_children():
		_main.remove_child(c)
		c.queue_free()
	for c in _aside.get_children():
		_aside.remove_child(c)
		c.queue_free()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 17)
	head.custom_minimum_size.y = 46   # tyle co z przełącznikiem trybu – bez przeskoku przy „Dowolnym”
	_main.add_child(head)
	var title := _label("Tuner", 31, ThemeManager.color("text"), ThemeManager.font_heading)
	head.add_child(title)
	_subtitle = _label("", 16, FAINT)
	_subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if not _chromatic():
		head.add_child(_segmented([[0, "String detection"], [1, "Selected string"]], _mode(), func(v: Variant) -> void:
			App.set_setting(&"tun_mode", v)
			_reset_reading()
			_rebuild()))

	match _view():
		0: _build_linear()
		1: _build_analog()
		_: _build_digital()

	_advice = _label("", 17, FAINT)
	_advice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_advice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_main.add_child(_gap(17))
	_main.add_child(_advice)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_child(fill)
	_strings_row = HBoxContainer.new()
	_strings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_strings_row.add_theme_constant_override("separation", 14)
	_main.add_child(_strings_row)

	_build_aside()
	_update_texts()
	_refresh()


func _build_linear() -> void:
	_main.add_child(_gap(43))
	_note = _big_note(180)
	_main.add_child(_note_row(180))
	_main.add_child(_gap(7))
	_freq = _freq_line(22)
	_main.add_child(_freq)
	_main.add_child(_gap(43))
	var m := LinearMeter.new()
	m.custom_minimum_size = Vector2(912, 110)
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main.add_child(m)
	_meter = m


func _build_analog() -> void:
	_main.add_child(_gap(26))
	_note = _big_note(132)
	_main.add_child(_note_row(132))
	_main.add_child(_gap(5))
	_freq = _freq_line(22)
	_main.add_child(_freq)
	_main.add_child(_gap(22))
	var d := AnalogDial.new()
	d.custom_minimum_size = Vector2(768, 360)
	d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	d.label = tr("CENTS")
	_main.add_child(d)
	_meter = d


func _build_digital() -> void:
	_main.add_child(_gap(48))
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 840
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := ThemeManager.box(Color("050806"), Color("1F2B24"), 24, 1, 43, 34)
	sb.content_margin_bottom = 36
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 12)
	panel.add_theme_stylebox_override("panel", sb)
	_main.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(top)
	_flat = Arrow.new()
	_flat.left = true
	top.add_child(_flat)
	var mid := HBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 0)
	top.add_child(mid)
	_note = _big_note(156)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mid.add_child(_tight(_note, 156))
	_octave = _label("", 48, Color("4C6B58"), ThemeManager.font_heading)
	_octave.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_octave.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mid.add_child(_tight(_octave, 156, 0.31))
	_sharp = Arrow.new()
	top.add_child(_sharp)
	col.add_child(_gap(17))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	col.add_child(row)
	_digital_cents = _label("", 31, Color("E9F5D0"), ThemeManager.font_heading)
	_digital_cents.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(_digital_cents)
	var bar := _label("|", 31, Color("4C6B58"), ThemeManager.font_heading)
	bar.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(bar)
	_digital_freq = _label("", 31, Color("E9F5D0"), ThemeManager.font_heading)
	_digital_freq.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(_digital_freq)
	col.add_child(_gap(31))
	var leds := DigitalLeds.new()
	leds.custom_minimum_size = Vector2(0, 41)
	col.add_child(leds)
	_meter = leds
	col.add_child(_gap(10))
	var scale := HBoxContainer.new()
	col.add_child(scale)
	for t in ["−50", "0", "+50"]:
		var l := _label(t, 14, Color("4C6B58"))
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][scale.get_child_count()]
		scale.add_child(l)


func _build_aside() -> void:
	# Widok tunera
	var vcard := _aside_card()
	var vc := vcard.get_child(0) as VBoxContainer
	vc.add_child(_label("Tuner view", 24, ThemeManager.color("text"), ThemeManager.font_heading))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	vc.add_child(grid)
	for i in 3:
		var b := _view_button(["rect", "arc", "88"][i], ["Linear", "Analog", "Digital"][i], i == _view())
		b.pressed.connect(func() -> void:
			App.set_setting(&"tun_view", i)
			_rebuild())
		grid.add_child(b)

	# Strój
	var tcard := _aside_card()
	var tc := tcard.get_child(0) as VBoxContainer
	tc.add_child(_label("Tuning", 24, ThemeManager.color("text"), ThemeManager.font_heading))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 7)
	tc.add_child(list)
	for i in TUNINGS.size():
		list.add_child(_tuning_row(i))
	list.add_child(_tuning_row(-1))

	# Strój odniesienia i kamerton
	var rcard := _aside_card()
	var rc := rcard.get_child(0) as VBoxContainer
	rc.add_theme_constant_override("separation", 10)
	rc.add_child(_label("Reference pitch", 16, ThemeManager.color("muted")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	rc.add_child(row)
	row.add_child(_round_button("−", -1))
	_ref_label = _label("", 24, ThemeManager.color("text"), ThemeManager.font_body_bold)
	_ref_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ref_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ref_label.custom_minimum_size.x = 132
	row.add_child(_ref_label)
	row.add_child(_round_button("+", 1))
	rc.add_child(_gap(9))
	_tone_button = Button.new()
	_tone_button.custom_minimum_size.y = 50
	_tone_button.focus_mode = Control.FOCUS_NONE
	_tone_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_tone_button.add_theme_font_override("font", ThemeManager.font_body_bold)
	_tone_button.add_theme_font_size_override("font_size", ThemeManager.fs(17))
	_tone_button.pressed.connect(func() -> void:
		_tone_on = not _tone_on
		_update_tone())
	rc.add_child(_tone_button)
	_update_tone_button()


# --- Odczyt wejścia ---------------------------------------------------------------

func _process(delta: float) -> void:
	_poll_t += delta
	if _poll_t >= POLL:
		_poll_t = 0.0
		if _core and _core.input_ok():
			var p: Dictionary = _core.pitch()
			if float(p.hz) > 0.0 and float(p.clarity) >= 0.8:
				_feed(float(p.hz))
		if _has_reading and _now() - _last_seen > HOLD:
			_reset_reading()
			_refresh()
	# Wskazówka dochodzi płynnie do odczytu.
	if absf(_shown_cents - _cents) > 0.05:
		_shown_cents = lerpf(_shown_cents, _cents, clampf(delta * 14.0, 0.0, 1.0))
		_update_meter()


## Nowy odczyt częstotliwości (mediana z kilku ostatnich – bez skoków przy wybrzmiewaniu).
func _feed(hz: float) -> void:
	_hz_history.append(hz)
	if _hz_history.size() > 5:
		_hz_history.remove_at(0)
	var sorted := _hz_history.duplicate()
	sorted.sort()
	_hz = sorted[sorted.size() / 2]
	_last_seen = _now()
	_has_reading = true
	var notes: Array = _tuning()[2]
	var a4 := _a4()
	if _chromatic():
		_target_string = -1
	elif _mode() == 1:
		_target_string = clampi(int(App.setting(&"tun_string")), 0, 5)
	else:
		# Najbliższa struna stroju; dźwięk dalej niż 2,5 półtonu od każdej – zwykły stroik chromatyczny.
		_target_string = -1
		var best := 1e9
		for i in notes.size():
			var c := _cents_from(_hz, float(notes[i]), a4)
			if absf(c) < absf(best):
				best = c
				_target_string = i
		if absf(best) > 250.0:
			_target_string = -1
	if _target_string >= 0:
		_target = int(notes[_target_string])
	else:
		_target = roundi(69.0 + 12.0 * log(_hz / a4) / log(2.0))
	_cents = _cents_from(_hz, float(_target), a4)
	if _target_string >= 0:
		_string_cents[_target_string] = _cents
		if _mode() == 0 and int(App.setting(&"tun_string")) != _target_string:
			App.set_setting(&"tun_string", _target_string)
	_refresh()


func _reset_reading() -> void:
	_has_reading = false
	_hz_history.clear()
	_cents = 0.0


static func _cents_from(hz: float, midi: float, a4: float) -> float:
	return 1200.0 * log(hz / (a4 * pow(2.0, (midi - 69.0) / 12.0))) / log(2.0)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Odświeżanie ------------------------------------------------------------------

func _refresh() -> void:
	if _note == null:
		return
	var ok := _has_reading and absf(_cents) <= IN_TUNE
	var accent: Color = ThemeManager.color("accent")
	var col: Color = GREEN if ok else accent
	var c := roundi(_cents)
	if _has_reading:
		_note.text = _note_name(_target, _target_string)
	else:
		_note.text = "–"
		col = ThemeManager.color("faint")
	if _view() == 2:
		var lcd := GREEN if ok else Color("E9F5D0")
		_note.add_theme_color_override("font_color", lcd if _has_reading else Color("4C6B58"))
		_note.add_theme_color_override("font_shadow_color", Color(lcd, 0.3 if ok else 0.1) if _has_reading else Color.TRANSPARENT)
		_octave.text = str(_target / 12 - 1) if _has_reading else ""
		_digital_cents.text = ((("+" if c > 0 else "−" if c < 0 else "±") + str(absi(c))) if _has_reading else "––") + " ct"
		_digital_cents.add_theme_color_override("font_color", lcd)
		_digital_freq.text = _freq_text()
		_digital_freq.add_theme_color_override("font_color", lcd)
		_arrow_on(_flat, _has_reading and c < -IN_TUNE)
		_arrow_on(_sharp, _has_reading and c > IN_TUNE)
	else:
		_note.add_theme_color_override("font_color", col)
		_octave.text = str(_target / 12 - 1) if _has_reading and _chromatic() else ""
		var cents_txt := _cents_text(c) if _has_reading else ""
		_freq.text = _freq_text() + ((" · [b][color=#%s]%s[/color][/b]" % [col.to_html(false), cents_txt]) if _has_reading else "")
	if _core == null:
		_advice.text = tr("No sound input – check the Sound and MIDI settings.")
	elif not _core.input_ok():
		_advice.text = tr("No sound input – check the Sound and MIDI settings.") + \
				("" if _core.input_error() == "" else "  (" + _core.input_error() + ")")
	elif not _has_reading:
		_advice.text = tr("Play any note.") if _chromatic() else tr("Play an open string.") if _mode() == 0 \
				else tr("Play the selected string.")
	elif ok:
		_advice.text = tr("String in tune.")
	elif c < 0:
		_advice.text = tr("Too low – tighten the string.")
	else:
		_advice.text = tr("Too high – loosen the string.")
	_update_meter()
	_build_strings()


func _update_meter() -> void:
	if _meter == null:
		return
	_meter.set("cents", clampf(_shown_cents, -50.0, 50.0))
	_meter.set("active", _has_reading)
	_meter.set("ok", _has_reading and absf(_cents) <= IN_TUNE)
	_meter.set("raw_cents", _cents)
	_meter.set("accent", ThemeManager.color("accent"))
	_meter.queue_redraw()


func _update_texts() -> void:
	_subtitle.text = tr("chromatic tuner · A4 = %d Hz") % roundi(_a4())
	_ref_label.text = "A4 = %d Hz" % roundi(_a4())


func _freq_text() -> String:
	if not _has_reading:
		return "– Hz"
	var s := "%.1f Hz" % _hz
	if TranslationServer.get_locale().substr(0, 2) != "en":
		s = s.replace(".", ",")
	return s


func _cents_text(c: int) -> String:
	var n := absi(c)
	var sign := "+" if c > 0 else "−" if c < 0 else ""
	var word: String
	match TranslationServer.get_locale().substr(0, 2):
		"pl":
			word = "cent" if n == 1 else "centy" if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14] else "centów"
		"ru":
			word = "цент" if n % 10 == 1 and n % 100 != 11 else "цента" if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14] else "центов"
		"de":
			word = "Cent"
		_:
			word = "cent" if n == 1 else "cents"
	return "%s%d %s" % [sign, n, word]


var _strings_sig := ""


func _build_strings() -> void:
	# Przebudowa tylko po zmianie tego, co pokazują przyciski (odczyt przychodzi ok. 30 razy na sekundę).
	var states := []
	for v in _string_cents:
		states.append(-9 if v == null else 0 if absf(v) <= IN_TUNE else signi(roundi(v)))
	var sig := str([_chromatic(), _has_reading, _target_string, posmod(_target, 12) if _chromatic() else 0,
			absf(_cents) <= IN_TUNE, states, App.setting(&"tun_string"), App.setting(&"tun_note"), App.setting(&"tuning"),
			_strings_row.get_child_count()])
	if sig == _strings_sig:
		return
	_strings_sig = sig
	for c in _strings_row.get_children():
		_strings_row.remove_child(c)
		c.queue_free()
	if _chromatic():
		_build_notes()
		return
	var notes: Array = _tuning()[2]
	var sel := int(App.setting(&"tun_string"))
	if _mode() == 0 and _has_reading:
		sel = _target_string
	for i in notes.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(125, 122)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var on := i == sel
		var bg := Color("1B2440") if on else ThemeManager.color("surface_2")
		var border: Color = ThemeManager.color("accent") if on else ThemeManager.color("border_strong")
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, ThemeManager.box(bg if st == "normal" else bg.lightened(0.05), border, 17, 1, 0, 17))
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var name := _label(_note_name(int(notes[i]), i), 31, ThemeManager.color("text"), ThemeManager.font_heading)
		name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name)
		var num := _label(tr("string %d") % (6 - i), 14, FAINT)
		num.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(num)
		col.add_child(_gap(7))
		var sc: Variant = _string_cents[i]
		var state := _label("–" if sc == null else tr("in tune") if absf(sc) <= IN_TUNE else tr("too low") if sc < 0 else tr("too high"),
				14, FAINT if sc == null else GREEN if absf(sc) <= IN_TUNE else YELLOW, ThemeManager.font_body_bold)
		state.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(state)
		for c in col.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func() -> void:
			App.set_setting(&"tun_string", i)
			if _mode() == 1:
				_reset_reading()
			_update_tone()
			_refresh())
		_strings_row.add_child(b)


## Tryb „Dowolny”: 12 dźwięków – podświetlony rozpoznany, kliknięcie wybiera dźwięk kamertonu.
func _build_notes() -> void:
	_strings_row.add_theme_constant_override("separation", 8)
	var sel := posmod(_target, 12) if _has_reading else int(App.setting(&"tun_note"))
	for pc in 12:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 90)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.text = NoteNames.note_name(60 + pc, App.notation())
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.add_theme_font_override("font", ThemeManager.font_heading)
		b.add_theme_font_size_override("font_size", ThemeManager.fs(22 if b.text.length() <= 2 else 17))
		var on := pc == sel
		var bg := Color("1B2440") if on else ThemeManager.color("surface_2")
		var border: Color = ThemeManager.color("accent") if on else ThemeManager.color("border_strong")
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, ThemeManager.box(bg if st == "normal" else bg.lightened(0.05), border, 14, 1, 0, 0))
		var tc: Color = (GREEN if absf(_cents) <= IN_TUNE else ThemeManager.color("accent")) if on and _has_reading else ThemeManager.color("text")
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, tc)
		b.pressed.connect(func() -> void:
			App.set_setting(&"tun_note", pc)
			_update_tone()
			_refresh())
		_strings_row.add_child(b)


# --- Kamerton -----------------------------------------------------------------------

## Dźwięk wzorcowy: przy rozpoznawaniu struny – A4, przy wybranej strunie – dźwięk tej struny.
func _update_tone() -> void:
	_update_tone_button()
	if _tone_on and _core == null:
		_core = AudioEngine.ensure_open()
	if _core == null:
		return
	if not _tone_on:
		_core.set_tone(440.0, 0.0)
		return
	var midi := 69
	if _chromatic():
		midi = 60 + clampi(int(App.setting(&"tun_note")), 0, 11)   # oktawa razkreślna, A = A4
	elif _mode() == 1:
		midi = int(_tuning()[2][clampi(int(App.setting(&"tun_string")), 0, 5)])
	_core.set_tone(_a4() * pow(2.0, (midi - 69) / 12.0), 0.5)


func _update_tone_button() -> void:
	if _tone_button == null:
		return
	_tone_button.text = tr("Stop reference tone") if _tone_on else tr("Play reference tone")
	var bg: Color = Color("1B2440") if _tone_on else ThemeManager.color("surface_2")
	var border: Color = ThemeManager.color("accent") if _tone_on else ThemeManager.color("border_strong")
	_tone_button.add_theme_stylebox_override("normal", ThemeManager.box(bg, border, 12, 1, 12, 0))
	_tone_button.add_theme_stylebox_override("hover", ThemeManager.box(bg.lightened(0.05), border, 12, 1, 12, 0))
	_tone_button.add_theme_stylebox_override("pressed", ThemeManager.box(ThemeManager.color("border"), border, 12, 1, 12, 0))


# --- Dane ---------------------------------------------------------------------------

func _view() -> int:
	return clampi(int(App.setting(&"tun_view")), 0, 2)


func _mode() -> int:
	return clampi(int(App.setting(&"tun_mode")), 0, 1)


func _a4() -> float:
	return clampf(float(App.setting(&"a4")), A4_MIN, A4_MAX)


func _chromatic() -> bool:
	return bool(App.setting(&"tun_chromatic"))


func _tuning_index() -> int:
	if _chromatic():
		return -1
	var id := str(App.setting(&"tuning"))
	for i in TUNINGS.size():
		if TUNINGS[i][0] == id:
			return i
	return -1


func _tuning() -> Array:
	var i := _tuning_index()
	if i >= 0:
		return TUNINGS[i]
	# Strój spoza listy (np. z ustawień: Drop C) – dźwięki z nagłówka.
	var id := str(App.setting(&"tuning"))
	return [id, id, ModuleHeader.TUNING_MIDI.get(id, TUNINGS[0][2])]


## Nazwa dźwięku w wybranym zapisie; w stroju „pół tonu niżej” – z bemolami (jak w makiecie).
func _note_name(midi: int, string_index: int) -> String:
	if string_index >= 0 and str(App.setting(&"tuning")) == "half_down":
		return FLATS[clampi(App.notation(), 0, 2)][posmod(midi, 12)]
	return NoteNames.note_name(midi, App.notation())


# --- Kontrolki ------------------------------------------------------------------------

## Wiersz stroju; i = −1 – „Dowolny” (stroik chromatyczny, bez przypinania do strun).
func _tuning_row(i: int) -> Button:
	var on := _chromatic() if i < 0 else i == _tuning_index()
	var b := Button.new()
	b.custom_minimum_size.y = 48
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg := Color("1B2440") if on else ThemeManager.color("surface_2")
	var border: Color = ThemeManager.color("accent") if on else Color.TRANSPARENT
	b.add_theme_stylebox_override("normal", ThemeManager.box(bg, border, 12, 1, 17, 0))
	b.add_theme_stylebox_override("hover", ThemeManager.box(bg.lightened(0.05), border, 12, 1, 17, 0))
	b.add_theme_stylebox_override("pressed", ThemeManager.box(bg, border, 12, 1, 17, 0))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 17
	row.offset_right = -17
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var name := _label("Any" if i < 0 else TUNINGS[i][1], 17, ThemeManager.color("text"), ThemeManager.font_body_bold)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name)
	var parts := PackedStringArray()
	for m in ([] if i < 0 else TUNINGS[i][2]):
		parts.append(FLATS[clampi(App.notation(), 0, 2)][posmod(m, 12)] if TUNINGS[i][0] == "half_down" else NoteNames.note_name(m, App.notation()))
	var notes := _label(tr("chromatic") if i < 0 else " ".join(parts), 14, FAINT)
	notes.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	notes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	notes.add_theme_constant_override("letter_spacing", 1)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(notes)
	b.pressed.connect(func() -> void:
		if i < 0:
			App.set_setting(&"tun_chromatic", true)
		else:
			App.set_settings({&"tun_chromatic": false, &"tuning": TUNINGS[i][0]})
		_string_cents = [null, null, null, null, null, null]
		_reset_reading()
		_update_tone()
		_rebuild())
	return b


func _view_button(icon: String, text: String, on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 89)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg := Color("1B2440") if on else ThemeManager.color("surface_2")
	var border: Color = ThemeManager.color("accent") if on else ThemeManager.color("border_strong")
	b.add_theme_stylebox_override("normal", ThemeManager.box(bg, border, 14, 1, 0, 0))
	b.add_theme_stylebox_override("hover", ThemeManager.box(bg.lightened(0.05), border, 14, 1, 0, 0))
	b.add_theme_stylebox_override("pressed", ThemeManager.box(bg, border, 14, 1, 0, 0))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 7)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var c: Color = ThemeManager.color("text") if on else ThemeManager.color("muted")
	var i := ViewIcon.new()
	i.kind = icon
	i.color = c
	i.custom_minimum_size = Vector2(0, 26)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(i)
	var t := _label(text, 17, c, ThemeManager.font_body_bold)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	return b


## Nazwa dźwięku z cyfrą oktawy (oktawa – tylko w trybie „Dowolny”).
func _note_row(px: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_tight(_note, px))
	_octave = _label("", roundi(px * 0.31), ThemeManager.color("muted"), ThemeManager.font_heading)
	_octave.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(_tight(_octave, px, 0.31))
	return row


## Napis w pudełku o wysokości równej wielkości czcionki (jak line-height: 1 w makiecie); `drop` przesuwa
## napis w dół o ułamek wysokości (cyfra oktawy przy linii bazowej nazwy dźwięku).
func _tight(l: Label, px: int, drop := 0.0) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(0, ThemeManager.fs(px))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_top = -ThemeManager.fs(px) * 0.5 + ThemeManager.fs(px) * drop
	l.offset_bottom = ThemeManager.fs(px) * 0.5 + ThemeManager.fs(px) * drop
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.add_child(l)
	l.resized.connect(func() -> void: box.custom_minimum_size.x = l.get_minimum_size().x)
	box.custom_minimum_size.x = l.get_minimum_size().x
	return box


func _big_note(px: int) -> Label:
	var l := _label("–", px, ThemeManager.color("accent"), ThemeManager.font_heading)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("line_spacing", 0)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 12)
	return l


func _freq_line(px: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", ThemeManager.fs(px))
	r.add_theme_font_size_override("bold_font_size", ThemeManager.fs(px))
	r.add_theme_font_override("normal_font", ThemeManager.font_body)
	r.add_theme_font_override("bold_font", ThemeManager.font_body_bold)
	r.add_theme_color_override("default_color", ThemeManager.color("muted"))
	return r


func _arrow_on(a: Arrow, on: bool) -> void:
	a.on = on
	a.queue_redraw()


func _label(text: String, px: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", ThemeManager.fs(px))
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _round_button(text: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(43, 43)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_size_override("font_size", ThemeManager.fs(22))
	for state in ["normal", "hover", "pressed"]:
		var bg: Color = ThemeManager.color("surface_2") if state == "normal" else ThemeManager.color("border")
		b.add_theme_stylebox_override(state, ThemeManager.box(bg, ThemeManager.color("border_strong"), 22, 1, 0, 0))
	b.pressed.connect(func() -> void:
		App.set_setting(&"a4", float(clampi(roundi(_a4()) + step, A4_MIN, A4_MAX)))
		_update_texts()
		_update_tone()
		if _has_reading:
			_feed(_hz)
		else:
			_refresh())
	return b


func _segmented(items: Array, current: int, on_pick: Callable) -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border"), 12, 1, 4, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	frame.add_child(row)
	for it in items:
		var b := Button.new()
		b.text = it[1]
		b.focus_mode = Control.FOCUS_NONE
		var on: bool = it[0] == current
		b.add_theme_font_override("font", ThemeManager.font_body_bold if on else ThemeManager.font_body_medium)
		b.add_theme_font_size_override("font_size", ThemeManager.fs(17))
		var bg: Color = ThemeManager.color("border_strong") if on else Color.TRANSPARENT
		b.add_theme_stylebox_override("normal", ThemeManager.box(bg, Color.TRANSPARENT, 10, 0, 19, 9))
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border_strong") if on else ThemeManager.color("border"), Color.TRANSPARENT, 10, 0, 19, 9))
		b.add_theme_stylebox_override("pressed", ThemeManager.box(ThemeManager.color("border_strong"), Color.TRANSPARENT, 10, 0, 19, 9))
		b.add_theme_color_override("font_color", ThemeManager.color("text") if on else ThemeManager.color("muted"))
		if not on:
			b.pressed.connect(on_pick.bind(it[0]))
		row.add_child(b)
	return frame


func _aside_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("border"), 24))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	_aside.add_child(card)
	return card


# --- Wskaźniki (rysowane – jeden węzeł zamiast wielu) ----------------------------------

## Widok liniowy: pasek od −50 do +50 centów, podziałka i wskaźnik.
class LinearMeter extends Control:
	var cents := 0.0
	var raw_cents := 0.0
	var active := false
	var ok := false
	var accent := Color("F5B544")

	func _x(v: float) -> float:
		return size.x * 0.5 + v * (size.x / 100.0)

	func _draw() -> void:
		var s := size.x / 760.0
		# Pasek barwny (jak gradient w makiecie, krycie 35%).
		var stops := [[0.0, Color("FF7A59")], [0.35, Color("F2D15C")], [0.46, Color("7BD88F")], [0.54, Color("7BD88F")],
				[0.65, Color("F2D15C")], [1.0, Color("FF7A59")]]
		var y0 := 40.0 * s
		var h := 12.0 * s
		var r := h * 0.5
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var inner := size.x - 2.0 * r
		for st in stops:
			pts.append(Vector2(r + inner * st[0], y0))
			cols.append(Color(st[1], 0.35))
		for k in range(stops.size() - 1, -1, -1):
			pts.append(Vector2(r + inner * stops[k][0], y0 + h))
			cols.append(Color(stops[k][1], 0.35))
		draw_polygon(pts, cols)
		draw_circle(Vector2(r, y0 + r), r, Color("FF7A59", 0.35))
		draw_circle(Vector2(size.x - r, y0 + r), r, Color("FF7A59", 0.35))
		# Podziałka i opisy.
		var font := ThemeManager.font_body
		var fsz := ThemeManager.fs(14)
		for v in range(-50, 51, 10):
			var x := _x(v)
			var top := (28.0 if v == 0 or absi(v) == 50 else 34.0) * s
			var len := (36.0 if v == 0 else 24.0) * s
			draw_rect(Rect2(x - s, top, 2.0 * s, len), Color("E8ECF6") if v == 0 else Color("3A4566"))
			var t := "0" if v == 0 else ("+%d" % v if v > 0 else "−%d" % -v)
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			draw_string(font, Vector2(x - w * 0.5, 70.0 * s + fsz), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("8C96B3"))
		# Wskaźnik.
		if active:
			var c := Color("7BD88F") if ok else accent
			var sb := StyleBoxFlat.new()
			sb.bg_color = c
			sb.set_corner_radius_all(int(3 * s))
			sb.shadow_color = Color(c, 0.7)
			sb.shadow_size = int(10 * s)
			draw_style_box(sb, Rect2(_x(cents) - 3.0 * s, 14.0 * s, 6.0 * s, 64.0 * s))


## Widok analogowy: tarcza miernika (tło – shader), podziałka, strefa ±5 centów i wskazówka.
class AnalogDial extends Control:
	const SHADER := """
shader_type canvas_item;
uniform vec2 px_size;
uniform float k;
float sd_round(vec2 p, vec2 b, vec4 r) {
	r.xy = (p.x > 0.0) ? r.xy : r.zw;
	r.x = (p.y > 0.0) ? r.x : r.y;
	vec2 q = abs(p) - b + r.x;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}
void fragment() {
	vec2 p = UV * px_size;
	vec2 c = px_size * 0.5;
	// promienie: górne 22, dolne 14 (w px makiety × k)
	float d = sd_round(p - c, c, vec4(14.0 * k, 22.0 * k, 14.0 * k, 22.0 * k));
	vec2 e = (p - vec2(c.x, px_size.y)) / vec2(c.x * 1.4142, px_size.y * 1.4142);
	vec3 face = mix(vec3(0.984, 0.973, 0.941), vec3(0.918, 0.894, 0.839), clamp(length(e), 0.0, 1.0));
	vec3 col = face;
	float in6 = 6.0 * k;
	if (d > -in6) col = vec3(0.102, 0.129, 0.251);
	else if (d > -in6 - 1.0 * k) col = vec3(0.227, 0.271, 0.4);
	float a = clamp(0.5 - d, 0.0, 1.0);
	COLOR = vec4(col, a);
}
"""
	var cents := 0.0
	var raw_cents := 0.0
	var active := false
	var ok := false
	var accent := Color("F5B544")
	var label := "CENTS"
	var _mat: ShaderMaterial

	func _ready() -> void:
		_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHADER
		_mat.shader = sh
		var bg := ColorRect.new()
		bg.material = _mat
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.show_behind_parent = true
		add_child(bg)
		resized.connect(func() -> void:
			_mat.set_shader_parameter("px_size", size)
			_mat.set_shader_parameter("k", size.x / 640.0))
		_mat.set_shader_parameter("px_size", custom_minimum_size)
		_mat.set_shader_parameter("k", custom_minimum_size.x / 640.0)

	func _p(c: float, r: float) -> Vector2:
		var k := size.x / 640.0
		var a := deg_to_rad(c / 50.0 * 58.0)
		return Vector2(320.0 + r * sin(a), 282.0 - r * cos(a)) * k

	func _draw() -> void:
		var k := size.x / 640.0
		# Strefa nastrojenia ±5 centów.
		var a0 := deg_to_rad(-5.0 / 50.0 * 58.0) - PI / 2.0
		var a1 := deg_to_rad(5.0 / 50.0 * 58.0) - PI / 2.0
		draw_arc(Vector2(320, 282) * k, 247.0 * k, a0, a1, 16, Color("7BD88F", 0.55), 14.0 * k, true)
		for v in range(-50, 51, 5):
			var big := v % 10 == 0
			draw_line(_p(v, 236), _p(v, 212 if big else 222), Color("2A2A36"), (3.0 if v == 0 else 2.0 if big else 1.2) * k, true)
		var font := ThemeManager.font_body_bold
		var fsz := roundi(14 * k)
		for v in range(-50, 51, 10):
			var t := "0" if v == 0 else ("+%d" % v if v > 0 else "−%d" % -v)
			var pos := _p(v, 190) + Vector2(0, 5 * k)
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			draw_string(font, Vector2(pos.x - w * 0.5, pos.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color("3A3A48"))
		var body := ThemeManager.font_body
		var lsz := roundi(13 * k)
		var lw := body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x + 2.0 * k * (label.length() - 1)
		var x := 320.0 * k - lw * 0.5
		for ch in label:
			draw_string(body, Vector2(x, 150 * k), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz, Color("6A6A78"))
			x += body.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, lsz).x + 2.0 * k
		var music := ThemeManager.font_music
		draw_string(music, Vector2(70, 270) * k, "♭", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(62 * k), Color("C0582F"))
		draw_string(music, Vector2(560, 270) * k, "♯", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(62 * k), Color("C0582F"))
		var tip := _p(cents if active else 0.0, 232)
		draw_line(Vector2(320, 282) * k, tip, Color("C0302A") if active else Color("C0302A", 0.35), 3.5 * k, true)
		draw_circle(Vector2(320, 282) * k, 13 * k, Color("1A1A22"))
		draw_circle(Vector2(320, 282) * k, 5 * k, Color("C9CED9"))


## Widok cyfrowy: 21 diod co 5 centów (środkowa wyższa).
class DigitalLeds extends Control:
	var cents := 0.0
	var raw_cents := 0.0
	var active := false
	var ok := false
	var accent := Color("F5B544")

	func _draw() -> void:
		var w := 26.0
		var gap := 7.0
		var total := 21.0 * w + 20.0 * gap
		var x0 := (size.x - total) * 0.5
		var lit := roundi(raw_cents / 5.0)
		for i in 21:
			var k := i - 10
			var on := active and (k == lit or (ok and absi(k) <= 1))
			var col := Color("7BD88F") if absi(k) <= 1 else Color("F2D15C") if absi(k) <= 5 else Color("FF7A59")
			var h := 41.0 if k == 0 else 31.0
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(5)
			sb.bg_color = col if on else Color("121A15")
			sb.border_color = col if on else Color("1F2B24")
			sb.set_border_width_all(1)
			if on:
				sb.shadow_color = Color(col, 0.8)
				sb.shadow_size = 8
			draw_style_box(sb, Rect2(x0 + i * (w + gap), (size.y - h) * 0.5, w, h))


## Strzałka widoku cyfrowego: trójkąt i znak ♭ / ♯; zapalona – pomarańczowa z poświatą.
class Arrow extends Control:
	var left := false
	var on := false

	func _init() -> void:
		custom_minimum_size = Vector2(108, 60)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Color("FF7A59") if on else Color("1F2B24")
		var font := ThemeManager.font_music   # Bravura: znaki chromatyczne w skali pięciolinii – stąd duży rozmiar
		var fsz := ThemeManager.fs(84)
		var sign := "♭" if left else "♯"
		var sw := font.get_string_size(sign, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var tri := 20.0
		var gap := 8.0
		var total := tri + gap + sw
		var x0 := (size.x - total) * 0.5
		var cy := size.y * 0.5
		var tx := x0 if left else x0 + sw + gap
		var sx := x0 + tri + gap if left else x0
		var pts := PackedVector2Array([Vector2(tx + tri, cy - 11), Vector2(tx + tri, cy + 11), Vector2(tx, cy)]) if left \
				else PackedVector2Array([Vector2(tx, cy - 11), Vector2(tx, cy + 11), Vector2(tx + tri, cy)])
		if on:
			for k in 3:
				var g := 1.0 + 0.25 * (k + 1)
				var c := Vector2(tx + tri * 0.5, cy)
				var big := PackedVector2Array()
				for p in pts:
					big.append(c + (p - c) * g)
				draw_colored_polygon(big, Color(col, 0.12))
		draw_colored_polygon(pts, col)
		draw_string(font, Vector2(sx, cy + fsz * 0.12), sign, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)


## Ikona widoku tunera: prostokąt (liniowy), łuk (analogowy) albo „88” (cyfrowy).
class ViewIcon extends Control:
	var kind := "rect"
	var color := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"rect":
				draw_rect(Rect2(c.x - 9, c.y - 4, 18, 8), color, false, 2.0)
			"arc":
				draw_arc(Vector2(c.x, c.y + 6), 9.0, PI * 1.12, PI * 1.88, 16, color, 2.0, true)
			_:
				var f := ThemeManager.font_body_bold
				var fsz := ThemeManager.fs(26)
				var w := f.get_string_size("88", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
				draw_string(f, Vector2(c.x - w * 0.5, c.y + fsz * 0.36), "88", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, color)
