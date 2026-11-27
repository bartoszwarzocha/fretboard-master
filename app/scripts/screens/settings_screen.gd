# Fretboard Master – okno konfiguracji: zakładki po lewej, treść po prawej. Każda zmiana działa
# od razu (podgląd na żywo) i trafia do pliku ustawień; „Przywróć domyślne” przywraca jedną zakładkę.
# Zakładka jest budowana od nowa tylko wtedy, gdy zmiana pokazuje lub ukrywa inne pola
# (np. tryb tła) – zwykła zmiana wartości niczego nie przebudowuje.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends ModuleScreen

const LANGUAGE_NAMES := {"": "System language", "en": "English", "pl": "Polski", "de": "Deutsch",
		"es": "Español", "ru": "Русский"}
const TABS := [
	[&"general", "General"], [&"look", "Appearance"], [&"guitar", "Guitar"], [&"audio", "Audio"],
	[&"midi", "MIDI"], [&"graphics", "Graphics"],
]
# Zmiana tych ustawień pokazuje lub ukrywa inne pola – zakładka jest wtedy budowana od nowa.
const REBUILD_KEYS := [&"theme", &"accent", &"bg_mode", &"bg_gradient_type", &"bg_animated", &"particles", &"hit_particles", &"window_mode", &"neck_view",
		&"quality", &"power_saving", &"logo_spin", &"animations", &"midi_output"]
# Widoki gryfu: realistyczne 3D (trzy rodzaje gitar) i schematyczne (jak w pierwotnej makiecie).
# Rysowanie powstanie razem z modułem gryfu; tu tylko wybór. Kolejne widoki – nowa pozycja listy.
const NECK_VIEWS := [
	["classical_3d", "Classical guitar (3D)"], ["acoustic_3d", "Acoustic guitar (3D)"],
	["electric_3d", "Electric guitar (3D)"], ["table", "Diagram – drawn table"],
	["grid", "Diagram – right angles"], ["neck_shape", "Diagram – neck shape"],
]
const BG_PALETTE := ["0B0F1E", "1D2A55", "2B1B3D", "123B3A", "3A2414", "1A1A1A", "4A4F5C"]
const QUALITY_KEYS := [&"msaa", &"render_scale", &"anisotropy", &"shadows", &"reflections"]
const TUNINGS := [
	["standard", "Standard (E A D G B E)"], ["drop_d", "Drop D (D A D G B E)"],
	["half_down", "Half step down (E♭ A♭ D♭ G♭ B♭ E♭)"], ["full_down", "Whole step down (D G C F A D)"],
	["drop_c", "Drop C (C G C F A D)"], ["dadgad", "DADGAD"], ["open_g", "Open G (D G D G B D)"],
	["open_d", "Open D (D A D F♯ A D)"], ["open_e", "Open E (E B E G♯ B E)"],
]
const GM_INSTRUMENTS := ["Acoustic Grand Piano", "Bright Acoustic Piano", "Electric Grand Piano",
	"Honky-tonk Piano", "Electric Piano 1", "Electric Piano 2", "Harpsichord", "Clavinet", "Celesta",
	"Glockenspiel", "Music Box", "Vibraphone", "Marimba", "Xylophone", "Tubular Bells", "Dulcimer",
	"Drawbar Organ", "Percussive Organ", "Rock Organ", "Church Organ", "Reed Organ", "Accordion",
	"Harmonica", "Tango Accordion", "Acoustic Guitar (nylon)", "Acoustic Guitar (steel)",
	"Electric Guitar (jazz)", "Electric Guitar (clean)", "Electric Guitar (muted)", "Overdriven Guitar",
	"Distortion Guitar", "Guitar Harmonics", "Acoustic Bass", "Electric Bass (finger)",
	"Electric Bass (pick)", "Fretless Bass", "Slap Bass 1", "Slap Bass 2", "Synth Bass 1", "Synth Bass 2",
	"Violin", "Viola", "Cello", "Contrabass", "Tremolo Strings", "Pizzicato Strings", "Orchestral Harp",
	"Timpani", "String Ensemble 1", "String Ensemble 2", "Synth Strings 1", "Synth Strings 2",
	"Choir Aahs", "Voice Oohs", "Synth Voice", "Orchestra Hit", "Trumpet", "Trombone", "Tuba",
	"Muted Trumpet", "French Horn", "Brass Section", "Synth Brass 1", "Synth Brass 2", "Soprano Sax",
	"Alto Sax", "Tenor Sax", "Baritone Sax", "Oboe", "English Horn", "Bassoon", "Clarinet", "Piccolo",
	"Flute", "Recorder", "Pan Flute", "Blown Bottle", "Shakuhachi", "Whistle", "Ocarina",
	"Lead 1 (square)", "Lead 2 (sawtooth)", "Lead 3 (calliope)", "Lead 4 (chiff)", "Lead 5 (charang)",
	"Lead 6 (voice)", "Lead 7 (fifths)", "Lead 8 (bass + lead)", "Pad 1 (new age)", "Pad 2 (warm)",
	"Pad 3 (polysynth)", "Pad 4 (choir)", "Pad 5 (bowed)", "Pad 6 (metallic)", "Pad 7 (halo)",
	"Pad 8 (sweep)", "FX 1 (rain)", "FX 2 (soundtrack)", "FX 3 (crystal)", "FX 4 (atmosphere)",
	"FX 5 (brightness)", "FX 6 (goblins)", "FX 7 (echoes)", "FX 8 (sci-fi)", "Sitar", "Banjo",
	"Shamisen", "Koto", "Kalimba", "Bagpipe", "Fiddle", "Shanai", "Tinkle Bell", "Agogo", "Steel Drums",
	"Woodblock", "Taiko Drum", "Melodic Tom", "Synth Drum", "Reverse Cymbal", "Guitar Fret Noise",
	"Breath Noise", "Seashore", "Bird Tweet", "Telephone Ring", "Helicopter", "Applause", "Gunshot"]

