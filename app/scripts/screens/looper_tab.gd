# Fretboard Master – zakładka „Looper” ekranu Metronomu (według zaakceptowanej makiety): lista nagranych
# ścieżek (fala, tempo, metrum, podkład, czas), pola wyboru ścieżek do wspólnego odtwarzania, przycinanie
# ciszy i wybór zakresu na fali, odtwarzanie w pętli z podkładem (brak / perkusja / metronom) i nagrywanie
# zawsze do automatu perkusyjnego albo metronomu, z odliczaniem.
# Dźwięk i zgranie z podkładem co do próbki – rdzeń C++ (FbmAudio: looper_*, input_read). Nagrania:
# user://looper/<id>.wav (32-bit float, mono) i opis ścieżek w user://looper/tracks.json.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name LooperTab
extends Node

const DIR := "user://looper/"
const INDEX := DIR + "tracks.json"
const METRES := ["2/4", "3/4", "4/4", "6/8", "7/8"]
const BEATS := [2, 3, 4, 6, 7]
const SUBS := [1, 2, 3, 4]
const KITS := [["Standard", 0], ["Room", 8], ["Power", 16], ["Jazz", 32], ["Brush", 40]]
const PRESETS := ["Rock", "Pop", "Shuffle", "Waltz", "Ballad 6/8"]
const TEAL := Color("3FD0C9")
const RED := Color("FF5A5F")
const STOP := Color("FF7A59")
const MAX_SECONDS := 600.0
const PEAKS := 1024

var scr: Node                      # ekran Metronomu (pomocnicze elementy i ustawienia rytmu)
var _core: Object
var _tracks: Array = []            # opisy ścieżek (słowniki, zob. _new_track)
var _samples := {}                 # id → PackedFloat32Array (wczytane próbki)
var _peaks := {}                   # id → PackedFloat32Array (szczyty do rysowania fali)
var _rows := {}                    # id → TrackRow
var _list: VBoxContainer
var _empty: Label
var _error: Label
var _bottom: HBoxContainer
var _play: Button
var _record: Button
var _live: TrackRow                # wiersz nagrywanej właśnie ścieżki
var _level_bar: Panel
var _level_fill: Panel
var _level_label: Label
var _level_db := -120.0
var _playing := false
var _selected := ""
var _rec := {}                     # stan nagrywania (pusty – nie nagrywa)
var _live_tick := 0


func _init(screen: Node) -> void:
	scr = screen


# --- Budowa -------------------------------------------------------------------------------

func build(main: VBoxContainer, aside: VBoxContainer) -> void:
	_core = AudioEngine.ensure_open()
	_load_index()

	main.add_child(scr._gap(31))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	main.add_child(row)
	row.add_child(scr._round_button("−", -1, 53, 26))
	var bpm: Label = scr._label("", 67, ThemeManager.color("text"), ThemeManager.font_heading)
	bpm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bpm.custom_minimum_size.x = 120
	bpm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(bpm)
	scr._bpm_label = bpm
	row.add_child(scr._round_button("+", 1, 53, 26))
	var tempo: RichTextLabel = scr._rich_tempo(17, "BPM")
	tempo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(tempo)
	scr._tempo_label = tempo
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var hint: Label = scr._label("tempo of a new recording", 16, Color("8C96B3"))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)

	main.add_child(scr._gap(31))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	main.add_child(head)
	head.add_child(scr._label("Recorded tracks", 22, ThemeManager.color("text"), ThemeManager.font_heading))
	var h2: Label = scr._label("ticked tracks play together · drag across the wave to choose a range", 16, Color("8C96B3"))
	h2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(h2)

	main.add_child(scr._gap(14))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_empty = scr._label("No recordings yet. Press „Record new” (R) – you always record along with the drum machine or the metronome.", 17, Color("8C96B3"))
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(_empty)
	for t in _tracks:
		_add_row(t)
	_update_empty()

	main.add_child(scr._gap(14))
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 22)
	main.add_child(legend)
	legend.add_child(scr._legend_item(ThemeManager.color("accent"), "start and end (trim)"))
	legend.add_child(_outline_item("playback range"))
	legend.add_child(scr._label("A track remembers the tempo, metre and backing of its recording.", 16, Color("8C96B3")))

	main.add_child(scr._gap(18))
	_error = scr._label("", 15, STOP)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	main.add_child(_error)
	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 17)
	main.add_child(_bottom)
	_build_bottom()

	_build_aside(aside)
	scr._show_bpm(scr._bpm())


func _build_bottom() -> void:
	for c in _bottom.get_children():
		c.queue_free()
	_play = Button.new()
	_play.custom_minimum_size = Vector2(205, 67)
	_play.add_theme_font_override("font", ThemeManager.font_body_bold)
	_play.add_theme_font_size_override("font_size", ThemeManager.fs(21))
	_play.focus_mode = Control.FOCUS_NONE
	_play.pressed.connect(toggle_play)
	_bottom.add_child(_play)
	var bl: Label = scr._label("Backing:", 16, ThemeManager.color("muted"))
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bottom.add_child(bl)
	_bottom.add_child(scr._segmented([[0, "none"], [1, "drums"], [2, "metronome"]], int(App.setting(&"lp_bed")),
			func(v: Variant) -> void:
				App.set_setting(&"lp_bed", v)
				_build_bottom()
				if _playing:
					_start_play()))
	_record = Button.new()
	_record.custom_minimum_size = Vector2(0, 67)
	_record.add_theme_font_override("font", ThemeManager.font_body_bold)
	_record.add_theme_font_size_override("font_size", ThemeManager.fs(19))
	_record.focus_mode = Control.FOCUS_NONE
	_record.pressed.connect(toggle_record)
	_bottom.add_child(_record)
	_update_buttons()


