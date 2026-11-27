# Fretboard Master – Metronom według zaakceptowanej makiety: metronom klasyczny (metrum, podział,
# brzmienie, akcenty) i automat perkusyjny MIDI (siatka kroków, wzorce, zestawy perkusyjne GS),
# stopniowe przyspieszanie i wystukiwanie tempa. Dźwięk i taktowanie – rdzeń audio w C++ (FbmAudio);
# ekran tylko ustawia parametry i co klatkę odczytuje słyszany właśnie krok (wtedy, gdy metronom gra).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends ModuleScreen

const METRES := ["2/4", "3/4", "4/4", "6/8", "7/8"]
const BEATS := [2, 3, 4, 6, 7]
const SUBS := [["quarter notes", 1], ["eighth notes", 2], ["triplets", 3], ["sixteenth notes", 4]]
const SOUNDS := ["click", "woodblock", "bell"]
const GRIDS := ["eighth notes", "triplets", "sixteenth notes"]
const KITS := [["Standard", 0], ["Room", 8], ["Power", 16], ["Jazz", 32], ["Brush", 40]]
const PRESETS := ["Rock", "Pop", "Shuffle", "Waltz", "Ballad 6/8"]
# Wiersze automatu (od góry): nazwa i klawisz perkusji General MIDI – zgodnie z rdzeniem (kDrumKeys).
const ROWS := [["Crash", "GM 49"], ["Ride", "GM 51"], ["Open hi-hat", "GM 46"], ["Closed hi-hat", "GM 42"],
		["Snare", "GM 38"], ["Kick", "GM 36"]]
const TEMPO_NAMES := [[40, "Grave"], [60, "Largo"], [66, "Larghetto"], [76, "Adagio"], [108, "Andante"],
		[120, "Moderato"], [156, "Allegro"], [176, "Vivace"], [200, "Presto"], [9999, "Prestissimo"]]
const BPM_MIN := 30
const BPM_MAX := 260
const STOP := Color("FF7A59")
const ARROW_STEPS := {KEY_UP: 1, KEY_DOWN: -1, KEY_RIGHT: 5, KEY_LEFT: -5}

var _core: Object
var _playing := false
var _pattern: Array = []          # wiersze × kroki, wartości 0/1/2
var _taps: Array[float] = []
var _from_edit: LineEdit
var _main: VBoxContainer
var _aside: VBoxContainer
var _subtitle: Label
var _bpm_label: Label
var _tempo_label: RichTextLabel
var _beats: BeatLights
var _grid: DrumGrid
var _play: Button
var _error: Label
var _looper: LooperTab     # zakładka „Looper” (gdy wybrana)


func _init() -> void:
	module_id = &"metronome"
	content_margin = Vector2(38, 29)


func _build_content() -> void:
	_core = AudioEngine.core()
	_pattern = _load_pattern()
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
	card.add_child(_main)
	_aside = VBoxContainer.new()
	_aside.custom_minimum_size.x = 456
	_aside.add_theme_constant_override("separation", 24)
	body.add_child(_aside)
	_rebuild()


func _exit_tree() -> void:
	if _playing and _core:
		_core.stop()
	if _looper:
		_looper.stop_all()


# Klawisze ekranu (przed obsługą przycisków, żeby spacja nie „klikała” przycisku z fokusem):
# spacja – start/stop, T – wystukiwanie tempa, ↑/↓ ±1 BPM, →/← ±5 BPM (przytrzymanie powtarza).
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or not is_visible_in_tree():
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if _looper and k.keycode in [KEY_SPACE, KEY_R] and not k.echo:
		if k.keycode == KEY_SPACE:
			_looper.toggle_play()
		else:
			_looper.toggle_record()
	elif k.keycode == KEY_SPACE and not k.echo:
		_toggle()
	elif k.keycode == KEY_T and not k.echo:
		_tap()
	elif k.keycode in ARROW_STEPS:
		_set_bpm(_bpm() + ARROW_STEPS[k.keycode])
	else:
		return
	get_viewport().set_input_as_handled()


# --- Budowa ekranu -----------------------------------------------------------------

