# Fretboard Master – zakładka „Dźwięk i MIDI” okna ustawień, wiernie według zaakceptowanej makiety:
# sterownik, wejście (urządzenie, kanał, poziom sygnału, rozpoznany dźwięk), wyjście (urządzenie,
# głośność, dźwięk próbny, odsłuch, bufor, opóźnienie i jego pomiar) oraz instrument MIDI.
# Sterowniki ASIO i WDM-KS oraz bufor w próbkach obsłuży rdzeń audio w C++ (PortAudio) – do tego czasu
# wybór jest zapamiętywany, a dźwięk idzie przez WASAPI (pastylka stanu mówi to wprost).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name SettingsAudio
extends VBoxContainer

const DRIVERS := [["asio", "ASIO"], ["wasapi", "WASAPI"], ["wdm_ks", "WDM-KS"]]
const BUFFERS := [64, 128, 256, 512, 1024]
# Instrumenty MIDI: numer programu General MIDI (od 0), nazwa, opis brzmienia.
const INSTRUMENTS := [
	[24, "Classical guitar", "nylon strings"], [25, "Acoustic guitar", "steel strings"],
	[27, "Electric guitar", "clean tone"], [26, "Jazz guitar", "warm, full tone"],
	[29, "Overdriven guitar", "overdriven tone"], [0, "Piano", "for ear training"],
	[33, "Bass guitar", "fingerstyle"],
]
const SEGMENTS := 32
const BLUE := Color("5AA9FF")
const GREEN := Color("7BD88F")
const RED := Color("FF5C5C")
const ORANGE := Color("FF7A59")

var _check: AudioCheck
var _meter: Control
var _level := -90.0
var _status: Label
var _note: Label
var _note_info: Label
var _volume_label: Label
var _volume_fill: Control
var _monitor_button: Button
var _latency_value: Label
var _latency_hint: Label
var _measured := 0.0          # zmierzone opóźnienie (ms); 0 – brak pomiaru


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	_check = AudioCheck.new()
	_check.channel = int(App.setting(&"input_channel"))
	add_child(_check)
	_check.level_changed.connect(_on_level)
	_check.pitch_changed.connect(_on_pitch)
	_check.latency_measured.connect(_on_latency)

	add_child(_driver_card())
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 20)
	add_child(pair)
	pair.add_child(_input_card())
	pair.add_child(_output_card())
	add_child(_midi_card())


# --- Karty --------------------------------------------------------------------