func _build_aside(aside: VBoxContainer) -> void:
	var card: PanelContainer = scr._aside_card()
	var col := card.get_child(0) as VBoxContainer
	col.add_child(scr._field("Metre", scr._chips_row(METRES, scr._metre(), false, func(i: int) -> void:
		var g: int = scr._grid_kind()
		if i >= 3 and g == 1:
			g = 0
		App.set_settings({&"met_metre": i, &"met_grid": g, &"met_preset": -1})
		scr._pattern = scr._basic(i, g)
		scr._save_pattern()
		scr._update_texts())))

	var rec: PanelContainer = scr._aside_card()
	var rc := rec.get_child(0) as VBoxContainer
	rc.add_theme_constant_override("separation", 17)
	rc.add_child(scr._label("Recording", 24, ThemeManager.color("text"), ThemeManager.font_heading))
	var note: Label = scr._label("", 14, Color("8C96B3"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var set_note := func() -> void:
		if int(App.setting(&"lp_rec_with")) == 0:
			note.text = tr("%s pattern, %s kit – set in the „Drum machine” tab.") % [_preset_name(), KITS[int(App.setting(&"met_kit"))][0]]
		else:
			note.text = tr("Sound and subdivision – set in the „Classic metronome” tab.")
	var with_f: VBoxContainer = scr._field("You play along with", scr._chips_row(["the drum machine", "the metronome"],
			int(App.setting(&"lp_rec_with")), true, func(i: int) -> void:
				App.set_setting(&"lp_rec_with", i)
				set_note.call(), true))
	with_f.add_child(note)
	set_note.call()
	rc.add_child(with_f)
	rc.add_child(scr._field("Count-in before recording", scr._chips_row(["none", "1 bar", "2 bars"],
			int(App.setting(&"lp_countin")), true, func(i: int) -> void:
				App.set_setting(&"lp_countin", i), true)))

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 9)
	rc.add_child(lv)
	var lh := HBoxContainer.new()
	lv.add_child(lh)
	var dev: Label = scr._label("", 16, ThemeManager.color("muted"))
	dev.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	dev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dev_name := str(App.setting(&"audio_input"))
	if dev_name == "Default":
		dev_name = tr("default device")
	if _core and _core.is_open() and _core.input_ok():
		dev.text = tr("Input: %s, channel %d") % [dev_name, int(App.setting(&"input_channel")) + 1]
	else:
		dev.text = tr("Audio input unavailable – check the Sound and MIDI settings.")
	lh.add_child(dev)
	_level_label = scr._label("", 16, TEAL)
	_level_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lh.add_child(_level_label)
	_level_bar = Panel.new()
	_level_bar.custom_minimum_size.y = 10
	_level_bar.add_theme_stylebox_override("panel", ThemeManager.box(Color("1C2440"), Color.TRANSPARENT, 5, 0, 0, 0))
	lv.add_child(_level_bar)
	_level_fill = Panel.new()
	_level_fill.add_theme_stylebox_override("panel", ThemeManager.box(TEAL, Color.TRANSPARENT, 5, 0, 0, 0))
	_level_bar.add_child(_level_fill)
	rc.add_child(scr._label("Space – playback · R – recording", 14, Color("8C96B3")))


func _outline_item(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var sw := Panel.new()
	sw.custom_minimum_size = Vector2(11, 11)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.add_theme_stylebox_override("panel", ThemeManager.box(Color.TRANSPARENT, TEAL, 3, 2, 0, 0))
	h.add_child(sw)
	h.add_child(scr._label(text, 16, Color("8C96B3")))
	return h


func _add_row(t: Dictionary, at_top := false) -> TrackRow:
	var r := TrackRow.new()
	r.setup(self, t)
	_list.add_child(r)
	if at_top:
		_list.move_child(r, 1)
	if not t.is_empty():
		_rows[t.id] = r
		r.wave.peaks = _track_peaks(t)
		r.refresh()
	return r


func _update_empty() -> void:
	_empty.visible = _tracks.is_empty() and _live == null


func _update_buttons() -> void:
	if _play == null:
		return
	_play.text = tr("Stop") if _playing else tr("Play")
	_play.icon = _glyph("stop" if _playing else "play", Color("1A1206"))
	_play.add_theme_constant_override("h_separation", 10)
	var bg: Color = STOP if _playing else ThemeManager.color("accent")
	var dark := Color("1A1206")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_play.add_theme_color_override(c, dark)
	_play.add_theme_stylebox_override("normal", ThemeManager.box(bg, Color.TRANSPARENT, 14, 0, 36, 10))
	_play.add_theme_stylebox_override("hover", ThemeManager.box(bg.lightened(0.1), Color.TRANSPARENT, 14, 0, 36, 10))
	_play.add_theme_stylebox_override("pressed", ThemeManager.box(bg.darkened(0.1), Color.TRANSPARENT, 14, 0, 36, 10))
	var rec := not _rec.is_empty()
	_record.text = tr("Finish recording") if rec else tr("Record new")
	var rbg := RED if rec else Color(RED, 0.10)
	var fg := Color.WHITE if rec else Color("FF8A8E")
	_record.icon = _glyph("stop" if rec else "dot", fg if rec else RED)
	_record.add_theme_constant_override("h_separation", 10)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_record.add_theme_color_override(c, fg)
	_record.add_theme_stylebox_override("normal", ThemeManager.box(rbg, RED, 14, 1, 31, 10))
	_record.add_theme_stylebox_override("hover", ThemeManager.box(rbg.lightened(0.08) if rec else Color(RED, 0.18), RED, 14, 1, 31, 10))
	_record.add_theme_stylebox_override("pressed", ThemeManager.box(Color(RED, 0.3), RED, 14, 1, 31, 10))


## Ikonka przycisku (trójkąt, kwadrat, kropka) – rysowana, bo czcionki interfejsu nie mają tych znaków.
static func _glyph(kind: String, color: Color) -> ImageTexture:
	var n := 18 * 4
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			var inside := false
			match kind:
				"play":
					inside = u > 0.18 and u < 0.86 and absf(v - 0.5) < (0.86 - u) * 0.62
				"stop":
					inside = u > 0.2 and u < 0.8 and v > 0.2 and v < 0.8
				_:
					inside = Vector2(u - 0.5, v - 0.5).length() < 0.32
			img.set_pixel(x, y, color if inside else Color(color, 0.0))
	img.resize(ThemeManager.fs(18), ThemeManager.fs(18), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func summary() -> String:
	var on := 0
	for t in _tracks:
		if t.on:
			on += 1
	return _count_text(_tracks.size(), on)


func _show_error(text: String) -> void:
	_error.text = text
	_error.visible = not text.is_empty()


# --- Odtwarzanie ---------------------------------------------------------------------------

func toggle_play() -> void:
	if not _rec.is_empty():
		_finish_record()
		return
	if _playing:
		stop_all()
	else:
		_start_play()


func _start_play() -> void:
	_stop_core()
	var sel := _ticked()
	if sel.is_empty():
		_show_error(tr("Tick the tracks to play."))
		return
	_core = AudioEngine.ensure_open()
	if _core == null:
		_show_error(tr("No sound output – check the Sound and MIDI settings."))
		return
	_show_error("")
	var ref: Dictionary = sel[0]
	_configure(int(ref.bpm), int(ref.metre), int(App.setting(&"lp_bed")))
	var loop := _loop_for(sel, int(ref.bpm), int(ref.metre), float(ref.rate))
	_core.looper_clear()
	for t in sel:
		var reg := _region(t)
		_core.looper_add(_track_samples(t), reg.x, reg.y, 1.0)
	_core.looper_play(loop.x, loop.y, 0)
	_core.start()
	_playing = true
	_update_buttons()


## Pętla (początek, długość) w próbkach: od taktu, w którym zaczyna się najwcześniejszy zakres,
## do końca taktu, w którym kończy się najpóźniejszy – całe takty, żeby podkład się zgadzał.
func _loop_for(sel: Array, bpm: int, metre: int, rate: float) -> Vector2i:
	var bar := _bar_frames(bpm, metre, rate)
	var a := INF
	var b := 0.0
	for t in sel:
		var reg := _region(t)
		a = minf(a, reg.x)
		b = maxf(b, reg.y)
	var first := floorf(a / bar)
	var bars := maxf(1.0, ceilf(b / bar) - first)
	return Vector2i(roundi(first * bar), roundi(bars * bar))


func stop_all() -> void:
	if not _rec.is_empty():
		_rec = {}
		if _live:
			_live.queue_free()
			_live = null
		_update_empty()
	_stop_core()
	_playing = false
	for id in _rows:
		(_rows[id] as TrackRow).wave.set_head(-1)
	_update_buttons()


func _stop_core() -> void:
	if _core:
		_core.looper_stop()
		_core.stop()


## Podkład do rdzenia: bed 0 – zegar bez dźwięku, 1 – automat perkusyjny, 2 – metronom klasyczny.
func _configure(bpm: int, metre: int, bed: int) -> void:
	var same: bool = metre == scr._metre()
	var g: int = scr._grid_kind() if same else 0
	var pattern: Array = scr._pattern if same else scr._basic(metre, 0)
	var steps: int = scr._steps(metre, g)
	var flat := PackedByteArray()
	flat.resize(6 * steps)
	for r in 6:
		for s in steps:
			flat[r * steps + s] = int(pattern[r][s]) if s < (pattern[r] as Array).size() else 0
	var mask := 0
	for a in ([0, 3] if metre == 3 else [0, 2, 4] if metre == 4 else [0]):
		mask |= 1 << a
	_core.configure({
		"bpm": float(bpm), "mode": 1 if bed == 1 else 0, "beats": BEATS[metre], "accents": mask,
		"subdivision": SUBS[clampi(int(App.setting(&"met_sub")), 0, 3)], "sound": int(App.setting(&"met_sound")),
		"steps": steps, "steps_per_beat": scr._spq(metre, g), "kit": KITS[int(App.setting(&"met_kit"))][1],
		"ramp": false, "silent": bed == 0,
	}, flat)


# --- Nagrywanie ----------------------------------------------------------------------------

func toggle_record() -> void:
	if _rec.is_empty():
		_start_record()
	else:
		_finish_record()


func _start_record() -> void:
	stop_all()
	_core = AudioEngine.ensure_open()
	if _core == null:
		_show_error(tr("No sound output – check the Sound and MIDI settings."))
		return
	if not _core.input_ok():
		_show_error(tr("Audio input unavailable – check the Sound and MIDI settings."))
		return
	_show_error("")
	var bpm: int = scr._bpm()
	var metre: int = scr._metre()
	var bed := 1 if int(App.setting(&"lp_rec_with")) == 0 else 2
	var rate: float = _core.sample_rate()
	var countin := int(App.setting(&"lp_countin"))
	_configure(bpm, metre, bed)
	# Odsłuch zaznaczonych ścieżek w tym samym tempie i metrum – po odliczaniu, od pierwszego taktu.
	var along: Array = _ticked().filter(func(t: Dictionary) -> bool: return int(t.bpm) == bpm and int(t.metre) == metre)
	_core.looper_clear()
	if not along.is_empty():
		for t in along:
			var reg := _region(t)
			_core.looper_add(_track_samples(t), reg.x, reg.y, 1.0)
		var loop := _loop_for(along, bpm, metre, rate)
		_core.looper_play(loop.x, loop.y, roundi(countin * _bar_frames(bpm, metre, rate)))
	_core.start()
	_rec = {"bpm": bpm, "metre": metre, "bed": bed, "rate": rate, "countin": countin,
			"out": -1, "next": -1, "buf": PackedFloat32Array()}
	_live = _add_row({}, true)
	_live.set_live(tr("New recording"), _meta_text(bpm, metre, bed, _bed_name(bed)))
	_update_empty()
	_update_buttons()


func _poll_record(v: Dictionary) -> void:
	var cs := int(v.clock_start)
	if int(_rec.next) < 0:
		if cs < 0:
			return
		var out := cs + roundi(int(_rec.countin) * _bar_frames(int(_rec.bpm), int(_rec.metre), float(_rec.rate)))
		_rec.out = out
		_rec.next = out + int(_core.latency_frames())
	var chunk: Variant = _core.input_read(int(_rec.next), 1 << 17)
	if chunk == null:
		_show_error(tr("Recording interrupted – the input was not read in time."))
		_finish_record()
		return
	var buf: PackedFloat32Array = _rec.buf
	buf.append_array(chunk)
	_rec.buf = buf
	_rec.next = int(_rec.next) + (chunk as PackedFloat32Array).size()
	var bar := _bar_frames(int(_rec.bpm), int(_rec.metre), float(_rec.rate))
	var heard := int(v.frame)
	var status: String
	if heard < int(_rec.out):
		var left := ceili((int(_rec.out) - heard) / bar)
		status = tr("count-in: %d") % maxi(left, 1)
	else:
		status = tr("recording · bar %d") % (floori((heard - int(_rec.out)) / bar) + 1)
	_live.set_status(status)
	_live_tick += 1
	if _live_tick % 6 == 0 and buf.size() > 0:
		var span := maxf(buf.size(), bar * 4.0)
		_live.wave.frames = int(span)
		_live.wave.peaks = _core.waveform(buf, maxi(1, roundi(PEAKS * buf.size() / span)))
		_live.wave.peak_frames = buf.size()
		_live.wave.trim = Vector2i(0, buf.size())
		_live.wave.queue_redraw()
	if buf.size() > MAX_SECONDS * float(_rec.rate):
		_finish_record()


func _finish_record() -> void:
	if _rec.is_empty():
		return
	if int(_rec.next) >= 0:
		var chunk: Variant = _core.input_read(int(_rec.next), 1 << 17)
		if chunk != null:
			var b: PackedFloat32Array = _rec.buf
			b.append_array(chunk)
			_rec.buf = b
	var rec := _rec
	_rec = {}
	stop_all()
	var buf: PackedFloat32Array = rec.buf
	if buf.size() < float(rec.rate) * 0.3:
		_show_error(tr("The recording is too short – it was not saved."))
		return
	var t := _new_track(rec, buf.size())
	if not _save_wav(DIR + t.id + ".wav", buf, int(rec.rate)):
		_show_error(tr("Could not save the recording."))
		return
	_samples[t.id] = buf
	_tracks.insert(0, t)
	_save_index()
	_add_row(t, true)
	_select(t.id)
	_update_empty()
	scr._update_texts()


func _new_track(rec: Dictionary, frames: int) -> Dictionary:
	var n := 1
	for t in _tracks:
		n = maxi(n, int(t.get("num", 0)) + 1)
	var bed := int(rec.bed)
	return {"id": "%d" % Time.get_unix_time_from_system() + "_%d" % randi_range(1000, 9999), "num": n,
		"name": tr("Recording %d") % n, "bpm": int(rec.bpm), "metre": int(rec.metre), "bed": bed,
		"bed_name": _bed_name(bed), "rate": float(rec.rate), "frames": frames,
		"trim": [0, frames], "range": [], "on": true}


# --- Ścieżki: zmiany z wierszy -----------------------------------------------------------

func _select(id: String) -> void:
	_selected = id
	for k in _rows:
		(_rows[k] as TrackRow).set_selected(k == id)


func row_changed(t: Dictionary, restart := true) -> void:
	_save_index()
	scr._update_texts()
	if _playing and restart:
		_start_play()


func row_rename(t: Dictionary, text: String) -> void:
	t.name = text.strip_edges() if not text.strip_edges().is_empty() else t.name
	_save_index()


func row_trim_silence(t: Dictionary) -> void:
	var s := _track_samples(t)
	var c := AudioEngine.core()
	if c == null or s.is_empty():
		return
	var b: Vector2i = c.sound_bounds(s, -42.0, roundi(float(t.rate) * 0.01))
	if b.y <= b.x:
		return
	t.trim = [b.x, b.y]
	if not (t["range"] as Array).is_empty():
		var a := clampi(int(t["range"][0]), b.x, b.y)
		var e := clampi(int(t["range"][1]), b.x, b.y)
		t["range"] = [a, e] if e - a > 0 else []
	(_rows[t.id] as TrackRow).refresh()
	row_changed(t)


func row_delete(t: Dictionary) -> void:
	_tracks.erase(t)
	_samples.erase(t.id)
	_peaks.erase(t.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + t.id + ".wav"))
	if _rows.has(t.id):
		(_rows[t.id] as TrackRow).queue_free()
		_rows.erase(t.id)
	_save_index()
	_update_empty()
	scr._update_texts()
	if _playing:
		if _ticked().is_empty():
			stop_all()
		else:
			_start_play()


func _process(_delta: float) -> void:
	if _core == null or not _core.is_open():
		return
	if _core.input_ok() and _level_fill:
		var db: float = _core.input_peak_db()
		_level_db = maxf(db, _level_db - 1.2)
		var f := clampf((_level_db + 60.0) / 60.0, 0.0, 1.0)
		_level_fill.size = Vector2(_level_bar.size.x * f, _level_bar.size.y)
		_level_label.text = "%d dB" % roundi(_level_db) if _level_db > -90.0 else "–"
	if not _rec.is_empty() or _playing:
		var v: Dictionary = _core.visual_state()
		if not _rec.is_empty():
			_poll_record(v)
		var pos: int = _core.looper_position()
		for t in _tracks:
			if _rows.has(t.id):
				(_rows[t.id] as TrackRow).wave.set_head(pos if (_playing or not _rec.is_empty()) and t.on else -1)


# --- Dane ----------------------------------------------------------------------------------

func _ticked() -> Array:
	return _tracks.filter(func(t: Dictionary) -> bool: return bool(t.on))


func _region(t: Dictionary) -> Vector2i:
	var r: Array = t["range"] if not (t["range"] as Array).is_empty() else t.trim
	return Vector2i(int(r[0]), int(r[1]))


func _bar_frames(bpm: int, metre: int, rate: float) -> float:
	return rate * 60.0 / float(maxi(bpm, 1)) * BEATS[metre]


func _track_samples(t: Dictionary) -> PackedFloat32Array:
	if not _samples.has(t.id):
		_samples[t.id] = _load_wav(DIR + t.id + ".wav")
	return _samples[t.id]


func _track_peaks(t: Dictionary) -> PackedFloat32Array:
	if not _peaks.has(t.id):
		var s := _track_samples(t)
		var c := AudioEngine.core()
		_peaks[t.id] = c.waveform(s, PEAKS) if c and not s.is_empty() else PackedFloat32Array()
	return _peaks[t.id]


func _load_index() -> void:
	_tracks.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var raw := FileAccess.get_file_as_string(INDEX)
	var data: Variant = JSON.parse_string(raw) if not raw.is_empty() else []
	if data is Array:
		for t in data:
			if t is Dictionary and FileAccess.file_exists(DIR + str(t.get("id", "")) + ".wav"):
				for key in ["bpm", "metre", "bed", "frames", "num"]:
					t[key] = int(t.get(key, 0))
				t.metre = clampi(int(t.metre), 0, METRES.size() - 1)
				_tracks.append(t)


func _save_index() -> void:
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_tracks, " "))