func _rebuild() -> void:
	for c in _main.get_children():
		c.queue_free()
	for c in _aside.get_children():
		c.queue_free()
	_beats = null
	_grid = null
	if _looper:
		_looper.stop_all()
		_looper.queue_free()
		_looper = null
	var drums := _mode() == 1

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	_main.add_child(head)
	var title := _label("Metronome", 31, ThemeManager.color("text"), ThemeManager.font_heading)
	head.add_child(title)
	_subtitle = _label("", 16, ThemeManager.color("faint"))
	_subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_subtitle)
	head.add_child(_segmented([[0, "Classic metronome"], [1, "Drum machine"], [2, "Looper"]], _mode(), func(v: Variant) -> void:
		_stop()
		_store(&"met_mode", v)
		_rebuild()))

	if _mode() == 2:
		_play = null
		_looper = LooperTab.new(self)
		add_child(_looper)
		_looper.build(_main, _aside)
		_update_texts()
		return

	if drums:
		_build_drums()
	else:
		_build_classic()

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_child(fill)
	_error = _label("", 15, STOP)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.visible = false
	_main.add_child(_error)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	_main.add_child(buttons)
	_play = Button.new()
	_play.custom_minimum_size = Vector2(190, 67)
	_play.add_theme_font_override("font", ThemeManager.font_body_bold)
	_play.add_theme_font_size_override("font_size", ThemeManager.fs(21))
	_play.pressed.connect(_toggle)
	buttons.add_child(_play)
	var tap := Button.new()
	tap.text = "Tap tempo"
	tap.custom_minimum_size.y = 67
	tap.add_theme_font_override("font", ThemeManager.font_body_bold)
	tap.add_theme_font_size_override("font_size", ThemeManager.fs(19))
	for state in ["normal", "hover", "pressed"]:
		var bg: Color = ThemeManager.color("surface_2") if state == "normal" else ThemeManager.color("border")
		tap.add_theme_stylebox_override(state, ThemeManager.box(bg, ThemeManager.color("border_strong"), 17, 1, 34, 10))
	tap.pressed.connect(_tap)
	buttons.add_child(tap)
	# „?” przy wystukiwaniu – wyjaśnienie i skróty klawiszowe w dymku.
	var help := Label.new()
	help.text = "?"
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	help.mouse_default_cursor_shape = Control.CURSOR_HELP
	help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help.custom_minimum_size = Vector2(30, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help.add_theme_font_override("font", ThemeManager.font_body_bold)
	help.add_theme_font_size_override("font_size", ThemeManager.fs(16))
	help.add_theme_color_override("font_color", ThemeManager.color("hint"))
	help.add_theme_stylebox_override("normal", ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border_strong"), 15, 1, 0, 0))
	help.tooltip_text = tr("Click the button (or press T) in time with the music – at least 2 times. The tempo sets itself.") + \
			"\n" + tr("Space – start/stop · ↑/↓ – tempo ±1 · ←/→ – tempo ±5")
	help.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	buttons.add_child(help)
	_taps.clear()
	_update_play_button()

	_build_aside(drums)
	_update_texts()
	_apply()


func _build_classic() -> void:
	_main.add_child(_gap(48))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)
	_main.add_child(row)
	row.add_child(_round_button("−", -1, 77, 34))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 0)
	row.add_child(mid)
	_bpm_label = _label("", 168, ThemeManager.color("text"), ThemeManager.font_heading)
	_bpm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bpm_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_bpm_label.custom_minimum_size.x = 330
	mid.add_child(_bpm_label)
	_tempo_label = _rich_tempo(19, tr("beats per minute"))
	mid.add_child(_tempo_label)
	row.add_child(_round_button("+", 1, 77, 34))
	_main.add_child(_gap(53))
	_beats = BeatLights.new()
	_beats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main.add_child(_beats)
	_beats.setup(BEATS[_metre()], _accents(), ThemeManager.color("accent"))


func _build_drums() -> void:
	_main.add_child(_gap(31))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_main.add_child(row)
	row.add_child(_round_button("−", -1, 53, 26))
	_bpm_label = _label("", 67, ThemeManager.color("text"), ThemeManager.font_heading)
	_bpm_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_bpm_label.custom_minimum_size.x = 120
	_bpm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_bpm_label)
	row.add_child(_round_button("+", 1, 53, 26))
	_tempo_label = _rich_tempo(17, "BPM")
	_tempo_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tempo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(_tempo_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var pl := _label("Patterns:", 16, ThemeManager.color("muted"))
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pl)
	for i in PRESETS.size():
		var b := _chip(PRESETS[i], false, true)
		b.pressed.connect(_preset.bind(i))
		row.add_child(b)

	_main.add_child(_gap(38))
	_grid = DrumGrid.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.add_child(_grid)
	var names: Array = []
	for r in ROWS:
		names.append([tr(r[0]), r[1]])
	_grid.setup(names, _pattern, _groups(_metre(), _grid_kind()), _count_labels(), ThemeManager.color("accent"))
	_grid.changed.connect(func() -> void:
		_save_pattern()
		_apply())

	_main.add_child(_gap(22))
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 22)
	_main.add_child(legend)
	legend.add_child(_label("Click a cell: hit → accent → empty.", 16, ThemeManager.color("hint")))
	legend.add_child(_legend_item(ThemeManager.color("focus"), "hit"))
	legend.add_child(_legend_item(ThemeManager.color("accent"), "accent"))
	var loop := _label(tr("Loop: 1 bar, %s") % _steps_text(_steps(_metre(), _grid_kind())), 16, ThemeManager.color("hint"))
	loop.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	legend.add_child(loop)
	var lsp := Control.new()
	lsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(lsp)
	var restore := _chip("Restore pattern", false, true)
	restore.tooltip_text = tr("Brings back the grid of the chosen pattern after your own changes.")
	restore.pressed.connect(_restore_pattern)
	legend.add_child(restore)
	var clear := _chip("Clear", false, true)
	clear.pressed.connect(func() -> void:
		_pattern = _empty(_steps(_metre(), _grid_kind()))
		_save_pattern()
		_rebuild())
	legend.add_child(clear)