var _tab: StringName = &"general"
var _tab_buttons := {}
var _title: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _sample: Label
var _rebuild_pending := false


func _init() -> void:
	module_id = &"settings"


func _build_content() -> void:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	content.add_child(body)

	# Zakładki
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 230
	side.add_theme_constant_override("separation", 4)
	body.add_child(side)
	var heading := Label.new()
	heading.text = "Settings"
	heading.theme_type_variation = &"Heading"
	side.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	side.add_child(gap)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.theme_type_variation = &"SideTab"
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.button_pressed = t[0] == _tab
		b.pressed.connect(_select_tab.bind(t[0]))
		side.add_child(b)
		_tab_buttons[t[0]] = b

	# Treść zakładki
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.theme_type_variation = &"Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var reset := Button.new()
	reset.text = "Restore defaults"
	reset.pressed.connect(func() -> void:
		App.reset_group(_tab)
		if _tab == &"graphics":
			Graphics.apply_quality(str(App.setting(&"quality")))
		_rebuild())
	head.add_child(reset)
	col.add_child(HSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	App.settings_changed.connect(_on_setting)
	_rebuild()


func _select_tab(tab: StringName) -> void:
	_tab = tab
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).set_pressed_no_signal(t == tab)
	_rebuild()
	_scroll.scroll_vertical = 0


func _on_setting(key: StringName) -> void:
	if key in REBUILD_KEYS and not _rebuild_pending:
		_rebuild_pending = true
		_rebuild.call_deferred()