static func _save_wav(path: String, samples: PackedFloat32Array, rate: int) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var data := samples.to_byte_array()
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(3)          # IEEE float
	f.store_16(1)          # mono
	f.store_32(rate)
	f.store_32(rate * 4)
	f.store_16(4)
	f.store_16(32)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	return true


## WAV: 32-bit float albo 16-bit PCM; przy wielu kanałach – pierwszy kanał.
static func _load_wav(path: String) -> PackedFloat32Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != "RIFF":
		return PackedFloat32Array()
	f.get_32()
	f.get_buffer(4)
	var fmt := 0
	var channels := 1
	var bits := 32
	while f.get_position() + 8 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var size := f.get_32()
		var next := f.get_position() + size + (size & 1)
		if id == "fmt ":
			fmt = f.get_16()
			channels = maxi(f.get_16(), 1)
			f.get_32()
			f.get_32()
			f.get_16()
			bits = f.get_16()
		elif id == "data":
			var bytes := f.get_buffer(size)
			var out := PackedFloat32Array()
			if fmt == 3 and bits == 32:
				out = bytes.to_float32_array()
			elif fmt == 1 and bits == 16:
				var n := bytes.size() / 2
				out.resize(n)
				for i in n:
					out[i] = bytes.decode_s16(i * 2) / 32768.0
			if channels > 1:
				var mono := PackedFloat32Array()
				mono.resize(out.size() / channels)
				for i in mono.size():
					mono[i] = out[i * channels]
				out = mono
			return out
		f.seek(next)
	return PackedFloat32Array()