func _build_aside(drums: bool) -> void:
	var card := _aside_card()
	var col := card.get_child(0) as VBoxContainer
	col.add_child(_field("Metre", _chips_row(METRES, _metre(), false, func(i: int) -> void:
		_stop()
		var g := _grid_kind()
		if i >= 3 and g == 1:
			g = 0
		App.set_settings({&"met_metre": i, &"met_grid": g, &"met_preset": -1})
		_pattern = _basic(i, g)
		_save_pattern()
		_rebuild())))
	if not drums:
		var subs: Array = []
		for s in SUBS:
			subs.append(s[0])
		col.add_child(_field("Subdivision", _chips_row(subs, int(App.setting(&"met_sub")), true, func(i: int) -> void:
			_store(&"met_sub", i)
			_update_texts()
			_apply())))
		col.add_child(_field("Sound", _chips_row(SOUNDS, int(App.setting(&"met_sound")), true, func(i: int) -> void:
			_store(&"met_sound", i)
			_apply())))
	else:
		var grids := _chips_row(GRIDS, _grid_kind(), true, func(i: int) -> void:
			_stop()
			App.set_settings({&"met_grid": i, &"met_preset": -1})
			_pattern = _basic(_metre(), i)
			_save_pattern()
			_rebuild(), true)
		if _metre() >= 3:   # w metrum ósemkowym nie ma siatki triolowej
			(grids.get_child(1) as Button).disabled = true
		col.add_child(_field("Grid", grids))
		var kits: Array = []
		for k in KITS:
			kits.append(k[0])
		var kit_row := _chips_row(kits, int(App.setting(&"met_kit")), false, func(i: int) -> void:
			_store(&"met_kit", i)
			_update_texts()
			_apply(), true)
		var f := _field("MIDI drum kit", kit_row)
		var note := _label("Built-in synthesizer, channel 10 (General MIDI drums). You can change this in the Sound and MIDI settings.",
				14, ThemeManager.color("hint"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.add_child(note)
		col.add_child(f)

	# Stopniowe przyspieszanie
	var ramp := _aside_card()
	var rc := ramp.get_child(0) as VBoxContainer
	var rh := HBoxContainer.new()
	rc.add_child(rh)
	var rt := _label("Gradual speed-up", 24, ThemeManager.color("text"), ThemeManager.font_heading)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rt)
	var sw := Switch.new()
	sw.on = bool(App.setting(&"met_ramp"))
	sw.toggled_on.connect(func(on: bool) -> void:
		_store(&"met_ramp", on)
		_apply())
	rh.add_child(sw)
	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 12)
	rc.add_child(boxes)
	var info := _label("", 16, ThemeManager.color("hint"))
	info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var update_info := func() -> void:
		info.text = tr("Tempo rises by %d BPM every %d bars.") % [int(App.setting(&"met_ramp_step")), int(App.setting(&"met_ramp_bars"))]
	for spec in [[&"met_bpm", "From", BPM_MIN, BPM_MAX, ""], [&"met_ramp_to", "To", BPM_MIN, BPM_MAX, ""],
			[&"met_ramp_step", "Step", 1, 20, "+"]]:
		boxes.add_child(_value_box(spec[0], spec[1], spec[2], spec[3], spec[4], update_info))
	update_info.call()
	rc.add_child(info)


# --- Sterowanie ------------------------------------------------------------------

func _toggle() -> void:
	if _playing:
		_stop()
	else:
		_start()


func _start() -> void:
	_core = AudioEngine.ensure_open()
	if _core == null:
		_error.text = tr("No sound output – check the Sound and MIDI settings.") + \
				("" if AudioEngine.last_error() in ["", "core"] else "  (" + AudioEngine.last_error() + ")")
		_error.visible = true
		return
	_error.visible = false
	_apply(true)
	_core.start()
	_playing = true
	set_process(true)
	_update_play_button()