func _driver_card() -> Control:
	var card := _card(Vector2(24, 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	text.add_child(_label("Sound driver", 15, ThemeManager.color("muted")))
	text.add_child(_label("ASIO gives the lowest latency if your sound card supports it.", 15, ThemeManager.color("faint")))
	var driver := str(App.setting(&"audio_driver"))
	row.add_child(_segmented(DRIVERS, driver, func(v: Variant) -> void:
		App.set_setting(&"audio_driver", v)
		_refresh_pill()
		_fill_outputs()
		_fill_inputs(), 16))
	_pill = Label.new()
	_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pill.add_theme_font_override("font", ThemeManager.font_body_bold)
	_pill.add_theme_font_size_override("font_size", ThemeManager.fs(16))
	row.add_child(_pill)
	_refresh_pill()
	return card


var _pill: Label
var _outputs: OptionButton
var _inputs: OptionButton


# Urządzenia wyjściowe: z rdzenia audio dla wybranego sterownika, a bez rdzenia – z Godota (WASAPI).
func _fill_outputs() -> void:
	var devices := AudioEngine.output_devices(AudioEngine.driver()) if AudioEngine.available() \
			else AudioServer.get_output_device_list()
	if devices.is_empty():
		devices = PackedStringArray(["Default"])
	_outputs.set_meta(&"devices", devices)
	_outputs.clear()
	var current := str(App.setting(&"audio_output"))
	for i in devices.size():
		_outputs.add_item(tr("System default") if devices[i] == "Default" else devices[i])
		_outputs.set_item_auto_translate_mode(i, Node.AUTO_TRANSLATE_MODE_DISABLED)
		if devices[i] == current:
			_outputs.selected = i
	if _outputs.selected < 0 and devices.size() > 0:
		_outputs.selected = 0


# Urządzenia wejściowe (gitara): z rdzenia audio dla wybranego sterownika, a bez rdzenia – z Godota.
func _fill_inputs() -> void:
	if _inputs == null:
		return
	var devices := AudioEngine.input_devices(AudioEngine.driver()) if AudioEngine.available() \
			else AudioServer.get_input_device_list()
	if devices.is_empty():
		devices = PackedStringArray(["Default"])
	_inputs.set_meta(&"devices", devices)
	_inputs.clear()
	var current := str(App.setting(&"audio_input"))
	for i in devices.size():
		_inputs.add_item(tr("System default") if devices[i] == "Default" else devices[i])
		_inputs.set_item_auto_translate_mode(i, Node.AUTO_TRANSLATE_MODE_DISABLED)
		if devices[i] == current:
			_inputs.selected = i
	if _inputs.selected < 0:
		_inputs.selected = 0


# Pastylka stanu: WASAPI działa już teraz; ASIO i WDM-KS – z nowym rdzeniem audio.
func _refresh_pill() -> void:
	var driver := str(App.setting(&"audio_driver"))
	var ok: bool
	var text: String
	if AudioEngine.available():
		# Sterownik obecny w rdzeniu i w systemie (ASIO – tylko w kompilacji z ASIO SDK i ze sterownikiem karty).
		ok = driver in AudioEngine.drivers()
		text = "Connected" if ok else "Not available on this computer"
	else:
		ok = driver == "wasapi"
		text = "Connected" if ok else "Coming with the new audio engine"
	var c: Color = ThemeManager.color("focus") if ok else ThemeManager.color("accent")
	_pill.text = "●  " + tr(text)
	_pill.add_theme_color_override("font_color", c)
	_pill.add_theme_stylebox_override("normal", ThemeManager.box(Color(c, 0.1), Color.TRANSPARENT, 20, 0, 16, 9))


func _input_card() -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _column(card)
	col.add_child(_label("Input – guitar", 22, ThemeManager.color("text"), true))
	col.add_child(_gap(4))
	col.add_child(_label("Device", 15, ThemeManager.color("muted")))
	_inputs = _device_select(&"audio_input", PackedStringArray())
	col.add_child(_inputs)
	_fill_inputs()
	col.add_child(_gap(6))
	col.add_child(_label("Channel", 15, ThemeManager.color("muted")))
	col.add_child(_chips([[0, "Input 1 (Hi-Z)"], [1, "Input 2"]], int(App.setting(&"input_channel")),
			func(v: Variant) -> void:
				App.set_setting(&"input_channel", v)
				_check.channel = int(v)))
	col.add_child(_gap(10))
	var head := HBoxContainer.new()
	col.add_child(head)
	var l := _label("Signal level – play a few notes", 15, ThemeManager.color("muted"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	_status = _label("", 15, GREEN, true)
	head.add_child(_status)
	_meter = Control.new()
	_meter.custom_minimum_size.y = 24
	_meter.draw.connect(_draw_meter)
	col.add_child(_meter)
	var scale := HBoxContainer.new()
	col.add_child(scale)
	for i in 4:
		var t := _label(["no signal", "too quiet", "good", "clipping"][i], 13, ThemeManager.color("faint"))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER,
				HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][i]
		scale.add_child(t)
	col.add_child(_gap(8))
	var found := PanelContainer.new()
	found.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("surface_2"), Color.TRANSPARENT, 10, 0, 16, 12))
	col.add_child(found)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	found.add_child(line)
	var fl := _label("Recognised note", 15, ThemeManager.color("muted"))
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(fl)
	_note = _label("—", 26, ThemeManager.color("accent"), true)
	_note.add_theme_font_override("font", ThemeManager.font_heading)
	_note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	line.add_child(_note)
	_note_info = _label("", 15, ThemeManager.color("faint"))
	_note_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_note_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_note_info)
	_on_level(-90.0)
	return card