# --- Teksty --------------------------------------------------------------------------------

func _preset_name() -> String:
	var p := int(App.setting(&"met_preset"))
	return tr(PRESETS[p]) if p >= 0 and p < PRESETS.size() else tr("own")


func _bed_name(bed: int) -> String:
	return _preset_name() if bed == 1 else ""


func _meta_text(bpm: int, metre: int, bed: int, bed_name: String) -> String:
	var b := (tr("drums %s") % bed_name) if bed == 1 else tr("metronome")
	return "%d BPM · %s · %s" % [bpm, METRES[metre], b]


static func time_text(frames: int, rate: float) -> String:
	var s := floori(frames / maxf(rate, 1.0))
	return "%d:%02d" % [s / 60, s % 60]


func _count_text(n: int, on: int) -> String:
	var lang := TranslationServer.get_locale().substr(0, 2)
	var few := func(k: int) -> bool: return k % 10 in [2, 3, 4] and not k % 100 in [12, 13, 14]
	match lang:
		"pl":
			return "%d %s, %d %s" % [n, "ścieżka" if n == 1 else "ścieżki" if few.call(n) else "ścieżek",
					on, "zaznaczona" if on == 1 else "zaznaczone" if few.call(on) else "zaznaczonych"]
		"ru":
			return "%d %s, %d %s" % [n, "дорожка" if n % 10 == 1 and n % 100 != 11 else "дорожки" if few.call(n) else "дорожек",
					on, "отмечена" if on % 10 == 1 and on % 100 != 11 else "отмечено"]
		"de":
			return "%d %s, %d ausgewählt" % [n, "Spur" if n == 1 else "Spuren", on]
		"es":
			return "%d %s, %d %s" % [n, "pista" if n == 1 else "pistas", on, "marcada" if on == 1 else "marcadas"]
	return "%d %s, %d ticked" % [n, "track" if n == 1 else "tracks", on]