func _stop() -> void:
	if _looper:
		_looper.stop_all()
	if _playing and _core:
		_core.stop()
	_playing = false
	set_process(false)
	if _beats:
		_beats.set_active(-1)
	if _grid:
		_grid.set_step(-1)
	_update_play_button()
	_update_texts()


func _process(_delta: float) -> void:
	if _core == null:
		return
	var v: Dictionary = _core.visual_state()
	var step := int(v.step)
	if _beats:
		var sub: int = SUBS[int(App.setting(&"met_sub"))][1]
		_beats.set_active(step / sub if step >= 0 else -1)
	if _grid:
		_grid.set_step(step)
	if bool(App.setting(&"met_ramp")):
		_show_bpm(roundi(float(v.bpm)))


# Parametry do rdzenia. starting – przy starcie z przyspieszaniem tempo zaczyna się od „Od”.
func _apply(starting := false, overrides := {}) -> void:
	if _core == null or (_mode() == 2 and overrides.is_empty()):
		return
	var bpm := _bpm()
	# Z przyspieszaniem „Od” to tempo z regulatora: start od niego, dalej tempo prowadzi rdzeń.
	if starting:
		_show_bpm(bpm)
	var m := _metre()
	var g := _grid_kind()
	var mask := 0
	for a in _accents():
		mask |= 1 << a
	var flat := PackedByteArray()
	var steps := _steps(m, g)
	flat.resize(ROWS.size() * steps)
	for r in ROWS.size():
		for s in steps:
			flat[r * steps + s] = _pattern[r][s]
	_core.configure({
		"bpm": float(bpm), "mode": _mode(), "beats": BEATS[m], "accents": mask,
		"subdivision": SUBS[int(App.setting(&"met_sub"))][1], "sound": int(App.setting(&"met_sound")),
		"steps": steps, "steps_per_beat": _spq(m, g), "kit": KITS[int(App.setting(&"met_kit"))][1],
		"ramp": bool(App.setting(&"met_ramp")), "ramp_to": float(App.setting(&"met_ramp_to")),
		"ramp_step": float(App.setting(&"met_ramp_step")), "ramp_bars": int(App.setting(&"met_ramp_bars")),
	}.merged(overrides, true), flat)


func _set_bpm(bpm: int) -> void:
	bpm = clampi(bpm, BPM_MIN, BPM_MAX)
	_store(&"met_bpm", bpm)
	_show_bpm(bpm)
	if _from_edit and is_instance_valid(_from_edit):
		_from_edit.text = str(bpm)
	_apply()


func _show_bpm(bpm: int) -> void:
	if _bpm_label:
		_bpm_label.text = str(bpm)
	if _tempo_label:
		_set_tempo_text(bpm)


# Wystukiwanie tempa: od 2. stuknięcia średnia z ostatnich odstępów (do 4), po przerwie dłuższej niż 2 s – od nowa.


func _tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _taps.is_empty() and now - _taps[-1] > 2.0:
		_taps.clear()
	_taps.append(now)
	if _taps.size() > 5:
		_taps.remove_at(0)
	if _taps.size() >= 2:
		var span := (_taps[-1] - _taps[0]) / (_taps.size() - 1)
		_set_bpm(roundi(60.0 / span))


func _preset(i: int) -> void:
	_stop()
	var cfg: Array = [[2, 0], [2, 2], [2, 1], [1, 0], [3, 0]][i]
	App.set_settings({&"met_metre": cfg[0], &"met_grid": cfg[1], &"met_preset": i})
	_pattern = _preset_pattern(i)
	_save_pattern()
	_rebuild()


func _preset_pattern(i: int) -> Array:
	var cfg: Array = [[2, 0], [2, 2], [2, 1], [1, 0], [3, 0]][i]
	var out := _empty(_steps(cfg[0], cfg[1]))
	var cells := _preset_cells(i)
	for key in cells:
		var p: PackedStringArray = (key as String).split(",")
		out[int(p[0])][int(p[1])] = cells[key]
	return out


# „Przywróć wzorzec”: siatka ostatnio wybranego wzorca, a po zmianie metrum lub siatki – rytm podstawowy.
# Gra nie zostaje przerwana.
func _restore_pattern() -> void:
	var i := int(App.setting(&"met_preset"))
	var cfg: Array = [[2, 0], [2, 2], [2, 1], [1, 0], [3, 0]][i] if i >= 0 else []
	if i >= 0 and cfg[0] == _metre() and cfg[1] == _grid_kind():
		_pattern = _preset_pattern(i)
	else:
		_pattern = _basic(_metre(), _grid_kind())
	_save_pattern()
	_rebuild()


# --- Teksty -------------------------------------------------------------------------