func _output_card() -> Control:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := _column(card)
	col.add_child(_label("Output – headphones and speakers", 22, ThemeManager.color("text"), true))
	col.add_child(_gap(4))
	col.add_child(_label("Device", 15, ThemeManager.color("muted")))
	_outputs = _device_select(&"audio_output", PackedStringArray())
	col.add_child(_outputs)
	_fill_outputs()
	col.add_child(_gap(6))
	var head := HBoxContainer.new()
	col.add_child(head)
	var vl := _label("Volume", 15, ThemeManager.color("muted"))
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(vl)
	_volume_label = _label("", 15, ThemeManager.color("text"), true)
	_volume_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.add_child(_volume_label)
	var vol := HBoxContainer.new()
	vol.add_theme_constant_override("separation", 12)
	col.add_child(vol)
	vol.add_child(_round_button("−", -10))
	var track := Panel.new()
	track.custom_minimum_size.y = 9
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("border"), Color.TRANSPARENT, 4, 0, 0, 0))
	track.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	vol.add_child(track)
	_volume_fill = ColorRect.new()
	(_volume_fill as ColorRect).color = ThemeManager.color("focus")
	track.add_child(_volume_fill)
	track.resized.connect(_update_volume)
	vol.add_child(_round_button("+", 10))
	_update_volume()

	col.add_child(_gap(6))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var test := _big_button("▶  " + tr("Test sound"))
	test.pressed.connect(func() -> void:
		if not AudioEngine.play_test_note():   # rdzeń C++ – wybrany instrument MIDI; bez rdzenia – Godot
			_check.play_test_tone())
	buttons.add_child(test)
	_monitor_button = _big_button("")
	_monitor_button.pressed.connect(func() -> void:
		var on := not bool(App.setting(&"input_monitor"))
		App.set_setting(&"input_monitor", on)
		_check.set_monitor(on)
		_update_monitor())
	buttons.add_child(_monitor_button)
	_update_monitor()

	col.add_child(_gap(8))
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _line())
	col.add_child(sep)
	col.add_child(_gap(4))
	var bh := HBoxContainer.new()
	col.add_child(bh)
	var bl := _label("Buffer size (in samples)", 15, ThemeManager.color("muted"))
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bl)
	var rate := _label(_number(int(AudioServer.get_mix_rate())) + " Hz", 15, ThemeManager.color("faint"))
	rate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bh.add_child(rate)
	var items := []
	for b in BUFFERS:
		items.append([b, str(b)])
	var chips := _chips(items, int(App.setting(&"buffer_samples")), func(v: Variant) -> void:
		App.set_setting(&"buffer_samples", v)
		_measured = 0.0
		_update_latency(), false)
	col.add_child(chips)
	col.add_child(_gap(4))
	var lat := HBoxContainer.new()
	lat.add_theme_constant_override("separation", 6)
	col.add_child(lat)
	lat.add_child(_label("Total latency:", 16, ThemeManager.color("text")))
	_latency_value = _label("", 16, GREEN, true)
	_latency_value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lat.add_child(_latency_value)
	_latency_hint = _label("", 16, ThemeManager.color("faint"))
	_latency_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_latency_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_latency_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lat.add_child(_latency_hint)
	var measure := Button.new()
	measure.text = "Measure latency"
	_style_teal(measure)
	measure.pressed.connect(func() -> void:
		_latency_hint.text = "· " + tr("measuring…")
		_check.measure_latency())
	lat.add_child(measure)
	_update_latency()
	return card