# Zakładka od nowa (zachowuje położenie przewinięcia).
func _rebuild() -> void:
	_rebuild_pending = false
	var keep := _scroll.scroll_vertical
	if _rows:
		_rows.queue_free()
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 14)
	_scroll.add_child(_rows)
	for t in TABS:
		if t[0] == _tab:
			_title.text = t[1]
	_sample = null
	match _tab:
		&"general": _build_general()
		&"look": _build_look()
		&"guitar": _build_guitar()
		&"audio": _build_audio()
		&"midi": _build_midi()
		&"graphics": _build_graphics()
	var pad := Control.new()
	pad.custom_minimum_size.y = 8
	_rows.add_child(pad)
	(func() -> void: _scroll.scroll_vertical = keep).call_deferred()


# --- Zakładki -----------------------------------------------------------------

func _build_general() -> void:
	_section("Language")
	var langs := []
	for code in App.LANGUAGES:
		langs.append([code, LANGUAGE_NAMES[code]])
	var lang := _select(&"language", "Interface language", langs, false)
	lang.set_item_auto_translate_mode(0, Node.AUTO_TRANSLATE_MODE_ALWAYS)
	var notation := []
	for i in NoteNames.NOTATION_LABELS.size():
		notation.append([i, NoteNames.NOTATION_LABELS[i]])
	_select(&"notation", "Note names", notation).item_selected.connect(func(_i: int) -> void: _update_sample())
	_sample = Label.new()
	_sample.theme_type_variation = &"Muted"
	_sample.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_row("", _sample)
	_update_sample()

	_section("Start")
	var screens := [["menu", "Main menu"], ["last", "Last opened screen"]]
	for m in App.MODULES:
		screens.append([String(m.id), m.name])
	_select(&"start_screen", "After start-up open", screens)


func _build_look() -> void:
	_section("Theme")
	_select(&"theme", "Colour theme", [["auto", "Automatic (as in the system)"], ["night", "Night"],
			["graphite", "Graphite"], ["light", "Light"]])
	_colors(&"accent", "Accent colour", "Theme colour")

	_section("Background")
	var mode := str(App.setting(&"bg_mode"))
	_select(&"bg_mode", "Background", [["solid", "Solid colour"], ["gradient", "Gradient"],
			["pattern", "Pattern"], ["image", "Own image"]])
	match mode:
		"solid":
			_colors(&"bg_color", "Colour", "Theme colour", BG_PALETTE)
		"gradient":
			var kind := str(App.setting(&"bg_gradient_type"))
			_select(&"bg_gradient_type", "Gradient type", [["linear", "Linear"], ["radial", "Radial"],
					["conic", "Angular"]])
			_colors(&"bg_color", "First colour", "Theme colour", BG_PALETTE)
			_colors(&"bg_color3", "Middle colour", "None", BG_PALETTE)
			_colors(&"bg_color2", "Last colour", "", BG_PALETTE)
			if kind != "radial":
				_slider(&"bg_gradient_angle", "Direction", 0, 360, 5, "%d°")
			if kind != "linear":
				_slider(&"bg_gradient_x", "Centre – horizontally", 0, 1, 0.05, "%")
				_slider(&"bg_gradient_y", "Centre – vertically", 0, 1, 0.05, "%")
		"pattern":
			_select(&"bg_pattern", "Pattern", [["wood", "Wood"], ["carbon", "Carbon"], ["leather", "Leather"],
					["felt", "Felt"], ["notes", "Notes"], ["hex", "Geometric"]])
			_colors(&"bg_color", "Base colour", "Theme colour", BG_PALETTE)
			_colors(&"bg_color2", "Pattern colour", "", BG_PALETTE)
			_slider(&"bg_intensity", "Pattern intensity", 0, 1, 0.05, "%")
			_slider(&"bg_scale", "Pattern scale", 0.5, 3, 0.1, "×")
		"image":
			_image_picker()
			_slider(&"bg_blur", "Blur", 0, 1, 0.05, "%")
	_slider(&"bg_dim", "Dim", 0, 0.9, 0.05, "%")
	if mode != "solid":
		_toggle(&"bg_animated", "Animated background")
		if bool(App.setting(&"bg_animated")):
			_slider(&"bg_anim_speed", "Animation speed", 0.2, 3, 0.1, "×")

	_section("Background particles")
	_select(&"particles", "Particles", [["off", "Off"], ["dust", "Dust"], ["sparks", "Sparks"],
			["notes", "Floating notes"], ["bokeh", "Bokeh"]])
	if str(App.setting(&"particles")) != "off":
		_slider(&"particles_density", "Density", 0, 1, 0.05, "%")
		_slider(&"particles_speed", "Speed", 0.2, 3, 0.1, "×")
		_colors(&"particles_color", "Colour", "Accent colour")

	_section("Played note effect")
	_toggle(&"hit_particles", "Effect when you hit the note")
	if bool(App.setting(&"hit_particles")):
		_select(&"hit_style", "Effect", [["sparks", "Sparks"], ["notes", "Notes"], ["glow", "Glow"]])
		var test := Button.new()
		test.text = "Try it"
		test.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		test.pressed.connect(func() -> void:
			Backdrop.burst(test.get_global_rect().get_center()))
		_row("", test)

	_section("Panels and tiles")
	_slider(&"panel_opacity", "Opacity", 0.3, 1, 0.05, "%")
	_slider(&"panel_radius", "Corner rounding", 0, 32, 1, "%d px")
	_slider(&"panel_shadow", "Shadow", 0, 24, 1, "%d px")
	_slider(&"font_scale", "Text size", 0.85, 1.3, 0.05, "%")