func _update_texts() -> void:
	if _subtitle == null:
		return
	var second: String
	if _looper:
		second = _looper.summary()
	elif _mode() == 1:
		second = tr("%s kit, MIDI") % KITS[int(App.setting(&"met_kit"))][0]
	else:
		second = tr(SUBS[int(App.setting(&"met_sub"))][0])
	_subtitle.text = tr("metre %s") % METRES[_metre()] + " · " + second
	_show_bpm(_bpm())


func _update_play_button() -> void:
	if _play == null:
		return
	_play.text = tr("Stop") if _playing else tr("Run")
	var bg: Color = STOP if _playing else ThemeManager.color("accent")
	var dark := ThemeManager.color("accent_text")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_play.add_theme_color_override(c, dark)
	_play.add_theme_stylebox_override("normal", ThemeManager.box(bg, Color.TRANSPARENT, 14, 0, 40, 10))
	_play.add_theme_stylebox_override("hover", ThemeManager.box(bg.lightened(0.1), Color.TRANSPARENT, 14, 0, 40, 10))
	_play.add_theme_stylebox_override("pressed", ThemeManager.box(bg.darkened(0.1), Color.TRANSPARENT, 14, 0, 40, 10))


func _set_tempo_text(bpm: int) -> void:
	var name := ""
	for t in TEMPO_NAMES:
		if bpm < t[0]:
			name = t[1]
			break
	_tempo_label.text = "%s · [color=#%s][i]%s[/i][/color]" % [
			_tempo_label.get_meta(&"prefix"), ThemeManager.color("accent").to_html(false), name]


func _steps_text(n: int) -> String:
	var lang := TranslationServer.get_locale().substr(0, 2)
	match lang:
		"pl":
			return "%d %s" % [n, "krok" if n == 1 else "kroki" if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14] else "kroków"]
		"ru":
			return "%d %s" % [n, "шаг" if n % 10 == 1 and n % 100 != 11 else "шага" if n % 10 in [2, 3, 4] and not n % 100 in [12, 13, 14] else "шагов"]
		"de":
			return "%d Schritte" % n
		"es":
			return "%d pasos" % n
	return "%d steps" % n


# --- Model rytmu (jak w makiecie) ----------------------------------------------------

func _mode() -> int:
	return int(App.setting(&"met_mode"))


func _metre() -> int:
	return clampi(int(App.setting(&"met_metre")), 0, METRES.size() - 1)


func _grid_kind() -> int:
	var g := clampi(int(App.setting(&"met_grid")), 0, 2)
	return 0 if g == 1 and _metre() >= 3 else g


func _bpm() -> int:
	return clampi(int(App.setting(&"met_bpm")), BPM_MIN, BPM_MAX)


static func _eighth(m: int) -> bool:
	return m >= 3


# Kroki na uderzenie: w metrum ósemkowym uderzeniem jest ósemka.
static func _spq(m: int, g: int) -> int:
	return [1, 1, 2][g] if _eighth(m) else [2, 3, 4][g]


static func _steps(m: int, g: int) -> int:
	return BEATS[m] * _spq(m, g)


# Początki grup (akcentowane uderzenia): 6/8 – 1 i 4, 7/8 – 1, 3 i 5, pozostałe – każde uderzenie.
static func _groups(m: int, g: int) -> Array:
	var k := _spq(m, g)
	if m == 3:
		return [0, 3 * k]
	if m == 4:
		return [0, 2 * k, 4 * k]
	var out := []
	for i in BEATS[m]:
		out.append(i * k)
	return out


func _accents() -> Array:
	var m := _metre()
	return [0, 3] if m == 3 else [0, 2, 4] if m == 4 else [0]


static func _empty(steps: int) -> Array:
	var p := []
	for r in ROWS.size():
		var row := []
		row.resize(steps)
		row.fill(0)
		p.append(row)
	return p


# Podstawowy rytm dla metrum i siatki: stopa i werbel na zmianę na początkach grup, hi-hat, crash na „raz”.
static func _basic(m: int, g: int) -> Array:
	var n := _steps(m, g)
	var groups := _groups(m, g)
	var k := _spq(m, g)
	var p := _empty(n)
	p[5][0] = 1
	p[0][0] = 2
	for i in groups.size():
		p[4 if i % 2 else 5][groups[i]] = 1
	var hh := k if _eighth(m) else maxi(1, k / 2)
	if g == 1 and not _eighth(m):
		hh = 1
	var s := 0
	while s < n:
		p[3][s] = 2 if s in groups else 1
		s += hh
	return p