# --- Wiersz ścieżki ------------------------------------------------------------------------

## Wiersz listy: pole wyboru, nazwa (do zmiany), opis, fala z przycięciem i zakresem, „Utnij ciszę”, usuń.
class TrackRow extends PanelContainer:
	const TEAL := Color("3FD0C9")
	const RED := Color("FF5A5F")
	var tab: LooperTab
	var t: Dictionary
	var check: CheckBox_
	var name_edit: LineEdit
	var meta: Label
	var info: Label
	var wave: WaveView
	var trim_btn: Button
	var del_btn: Button
	var _selected := false
	var _confirm := false

	func setup(p_tab: LooperTab, p_t: Dictionary) -> void:
		tab = p_tab
		t = p_t
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 17)
		add_child(row)
		check = CheckBox_.new()
		check.on = bool(t.get("on", true))
		check.toggled_on.connect(func(on: bool) -> void:
			t.on = on
			_restyle()
			tab._select(t.id)
			tab.row_changed(t))
		row.add_child(check)
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 235
		col.add_theme_constant_override("separation", 1)
		row.add_child(col)
		name_edit = LineEdit.new()
		name_edit.flat = true
		name_edit.max_length = 60
		name_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_edit.add_theme_font_override("font", ThemeManager.font_body_bold)
		name_edit.add_theme_font_size_override("font_size", ThemeManager.fs(17))
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "read_only"]:
			name_edit.add_theme_stylebox_override(s, empty)
		name_edit.add_theme_stylebox_override("focus", ThemeManager.box(Color("0A0F1F"), Color("26305A"), 6, 1, 4, 0))
		name_edit.text_submitted.connect(func(s: String) -> void:
			tab.row_rename(t, s)
			name_edit.release_focus())
		name_edit.focus_exited.connect(func() -> void:
			if not t.is_empty():
				tab.row_rename(t, name_edit.text)
				name_edit.text = t.name)
		col.add_child(name_edit)
		meta = _small(14, Color("8C96B3"))
		col.add_child(meta)
		info = _small(14, Color("6F7A99"))
		col.add_child(info)
		wave = WaveView.new()
		wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wave.edited.connect(func(final: bool) -> void:
			t.trim = [wave.trim.x, wave.trim.y]
			t["range"] = [wave.span.x, wave.span.y] if wave.span.y > wave.span.x else []
			_update_info()
			tab._select(t.id)
			if final:
				tab.row_changed(t))
		row.add_child(wave)
		trim_btn = _button(tr("Trim silence"), 14)
		trim_btn.tooltip_text = tr("Cuts the silence at the start and the end.")
		trim_btn.pressed.connect(func() -> void: tab.row_trim_silence(t))
		row.add_child(trim_btn)
		del_btn = _button("×", 18)
		del_btn.custom_minimum_size = Vector2(36, 36)
		del_btn.tooltip_text = tr("Delete the track")
		del_btn.pressed.connect(_on_delete)
		row.add_child(del_btn)
		if t.is_empty():
			check.visible = false
			trim_btn.disabled = true
			del_btn.visible = false
			name_edit.editable = false
		_restyle()

	func _small(px: int, c: Color) -> Label:
		var l := Label.new()
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_font_size_override("font_size", ThemeManager.fs(px))
		l.add_theme_color_override("font_color", c)
		return l

	func _button(text: String, px: int) -> Button:
		var b := Button.new()
		b.text = text
		b.focus_mode = Control.FOCUS_NONE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size.y = 36
		b.add_theme_font_override("font", ThemeManager.font_body_bold)
		b.add_theme_font_size_override("font_size", ThemeManager.fs(px))
		b.add_theme_stylebox_override("normal", ThemeManager.box(ThemeManager.color("surface_2"), ThemeManager.color("border_strong"), 9, 1, 12, 4))
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border"), ThemeManager.color("border_strong"), 9, 1, 12, 4))
		b.add_theme_stylebox_override("pressed", ThemeManager.box(ThemeManager.color("border_strong"), ThemeManager.color("border_strong"), 9, 1, 12, 4))
		b.add_theme_stylebox_override("disabled", ThemeManager.box(Color(ThemeManager.color("surface_2"), 0.4), Color(ThemeManager.color("border_strong"), 0.4), 9, 1, 12, 4))
		return b

	func refresh() -> void:
		name_edit.text = t.name
		meta.text = tab._meta_text(int(t.bpm), int(t.metre), int(t.bed), str(t.get("bed_name", "")))
		wave.frames = int(t.frames)
		wave.peak_frames = int(t.frames)
		wave.trim = Vector2i(int(t.trim[0]), int(t.trim[1]))
		wave.span = Vector2i(int(t["range"][0]), int(t["range"][1])) if not (t["range"] as Array).is_empty() else Vector2i.ZERO
		wave.queue_redraw()
		_update_info()

	func _update_info() -> void:
		var rate := float(t.rate)
		var txt := ""
		if wave.span.y > wave.span.x:
			txt = tr("range %s–%s") % [LooperTab.time_text(wave.span.x, rate), LooperTab.time_text(wave.span.y, rate)] + " · "
		info.text = txt + LooperTab.time_text(int(t.frames), rate)
		info.add_theme_color_override("font_color", Color("6F7A99"))

	func set_live(title: String, meta_text: String) -> void:
		name_edit.text = title
		meta.text = meta_text
		info.add_theme_color_override("font_color", Color("FF8A8E"))
		wave.live = true
		_selected = true
		_restyle()

	func set_status(s: String) -> void:
		info.text = s

	func set_selected(on: bool) -> void:
		_selected = on
		_restyle()

	func _restyle() -> void:
		var on := t.is_empty() or bool(t.get("on", true))
		var border: Color = (RED if t.is_empty() else Color("26305A")) if _selected else Color.TRANSPARENT
		add_theme_stylebox_override("panel", ThemeManager.box(Color("121933") if on else Color("0F1428"), border, 14, 1, 17, 12))
		name_edit.add_theme_color_override("font_color", ThemeManager.color("text") if on else ThemeManager.color("muted"))

	func _on_delete() -> void:
		if not _confirm:
			_confirm = true
			del_btn.text = tr("Delete?")
			del_btn.add_theme_color_override("font_color", RED)
			get_tree().create_timer(3.0).timeout.connect(func() -> void:
				if is_instance_valid(del_btn):
					_confirm = false
					del_btn.text = "×"
					del_btn.remove_theme_color_override("font_color"))
			return
		tab.row_delete(t)