func _build_guitar() -> void:
	_section("Instrument")
	_select(&"tuning", "Tuning", TUNINGS)
	_select(&"strings", "Strings", [[6, "6"], [7, "7"], [8, "8"]], false)
	_select(&"frets", "Frets", [[19, "19"], [20, "20"], [21, "21"], [22, "22"], [24, "24"]], false)
	_toggle(&"left_handed", "Left-handed")
	_slider(&"a4", "Concert pitch (A4)", 415, 466, 1, "%d Hz")

	_section("Fretboard look")
	_select(&"neck_view", "Fretboard view", NECK_VIEWS)
	# Drewno, progi i struny dotyczą tylko realistycznych widoków 3D; markery – wszystkich widoków.
	if str(App.setting(&"neck_view")).ends_with("_3d"):
		_select(&"fretboard_wood", "Fretboard wood", [["rosewood", "Rosewood"], ["maple", "Maple"],
				["ebony", "Ebony"]])
		_select(&"fret_metal", "Frets", [["nickel", "Nickel"], ["stainless", "Stainless steel"], ["gold", "Gold"]])
		_select(&"string_color", "Strings", [["nickel", "Nickel"], ["bronze", "Bronze"], ["black", "Black"]])
	_select(&"inlays", "Inlays", [["dots", "Dots"], ["blocks", "Blocks"], ["trapezoids", "Trapezoids"],
			["none", "None"]])


func _build_audio() -> void:
	_section("Devices")
	_select(&"audio_input", "Input (guitar)", _devices(AudioServer.get_input_device_list()), false)
	_select(&"input_channel", "Input channel", [[0, "Left"], [1, "Right"], [2, "Both (mono)"]])
	_select(&"audio_output", "Output", _devices(AudioServer.get_output_device_list()), false)

	_section("Latency")
	_select(&"buffer_ms", "Buffer", [[3, "3 ms"], [5, "5 ms"], [10, "10 ms"], [20, "20 ms"], [40, "40 ms"]], false)
	_slider(&"latency_comp_ms", "Latency compensation", -100, 100, 1, "%d ms")

	_section("Recognition")
	_slider(&"sensitivity", "Sensitivity", 0, 1, 0.05, "%")
	_slider(&"noise_gate_db", "Noise gate", -90, -20, 1, "%d dB")
	_toggle(&"input_monitor", "Input monitoring (headphones)")
	_slider(&"master_volume", "Program volume", 0, 1, 0.05, "%")