static func _preset_cells(i: int) -> Dictionary:
	return [
		{"0,0": 2, "3,0": 2, "3,1": 1, "3,2": 2, "3,3": 1, "3,4": 2, "3,5": 1, "3,6": 2, "3,7": 1, "4,2": 2, "4,6": 2, "5,0": 2, "5,4": 1, "5,5": 1},
		{"3,0": 2, "3,2": 1, "3,4": 2, "3,6": 1, "3,8": 2, "3,10": 1, "3,12": 2, "2,14": 1, "4,4": 2, "4,12": 2, "5,0": 2, "5,7": 1, "5,8": 2},
		{"1,0": 2, "1,2": 1, "1,3": 1, "1,5": 1, "1,6": 2, "1,8": 1, "1,9": 1, "1,11": 1, "4,3": 2, "4,9": 2, "5,0": 2, "5,6": 1},
		{"3,0": 2, "3,2": 1, "3,4": 1, "4,2": 1, "4,4": 1, "5,0": 2},
		{"1,0": 2, "1,1": 1, "1,2": 1, "1,3": 2, "1,4": 1, "1,5": 1, "4,3": 2, "5,0": 2, "5,5": 1},
	][i]


func _count_labels() -> Array:
	var m := _metre()
	var g := _grid_kind()
	var k := _spq(m, g)
	var out := []
	for s in _steps(m, g):
		if s % k == 0:
			out.append([str(s / k + 1), true])
		elif _eighth(m) or g == 1:
			out.append(["·", false])
		elif g == 0:
			out.append([tr("&"), false])
		else:
			out.append([["", tr("e"), tr("&"), tr("a")][s % 4], false])
	return out


func _load_pattern() -> Array:
	var steps := _steps(_metre(), _grid_kind())
	var raw := str(App.setting(&"met_pattern"))
	if raw.length() != ROWS.size() * steps:
		if _metre() == 2 and _grid_kind() == 0:   # pierwsze uruchomienie: wzorzec „Rock” (jak w makiecie)
			return _preset_pattern(0)
		return _basic(_metre(), _grid_kind())
	var p := _empty(steps)
	for r in ROWS.size():
		for s in steps:
			p[r][s] = clampi(int(raw[r * steps + s]), 0, 2)
	return p


func _save_pattern() -> void:
	var raw := ""
	for row in _pattern:
		for v in row:
			raw += str(v)
	_store(&"met_pattern", raw)


func _store(key: StringName, value: Variant) -> void:
	App.set_setting(key, value)


# --- Elementy -----------------------------------------------------------------------

func _label(text: String, px: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", ThemeManager.fs(px))
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _rich_tempo(px: int, prefix: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta(&"prefix", prefix)
	r.add_theme_font_size_override("normal_font_size", ThemeManager.fs(px))
	r.add_theme_font_size_override("italics_font_size", ThemeManager.fs(px))
	var italic := FontVariation.new()   # kursywa pochylona (czcionki interfejsu nie mają odmiany italic)
	italic.base_font = ThemeManager.font_body
	italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	r.add_theme_font_override("italics_font", italic)
	r.add_theme_color_override("default_color", ThemeManager.color("muted"))
	return r


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _round_button(text: String, step: int, d: int, px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(d, d)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_size_override("font_size", ThemeManager.fs(px))
	for state in ["normal", "hover", "pressed"]:
		var bg: Color = ThemeManager.color("surface_2") if state == "normal" else ThemeManager.color("border")
		b.add_theme_stylebox_override(state, ThemeManager.box(bg, ThemeManager.color("border_strong"), d / 2, 1, 0, 0))
	b.pressed.connect(func() -> void: _set_bpm(_bpm() + step))
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
		b.add_theme_font_size_override("font_size", ThemeManager.fs(16))
		var bg: Color = ThemeManager.color("border_strong") if on else Color.TRANSPARENT
		b.add_theme_stylebox_override("normal", ThemeManager.box(bg, Color.TRANSPARENT, 10, 0, 17, 9))
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border_strong") if on else ThemeManager.color("border"), Color.TRANSPARENT, 9, 0, 16, 7))
		b.add_theme_stylebox_override("pressed", ThemeManager.box(ThemeManager.color("border_strong"), Color.TRANSPARENT, 9, 0, 16, 7))
		b.add_theme_color_override("font_color", ThemeManager.color("text") if on else ThemeManager.color("muted"))
		if not on:
			b.pressed.connect(on_pick.bind(it[0]))
		row.add_child(b)
	return frame


func _chip(text: String, on: bool, small := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 36 if small else 43
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", ThemeManager.font_body_bold)
	b.add_theme_font_size_override("font_size", ThemeManager.fs(14 if small else 16))
	_style_chip(b, on, small)
	return b


func _style_chip(b: Button, on: bool, small: bool) -> void:
	var pad := 13 if small else 17
	var off := ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border_strong"), 8 if small else 10, 1, pad, 4)
	var sel := ThemeManager.box(Color(ThemeManager.color("focus"), 0.12), ThemeManager.color("focus"), 8 if small else 10, 1, pad, 4)
	b.add_theme_stylebox_override("normal", sel if on else off)
	b.add_theme_stylebox_override("hover", sel if on else ThemeManager.box(ThemeManager.color("border"), ThemeManager.color("border_strong"), 8 if small else 10, 1, pad, 4))
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("disabled", ThemeManager.box(Color(ThemeManager.color("surface_2"), 0.35), Color(ThemeManager.color("border_strong"), 0.35), 8 if small else 10, 1, pad, 4))
	if on:
		b.add_theme_color_override("font_color", ThemeManager.color("focus"))
		b.add_theme_color_override("font_hover_color", ThemeManager.color("focus"))
	else:
		b.remove_theme_color_override("font_color")
		b.remove_theme_color_override("font_hover_color")


func _chips_row(labels: Array, current: int, translate: bool, on_pick: Callable, small := false) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 7)
	row.add_theme_constant_override("v_separation", 7)
	for i in labels.size():
		var b := _chip(labels[i], i == current, small)
		if not translate:
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(func() -> void:
			# Podświetlenie wybranego od razu – także tam, gdzie wybór nie przebudowuje ekranu.
			for k in row.get_child_count():
				_style_chip(row.get_child(k) as Button, k == i, small)
			on_pick.call(i))
		row.add_child(b)
	return row


func _field(title: String, control: Control) -> VBoxContainer:
	var f := VBoxContainer.new()
	f.add_theme_constant_override("separation", 10)
	f.add_child(_label(title, 16, ThemeManager.color("muted")))
	f.add_child(control)
	return f


func _aside_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("border"), 24))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 19)
	card.add_child(col)
	_aside.add_child(card)
	return card