## Pole wyboru rysowane jak w makiecie (turkusowy kwadrat z ptaszkiem).
class CheckBox_ extends Control:
	const TEAL := Color("3FD0C9")
	const RED := Color("FF5A5F")
	signal toggled_on(on: bool)
	var on := true

	func _init() -> void:
		custom_minimum_size = Vector2(26, 26)
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
		var r := Rect2(Vector2.ZERO, size)
		if on:
			draw_style_box(ThemeManager.box(TEAL, Color.TRANSPARENT, 7, 0, 0, 0), r)
			var p := PackedVector2Array([Vector2(size.x * 0.25, size.y * 0.52), Vector2(size.x * 0.43, size.y * 0.70),
					Vector2(size.x * 0.76, size.y * 0.32)])
			draw_polyline(p, Color("04201E"), 3.0, true)
		else:
			draw_style_box(ThemeManager.box(Color.TRANSPARENT, Color("3A4566"), 7, 2, 0, 0), r)


## Fala ścieżki: słupki szczytów, przyciemnione przycięte końce z pomarańczowymi uchwytami (przeciągane),
## turkusowa ramka wybranego zakresu (przeciągnięcie po fali; kliknięcie bez przeciągania – bez zakresu)
## i biała kreska odtwarzania.
class WaveView extends Control:
	const TEAL := Color("3FD0C9")
	const RED := Color("FF5A5F")
	signal edited(final: bool)
	const BAR_W := 6.7
	var peaks := PackedFloat32Array()
	var frames := 1             # długość ścieżki (szerokość fali)
	var peak_frames := 1        # ile próbek obejmują szczyty (przy nagrywaniu mniej niż `frames`)
	var trim := Vector2i.ZERO
	var span := Vector2i.ZERO
	var head := -1
	var live := false
	var _drag := ""
	var _anchor := 0

	func _init() -> void:
		custom_minimum_size = Vector2(320, 55)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_default_cursor_shape = Control.CURSOR_IBEAM

	func set_head(f: int) -> void:
		if f != head:
			head = f
			queue_redraw()

	func _x(f: int) -> float:
		return size.x * float(f) / float(maxi(frames, 1))

	func _f(x: float) -> int:
		return clampi(roundi(x / maxf(size.x, 1.0) * frames), 0, frames)

	func _gui_input(e: InputEvent) -> void:
		if live or frames <= 1:
			return
		var mb := e as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if absf(mb.position.x - _x(trim.x)) < 9.0:
					_drag = "a"
				elif absf(mb.position.x - _x(trim.y)) < 9.0:
					_drag = "b"
				else:
					_drag = "sel"
					_anchor = clampi(_f(mb.position.x), trim.x, trim.y)
					span = Vector2i(_anchor, _anchor)
			else:
				if _drag == "sel" and absf(_x(span.y) - _x(span.x)) < 4.0:
					span = Vector2i.ZERO
				_drag = ""
				queue_redraw()
				edited.emit(true)
			accept_event()
			return
		var mm := e as InputEventMouseMotion
		if mm and not _drag.is_empty():
			var f := _f(mm.position.x)
			match _drag:
				"a":
					trim.x = clampi(f, 0, trim.y - 1)
				"b":
					trim.y = clampi(f, trim.x + 1, frames)
				"sel":
					f = clampi(f, trim.x, trim.y)
					span = Vector2i(mini(_anchor, f), maxi(_anchor, f))
			if span.y > span.x:
				span = Vector2i(clampi(span.x, trim.x, trim.y), clampi(span.y, trim.x, trim.y))
			queue_redraw()
			edited.emit(false)
			accept_event()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_style_box(ThemeManager.box(Color("0A0F1F"), Color.TRANSPARENT, 9, 0, 0, 0), Rect2(Vector2.ZERO, size))
		var n := maxi(int(w / BAR_W), 1)
		var bw := w / n
		var top := 0.05
		for p in peaks:
			top = maxf(top, p)
		var has_range := span.y > span.x
		for i in n:
			var f0 := int(float(i) / n * frames)
			var f1 := int(float(i + 1) / n * frames)
			var a := 0.0
			if not peaks.is_empty() and f0 < peak_frames:
				var k0 := int(float(f0) / peak_frames * peaks.size())
				var k1 := maxi(k0 + 1, int(float(mini(f1, peak_frames)) / peak_frames * peaks.size()))
				for k in range(k0, mini(k1, peaks.size())):
					a = maxf(a, peaks[k])
				a /= top
			var bh := maxf(2.0, sqrt(a) * (h - 8.0))
			var mid := (f0 + f1) / 2
			var col: Color
			if live:
				col = RED
			elif mid < trim.x or mid > trim.y:
				col = Color("3A4566")
			elif has_range and (mid < span.x or mid > span.y):
				col = Color("2E6F75")
			else:
				col = TEAL
			if f0 >= peak_frames and live:
				col = Color("26305A")
				bh = 2.0
			draw_rect(Rect2(i * bw + 0.6, (h - bh) * 0.5, bw - 1.6, bh), col)
		if not live:
			var shade := Color("04060D", 0.55)
			draw_rect(Rect2(0, 0, _x(trim.x), h), shade)
			draw_rect(Rect2(_x(trim.y), 0, w - _x(trim.y), h), shade)
			var orange := ThemeManager.color("accent")
			for x in [_x(trim.x), _x(trim.y)]:
				draw_rect(Rect2(x - 1.5, 0, 3, h), orange)
				draw_style_box(ThemeManager.box(orange, Color.TRANSPARENT, 3, 0, 0, 0), Rect2(x - 5, h * 0.5 - 9, 10, 18))
			if has_range:
				var r := Rect2(_x(span.x), 1, _x(span.y) - _x(span.x), h - 2)
				draw_style_box(ThemeManager.box(Color(TEAL, 0.10), TEAL, 5, 2, 0, 0), r)
		if head >= 0 and head <= frames:
			draw_rect(Rect2(_x(head) - 1.0, 0, 2.0, h), Color.WHITE)