func _build_midi() -> void:
	_section("Devices")
	var outputs := [["internal", "Built-in synthesizer"]]
	_select(&"midi_output", "Output", outputs)
	# Wejścia MIDI obsłuży rdzeń C++ (PortMidi). Wbudowane MIDI Godota (OS.open_midi_inputs)
	# zawieszało program na Windows przy otwarciu tej zakładki – nie jest tu używane.
	var inputs := [["", tr("None")]]
	var saved := str(App.setting(&"midi_input"))
	if not saved.is_empty():
		inputs.append([saved, saved])
	_select(&"midi_input", "Input (MIDI guitar, keyboard)", inputs, false)

	_section("Sound")
	var instruments := []
	for i in GM_INSTRUMENTS.size():
		instruments.append([i, "%d. %s" % [i + 1, GM_INSTRUMENTS[i]]])
	_select(&"midi_instrument", "Instrument", instruments, false)
	_slider(&"midi_volume", "Volume", 0, 1, 0.05, "%")
	_slider(&"midi_reverb", "Reverb", 0, 1, 0.05, "%")
	_slider(&"midi_velocity", "Velocity", 1, 127, 1, "%d")


func _build_graphics() -> void:
	_section("Window")
	var mode := str(App.setting(&"window_mode"))
	_select(&"window_mode", "Display mode", [["windowed", "Window"], ["maximized", "Maximized window"],
			["fullscreen", "Full screen"], ["exclusive", "Exclusive full screen"]])
	if mode == "windowed":
		var res := []
		for r in Graphics.resolutions():
			res.append([r, r.replace("x", " × ")])
		_select(&"resolution", "Window size", res, false)
	var monitors := [[-1, tr("Automatic")]]
	for i in DisplayServer.get_screen_count():
		var s := DisplayServer.screen_get_size(i)
		monitors.append([i, "%s %d (%d × %d)" % [tr("Monitor"), i + 1, s.x, s.y]])
	_select(&"monitor", "Monitor", monitors, false)
	_slider(&"ui_scale", "Interface scale", 0.75, 1.5, 0.05, "%")

	_section("Frame rate")
	_select(&"vsync", "V-Sync", [["on", "On"], ["adaptive", "Adaptive"], ["off", "Off"]])
	_select(&"max_fps", "Frame limit", [[0, "No limit"], [30, "30"], [60, "60"], [75, "75"], [120, "120"],
			[144, "144"], [165, "165"], [240, "240"]])
	_toggle(&"power_saving", "Power saving (redraw only on change)")
	if bool(App.setting(&"power_saving")):
		_select(&"background_fps", "Frames in the background", [[5, "5"], [10, "10"], [15, "15"], [30, "30"]], false)
	_toggle(&"perf_info", "Show performance data (F3)")

	_section("3D quality")
	_select(&"quality", "Quality profile", [["low", "Low"], ["medium", "Medium"], ["high", "High"],
			["ultra", "Ultra"], ["custom", "Custom"]]).item_selected.connect(func(i: int) -> void:
		var preset := ["low", "medium", "high", "ultra", "custom"][i] as String
		if preset != "custom":
			Graphics.apply_quality(preset))
	_select(&"msaa", "Anti-aliasing (MSAA)", [[0, "Off"], [2, "2×"], [4, "4×"], [8, "8×"]], false)
	_slider(&"render_scale", "3D render scale", 0.5, 1, 0.05, "%")
	_select(&"anisotropy", "Anisotropic filtering", [[0, "Off"], [2, "2×"], [4, "4×"], [8, "8×"], [16, "16×"]], false)
	_select(&"shadows", "Shadows", [["off", "Off"], ["low", "Low"], ["medium", "Medium"], ["high", "High"]])
	_toggle(&"reflections", "Reflections of the surroundings")

	_section("Picture")
	_slider(&"brightness", "Brightness", 0.5, 1.5, 0.05, "%")
	_slider(&"contrast", "Contrast", 0.5, 1.5, 0.05, "%")
	_slider(&"gamma", "Gamma", 0.6, 1.8, 0.05, "×")

	_section("Animations")
	_select(&"animations", "Interface animations", [["full", "Full"], ["reduced", "Reduced"], ["off", "Off"]])
	if App.animations() != "off":
		_slider(&"anim_speed", "Animation speed", 0.5, 2, 0.1, "×")
		_toggle(&"logo_spin", "Random logo spin")
		if bool(App.setting(&"logo_spin")):
			_select(&"logo_spin_rate", "Spin frequency", [["rare", "Rarely"], ["normal", "Normally"], ["often", "Often"]])

	_section("3D fretboard")
	_slider(&"neck_tilt", "Camera tilt", 0, 60, 1, "%d°")
	_slider(&"neck_fov", "Perspective (field of view)", 20, 70, 1, "%d°")