func _midi_card() -> Control:
	var card := _card()
	var col := _column(card)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	text.add_child(_label("MIDI playback – instrument", 22, ThemeManager.color("text"), true))
	text.add_child(_label("The program plays examples in the encyclopedia, exercises and backing tracks with this sound.",
			15, ThemeManager.color("faint")))
	var seg := _segmented([["internal", "Built-in synthesizer"], ["external", "External MIDI device"]],
			str(App.setting(&"midi_output")), func(v: Variant) -> void: App.set_setting(&"midi_output", v), 15)
	seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(seg)
	col.add_child(_gap(6))
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	col.add_child(tiles)
	var group := ButtonGroup.new()
	var current := int(App.setting(&"midi_instrument"))
	var accent := ThemeManager.color("accent")
	for inst in INSTRUMENTS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 128
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var off := ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border_strong"), 14, 1, 10, 14)
		var on := ThemeManager.box(Color(accent, 0.1), accent, 14, 2, 10, 14)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border"), ThemeManager.color("border_strong"), 14, 1, 10, 14))
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.button_pressed = inst[0] == current
		b.pressed.connect(App.set_setting.bind(&"midi_instrument", inst[0]))
		tiles.add_child(b)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 8
		box.offset_right = -8
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var gm := _label("GM %d" % (inst[0] + 1), 13, ThemeManager.color("faint"), true)
		gm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(gm)
		box.add_child(_gap(4))
		box.add_child(_label(inst[1], 16, ThemeManager.color("text"), true))
		box.add_child(_label(inst[2], 14, ThemeManager.color("faint")))
		for l in box.get_children():
			if l is Label:
				(l as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


# --- Sygnały pomiaru ------------------------------------------------------------

func _on_level(db: float) -> void:
	_level = db
	_meter.queue_redraw()
	var i := 0 if db < -54.0 else 1 if db < -36.0 else 2 if db < -3.0 else 3
	_status.text = ["no signal", "too quiet", "good", "clipping"][i]
	_status.add_theme_color_override("font_color", [ThemeManager.color("faint"), BLUE, GREEN, RED][i])


func _on_pitch(hz: float) -> void:
	if hz <= 0.0:
		_note.text = "—"
		_note_info.text = ""
		return
	var a4 := float(App.setting(&"a4"))
	var exact := 69.0 + 12.0 * log(hz / a4) / log(2.0)
	var midi := roundi(exact)
	var cents := roundi((exact - midi) * 100.0)
	_note.text = NoteNames.note_name(midi, App.notation(), true)
	_note_info.text = "%s Hz · %+d ct" % [_decimal(hz), cents]


func _on_latency(ms: float) -> void:
	if ms < 0.0:
		_latency_hint.text = "· " + tr("no signal – connect the output to the input")
		return
	_measured = ms
	_update_latency()


# --- Odświeżanie ----------------------------------------------------------------

# Opóźnienie: zmierzone (po pomiarze) albo wyliczone z bufora – wejście i wyjście plus przetwornik.
func _update_latency() -> void:
	var ms := _measured
	if ms <= 0.0:
		ms = int(App.setting(&"buffer_samples")) * 2.0 / AudioServer.get_mix_rate() * 1000.0 + 2.5
	var lat := roundi(ms)
	var hint := "very good for live playing" if lat <= 8 else "sufficient" if lat <= 15 else "noticeable when playing live"
	_latency_value.text = "%d ms" % lat
	_latency_value.add_theme_color_override("font_color",
			GREEN if lat <= 8 else ThemeManager.color("accent") if lat <= 15 else ORANGE)
	_latency_hint.text = "· " + tr(hint) + ("  (" + tr("measured") + ")" if _measured > 0.0 else "")


func _update_volume() -> void:
	var v := int(App.setting(&"output_volume"))
	_volume_label.text = "%d%%" % v
	var track := _volume_fill.get_parent() as Control
	_volume_fill.position = Vector2.ZERO
	_volume_fill.size = Vector2(track.size.x * v / 100.0, track.size.y)


func _update_monitor() -> void:
	_monitor_button.text = tr("Guitar monitoring: on") if bool(App.setting(&"input_monitor")) \
			else tr("Guitar monitoring: off")


func _draw_meter() -> void:
	var w := _meter.size.x
	var gap := 3.0
	var seg := (w - gap * (SEGMENTS - 1)) / SEGMENTS
	var lit := _lit_segments(_level)
	for i in SEGMENTS:
		var c: Color = BLUE if i < 8 else GREEN if i < 26 else RED
		if i >= lit:
			c = Color(ThemeManager.color("border"), 0.7)
		_meter.draw_rect(Rect2(i * (seg + gap), 0, seg, _meter.size.y), c)


# Podział wskaźnika: 8 niebieskich (-60…-36 dB, za cichy), 18 zielonych (-36…-3 dB), 6 czerwonych (-3…0 dB).
static func _lit_segments(db: float) -> int:
	if db < -60.0:
		return 0
	if db < -36.0:
		return int((db + 60.0) / 24.0 * 8.0) + 1
	if db < -3.0:
		return 8 + int((db + 36.0) / 33.0 * 18.0) + 1
	return mini(26 + int((db + 3.0) / 3.0 * 6.0) + 1, SEGMENTS)


# --- Elementy -----------------------------------------------------------------

func _card(pad := Vector2(24, 24)) -> PanelContainer:
	var card := PanelContainer.new()
	var box := ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("border"), int(pad.x))
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	card.add_theme_stylebox_override("panel", box)
	return card