func _legend_item(color: Color, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var sw := Panel.new()
	sw.custom_minimum_size = Vector2(11, 11)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.add_theme_stylebox_override("panel", ThemeManager.box(color, Color.TRANSPARENT, 3, 0, 0, 0))
	h.add_child(sw)
	h.add_child(_label(text, 16, ThemeManager.color("hint")))
	return h


# Pole „Od / Do / Krok”: podpis i wartość do wpisania (Enter lub wyjście z pola zapisuje).
func _value_box(key: StringName, title: String, lo: int, hi: int, prefix: String, on_change: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("surface_2"), Color.TRANSPARENT, 12, 0, 14, 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	p.add_child(col)
	col.add_child(_label(title, 14, ThemeManager.color("hint")))
	var e := LineEdit.new()
	e.text = prefix + str(int(App.setting(key)))
	e.flat = true
	e.max_length = 4
	e.add_theme_font_override("font", ThemeManager.font_body_bold)
	e.add_theme_font_size_override("font_size", ThemeManager.fs(22))
	e.add_theme_constant_override("minimum_character_width", 3)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(s, empty)
	if key == &"met_bpm":
		_from_edit = e
	var commit := func() -> void:
		var v := clampi(int(e.text.replace("+", "")), lo, hi)
		e.text = prefix + str(v)
		if key == &"met_bpm":
			_set_bpm(v)
			return
		_store(key, v)
		on_change.call()
		_apply()
	e.text_submitted.connect(func(_t: String) -> void:
		commit.call()
		e.release_focus())
	e.focus_exited.connect(commit)
	col.add_child(e)
	return p


# --- Kontrolki rysowane (jeden węzeł zamiast wielu – mniej wywołań rysowania) ------------

## Światełka uderzeń metronomu klasycznego: akcentowane większe, w kolorze akcentu.
class BeatLights extends Control:
	var count := 4
	var accents: Array = [0]
	var accent := Color.ORANGE
	var active := -1

	func setup(p_count: int, p_accents: Array, p_accent: Color) -> void:
		count = p_count
		accents = p_accents
		accent = p_accent
		custom_minimum_size = Vector2(count * 55 + (count - 1) * 22 + 50, 100)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func set_active(i: int) -> void:
		if i != active:
			active = i
			queue_redraw()

	func _draw() -> void:
		var x := (size.x - (count * 55 + (count - 1) * 22)) * 0.5
		var cy := size.y * 0.5
		var teal := ThemeManager.color("focus")
		for i in count:
			var acc: bool = i in accents
			var r := 27.5 if acc else 21.5
			var c := Vector2(x + 27.5, cy)
			var col: Color = accent if acc else teal
			if i == active:
				for g in 6:   # poświata
					draw_circle(c, r + 4.0 + g * 3.0, Color(col, 0.10 - g * 0.015))
				draw_circle(c, r, col)
			else:
				draw_circle(c, r, ThemeManager.color("border"))
				draw_arc(c, r - 1.0, 0.0, TAU, 48, col, 2.5, true)
			x += 55.0 + 22.0


## Siatka automatu perkusyjnego: nazwy instrumentów, kratki kroków (klik: uderzenie → akcent → pusto)
## i liczenie pod spodem. Grupy (uderzenia) oddzielone szerszą przerwą.
class DrumGrid extends Control:
	signal changed

	const NAME_W := 228.0
	const CELL_H := 62.0
	const GAP := 5.0
	const GROUP_GAP := 10.0
	const ROW_GAP := 12.0
	var names: Array = []
	var pattern: Array = []
	var groups: Array = []
	var counts: Array = []
	var accent := Color.ORANGE
	var step := -1

	func setup(p_names: Array, p_pattern: Array, p_groups: Array, p_counts: Array, p_accent: Color) -> void:
		names = p_names
		pattern = p_pattern
		groups = p_groups
		counts = p_counts
		accent = p_accent
		custom_minimum_size.y = names.size() * (CELL_H + ROW_GAP) + 26.0
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		queue_redraw()

	func set_step(s: int) -> void:
		if s != step:
			step = s
			queue_redraw()

	func _cell_w() -> float:
		var n := counts.size()
		return minf(62.0, floorf((size.x - NAME_W - n * GAP - groups.size() * GROUP_GAP) / n))

	func _cell_x(s: int) -> float:
		var x := NAME_W
		var w := _cell_w()
		for i in s:
			x += w + GAP
			if i + 1 in groups:
				x += GROUP_GAP
		return x

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var r := int(mb.position.y / (CELL_H + ROW_GAP))
		if r < 0 or r >= names.size() or fmod(mb.position.y, CELL_H + ROW_GAP) > CELL_H:
			return
		var w := _cell_w()
		for s in counts.size():
			var x := _cell_x(s)
			if mb.position.x >= x and mb.position.x <= x + w:
				pattern[r][s] = (int(pattern[r][s]) + 1) % 3
				queue_redraw()
				changed.emit()
				accept_event()
				return

	func _draw() -> void:
		var font := ThemeManager.font_body_bold
		var small := ThemeManager.font_body
		var fs := ThemeManager.fs(17)
		var w := _cell_w()
		var y := 0.0
		for r in names.size():
			var base := y + CELL_H * 0.5 + fs * 0.35
			draw_string(font, Vector2(0, base), names[r][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ThemeManager.color("text"))
			var nw := font.get_string_size(names[r][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(small, Vector2(nw + 6, base), names[r][1], HORIZONTAL_ALIGNMENT_LEFT, -1, ThemeManager.fs(13), ThemeManager.color("faint"))
			for s in counts.size():
				var v := int(pattern[r][s])
				var rect := Rect2(_cell_x(s), y, w, CELL_H)
				var bg: Color = accent if v == 2 else ThemeManager.color("focus") if v == 1 else (ThemeManager.color("cell_group") if s in groups else ThemeManager.color("surface_2"))
				var cur := s == step
				var border: Color = ThemeManager.color("text") if cur else (Color.TRANSPARENT if v else ThemeManager.color("border_strong"))
				draw_style_box(ThemeManager.box(bg, border, 8, 1, 0, 0), rect)
				if cur and v:
					draw_style_box(ThemeManager.box(Color(1, 1, 1, 0.18), Color.TRANSPARENT, 7, 0, 0, 0), rect.grow(3))
			y += CELL_H + ROW_GAP
		for s in counts.size():
			var c: Array = counts[s]
			var col: Color = ThemeManager.color("text") if s == step else (ThemeManager.color("muted") if c[1] else ThemeManager.color("dim"))
			draw_string(font if c[1] else small, Vector2(_cell_x(s), y + 16), c[0], HORIZONTAL_ALIGNMENT_CENTER, w,
					ThemeManager.fs(14), col)


## Przełącznik (włącz/wyłącz) jak w makiecie.
class Switch extends Control:
	signal toggled_on(on: bool)
	var on := false

	func _init() -> void:
		custom_minimum_size = Vector2(58, 34)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on = not on
			queue_redraw()
			toggled_on.emit(on)
			accept_event()

	func _draw() -> void:
		var track: Color = ThemeManager.color("focus") if on else ThemeManager.color("border_strong")
		draw_style_box(ThemeManager.box(track, Color.TRANSPARENT, 17, 0, 0, 0), Rect2(Vector2.ZERO, size))
		draw_circle(Vector2(size.x - 17.0 if on else 17.0, size.y * 0.5), 13.0, Color.WHITE)