# --- Wiersze ------------------------------------------------------------------

func _section(text: String) -> void:
	if _rows.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 10
		_rows.add_child(gap)
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"Section"
	l.uppercase = true
	_rows.add_child(l)


func _row(label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_rows.add_child(row)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 300
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(control)


# Zapis ustawienia z ekranu konfiguracji; ręczna zmiana ustawienia jakości przełącza profil na „własny”.
func _store(key: StringName, value: Variant) -> void:
	if key in QUALITY_KEYS:
		App.set_settings({key: value, &"quality": "custom"})
	else:
		App.set_setting(key, value)


func _select(key: StringName, label_text: String, items: Array, translate := true) -> OptionButton:
	var opt := OptionButton.new()
	opt.fit_to_longest_item = false
	opt.custom_minimum_size.x = 380
	opt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var current: Variant = App.setting(key)
	for i in items.size():
		opt.add_item(str(items[i][1]))
		if not translate:
			opt.set_item_auto_translate_mode(i, Node.AUTO_TRANSLATE_MODE_DISABLED)
		if items[i][0] == current or str(items[i][0]) == str(current):
			opt.selected = i
	if opt.selected < 0 and items.size() > 0:
		opt.selected = 0
	opt.item_selected.connect(func(i: int) -> void: _store(key, items[i][0]))
	_row(label_text, opt)
	return opt


func _toggle(key: StringName, label_text: String) -> CheckBox:
	var box := CheckBox.new()
	box.button_pressed = bool(App.setting(key))
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.toggled.connect(func(on: bool) -> void: _store(key, on))
	_row(label_text, box)
	return box


# Suwak z wartością obok. fmt: "%" – procent, "×" – mnożnik, inaczej wzorzec liczby.
func _slider(key: StringName, label_text: String, lo: float, hi: float, step: float, fmt: String) -> HSlider:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(App.setting(key))
	s.custom_minimum_size.x = 300
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(s)
	var value := Label.new()
	value.theme_type_variation = &"Muted"
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.custom_minimum_size.x = 80
	line.add_child(value)
	var integer := step >= 1.0 and is_equal_approx(fmod(lo, 1.0), 0.0)
	var show := func(v: float) -> void:
		match fmt:
			"%": value.text = "%d%%" % roundi(v * 100.0)
			"×": value.text = "%.1f×" % v if step >= 0.1 else "%.2f×" % v
			_: value.text = fmt % v
	show.call(s.value)
	s.value_changed.connect(func(v: float) -> void:
		show.call(v)
		_store(key, int(v) if integer else v))
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_row(label_text, line)
	return s


# Próbki kolorów: domyślny (z motywu, gdy default_text nie jest pusty), gotowa paleta i „+” –
# własne okno wyboru dowolnego koloru (ColorPopup). Wartość w ustawieniach: HEX albo "" (domyślny).
# Ten sam wiersz posłuży kolejnym kolorom (np. znaczniki na gryfie) – wystarczy podać paletę.
func _colors(key: StringName, label_text: String, default_text: String,
		palette: Array = ThemeManager.ACCENTS) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var current := str(App.setting(key))
	var group := ButtonGroup.new()
	var options: Array = []
	if not default_text.is_empty():
		options.append("")
	options.append_array(palette)
	var own := not current.is_empty() and not current in options
	options.append("+")
	for hex in options:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(34, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var fill: Color = ThemeManager.color("surface_2") if hex.is_empty() or hex == "+" else Color(hex)
		if hex == "+" and own:
			fill = Color(current)
		var ring := ThemeManager.color("text")
		b.add_theme_stylebox_override("normal", ThemeManager.box(fill, ThemeManager.color("border_strong"), 17, 1, 0, 0))
		b.add_theme_stylebox_override("hover", ThemeManager.box(fill, ThemeManager.color("muted"), 17, 2, 0, 0))
		b.add_theme_stylebox_override("pressed", ThemeManager.box(fill, ring, 17, 3, 0, 0))
		b.add_theme_stylebox_override("hover_pressed", ThemeManager.box(fill, ring, 17, 3, 0, 0))
		if hex.is_empty():
			b.text = "–" if default_text == "None" else "A"   # brak koloru / kolor domyślny
			b.tooltip_text = default_text
			b.add_theme_font_size_override("font_size", 13)
			b.add_theme_color_override("font_color", ThemeManager.color("muted"))
			b.add_theme_color_override("font_pressed_color", ThemeManager.color("text"))
		if hex == "+":
			b.text = "" if own else "+"
			b.tooltip_text = "Custom colour"
			b.add_theme_font_size_override("font_size", 18)
			b.add_theme_color_override("font_color", ThemeManager.color("muted"))
			b.toggle_mode = false
			if own:   # wybrany własny kolor – próbka „+” w tym kolorze, z obwódką wyboru
				b.add_theme_stylebox_override("normal", ThemeManager.box(fill, ring, 17, 3, 0, 0))
			b.pressed.connect(func() -> void:
				var start := Color(current) if not current.is_empty() else ThemeManager.color("accent")
				_color_popup(key).open(start, b.get_global_rect()))
		else:
			b.button_pressed = hex == current
			b.pressed.connect(_store.bind(key, hex))
		line.add_child(b)
	_row(label_text, line)


# Jedno okno wyboru koloru na ekran (dziecko ekranu, nie wiersza – przetrwa przebudowę zakładki).
var _popup: ColorPopup
var _popup_key: StringName


func _color_popup(key: StringName) -> ColorPopup:
	if _popup == null:
		_popup = ColorPopup.new()
		_popup.picked.connect(func(c: Color) -> void: _store(_popup_key, c.to_html(false).to_upper()))
		add_child(_popup)
	_popup_key = key
	return _popup


func _image_picker() -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var path := str(App.setting(&"bg_image"))
	var choose := Button.new()
	choose.text = "Choose an image…"
	choose.pressed.connect(func() -> void:
		DisplayServer.file_dialog_show(tr("Background image"), OS.get_system_dir(OS.SYSTEM_DIR_PICTURES), "",
				false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
				PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"]),
				func(ok: bool, files: PackedStringArray, _filter: int) -> void:
					if ok and files.size() > 0:
						_store(&"bg_image", files[0])
						_rebuild.call_deferred()))
	line.add_child(choose)
	var name := Label.new()
	name.theme_type_variation = &"Muted"
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name.text = path.get_file() if not path.is_empty() else tr("No image selected")
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(name)
	_row("Image", line)


func _devices(list: PackedStringArray) -> Array:
	var out := []
	for d in list:
		out.append([d, tr("System default") if d == "Default" else d])
	return out


func _update_sample() -> void:
	if _sample:
		_sample.text = "%s  %s" % [tr("Example:"), NoteNames.chromatic_scale(App.notation())]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _sample:
		_update_sample()