func _column(card: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	return col


func _label(text: String, px: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", ThemeManager.fs(px))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", ThemeManager.font_heading if px >= 20 else ThemeManager.font_body_bold)
	return l


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _line() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = ThemeManager.color("border")
	s.thickness = 1
	return s


# Przełącznik segmentowy (sterownik, źródło MIDI): wybrany segment na granatowym tle.
func _segmented(items: Array, current: Variant, on_pick: Callable, px: int) -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border"), 12, 1, 4, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	frame.add_child(row)
	var group := ButtonGroup.new()
	var buttons: Array[Button] = []
	for it in items:
		var b := Button.new()
		b.text = it[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", ThemeManager.fs(px))
		var off := ThemeManager.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0, 18, 8)
		var on := ThemeManager.box(ThemeManager.color("border_strong"), Color.TRANSPARENT, 8, 0, 18, 8)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border"), Color.TRANSPARENT, 8, 0, 18, 8))
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_color", ThemeManager.color("muted"))
		b.add_theme_color_override("font_hover_color", ThemeManager.color("text"))
		b.button_pressed = str(it[0]) == str(current)
		buttons.append(b)
		b.pressed.connect(func() -> void:
			for o in buttons:
				o.add_theme_font_override("font", ThemeManager.font_body_bold if o == b else ThemeManager.font_body_medium)
			on_pick.call(it[0]))
		if b.button_pressed:
			b.add_theme_font_override("font", ThemeManager.font_body_bold)
		row.add_child(b)
	return frame


# Żetony wyboru (kanał, bufor): wybrany – turkusowa obwódka i tło.
func _chips(items: Array, current: Variant, on_pick: Callable, translate := true) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	var teal := ThemeManager.color("focus")
	for it in items:
		var b := Button.new()
		b.text = it[1]
		if not translate:
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(58, 40)
		b.add_theme_font_override("font", ThemeManager.font_body_bold)
		b.add_theme_font_size_override("font_size", ThemeManager.fs(15))
		var off := ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border_strong"), 10, 1, 14, 8)
		var on := ThemeManager.box(Color(teal, 0.12), teal, 10, 1, 14, 8)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border"), ThemeManager.color("border_strong"), 10, 1, 14, 8))
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_color_override("font_pressed_color", teal)
		b.add_theme_color_override("font_hover_pressed_color", teal)
		b.button_pressed = str(it[0]) == str(current)
		b.pressed.connect(on_pick.bind(it[0]))
		row.add_child(b)
	return row


func _device_select(key: StringName, devices: PackedStringArray) -> OptionButton:
	var opt := OptionButton.new()
	opt.fit_to_longest_item = false
	opt.custom_minimum_size.y = 48
	opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var current := str(App.setting(key))
	for i in devices.size():
		opt.add_item(tr("System default") if devices[i] == "Default" else devices[i])
		opt.set_item_auto_translate_mode(i, Node.AUTO_TRANSLATE_MODE_DISABLED)
		if devices[i] == current:
			opt.selected = i
	if opt.selected < 0 and devices.size() > 0:
		opt.selected = 0
	opt.item_selected.connect(func(i: int) -> void:
		var list: PackedStringArray = opt.get_meta(&"devices", devices)
		App.set_setting(key, list[i]))
	return opt


func _round_button(text: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(40, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.add_theme_font_size_override("font_size", ThemeManager.fs(20))
	for state in ["normal", "hover", "pressed"]:
		var bg: Color = ThemeManager.color("surface_2") if state == "normal" else ThemeManager.color("border")
		b.add_theme_stylebox_override(state, ThemeManager.box(bg, ThemeManager.color("border_strong"), 20, 1, 0, 0))
	b.pressed.connect(func() -> void:
		App.set_setting(&"output_volume", clampi(int(App.setting(&"output_volume")) + step, 0, 100))
		_update_volume())
	return b


func _big_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 50
	b.add_theme_font_override("font", ThemeManager.font_body_bold)
	b.add_theme_font_size_override("font_size", ThemeManager.fs(16))
	return b


func _style_teal(b: Button) -> void:
	var teal := ThemeManager.color("focus")
	b.custom_minimum_size.y = 42
	b.add_theme_font_override("font", ThemeManager.font_body_bold)
	b.add_theme_font_size_override("font_size", ThemeManager.fs(15))
	var dark := Color("04201E")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, dark)
	b.add_theme_stylebox_override("normal", ThemeManager.box(teal, Color.TRANSPARENT, 10, 0, 16, 8))
	b.add_theme_stylebox_override("hover", ThemeManager.box(teal.lightened(0.12), Color.TRANSPARENT, 10, 0, 16, 8))
	b.add_theme_stylebox_override("pressed", ThemeManager.box(teal.darkened(0.1), Color.TRANSPARENT, 10, 0, 16, 8))


# Liczby w zapisie języka interfejsu: przecinek dziesiętny i spacja tysięcy (poza angielskim).
func _decimal(v: float) -> String:
	var s := "%.1f" % v
	return s if TranslationServer.get_locale().begins_with("en") else s.replace(".", ",")


func _number(v: int) -> String:
	var s := str(v)
	if s.length() > 3:
		var sep := "," if TranslationServer.get_locale().begins_with("en") else " "
		s = s.substr(0, s.length() - 3) + sep + s.substr(s.length() - 3)
	return s
