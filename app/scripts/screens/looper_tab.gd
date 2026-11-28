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
const RED := Color("FF5A5F")
const STOP := Color("FF7A59")
const MAX_SECONDS := 600.0            # najdłuższe nagranie (ok. 115 MB w pamięci i na dysku przy 48 kHz)
const WARN_SECONDS := 30.0            # ostrzeżenie przed końcem dozwolonego czasu
const DISK_RESERVE := 64 << 20        # tyle miejsca na dysku zostawiamy zawsze wolne (bajty)
const MIN_SECONDS := 5.0              # mniej miejsca na nagranie – nie zaczynamy
const STALL_MS := 1500                # wejście nie daje próbek tak długo – urządzenie odłączone albo zawieszone
const REC_BARS := [0, 1, 2, 4, 8, 16]   # długość nagrania w taktach (0 – dowolna, do zatrzymania)
const TOGGLE_GUARD_MS := 600            # po starcie albo końcu nagrania przycisk/R chwilę nie działa
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
var _toggle_at := -100000             # chwila ostatniego startu albo końca nagrania (ms)
var _retry: Button                    # „Zapisz ponownie” – po nieudanym zapisie nagrania
var _pending := {}                    # nagranie, którego nie udało się zapisać (rec + próbki)
var _test_free := -1                  # tylko test (--looper-test): udawane wolne miejsce w bajtach
var _test_fail := false               # tylko test: udawany błąd zapisu


func _init(screen: Node) -> void:
	scr = screen


# --- Budowa -------------------------------------------------------------------------------

func build(main: VBoxContainer, aside: VBoxContainer) -> void:
	_core = AudioEngine.ensure_open()
	_load_index()
	if "--looper-test" in OS.get_cmdline_user_args():
		_selftest.call_deferred()

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
	var hint: Label = scr._label("tempo of a new recording", 16, ThemeManager.color("hint"))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)

	main.add_child(scr._gap(31))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	main.add_child(head)
	head.add_child(scr._label("Recorded tracks", 22, ThemeManager.color("text"), ThemeManager.font_heading))
	var h2: Label = scr._label("ticked tracks play together · drag across the wave to choose a range", 16, ThemeManager.color("hint"))
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
	_empty = scr._label("No recordings yet. Press „Record new” (R) – you always record along with the drum machine or the metronome.", 17, ThemeManager.color("hint"))
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
	legend.add_child(scr._label("A track remembers the tempo, metre and backing of its recording.", 16, ThemeManager.color("hint")))

	main.add_child(scr._gap(18))
	_error = scr._label("", 15, STOP)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.visible = false
	main.add_child(_error)
	_retry = Button.new()
	_retry.text = "Save again"
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retry.visible = false
	_retry.pressed.connect(_save_pending)
	main.add_child(_retry)
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
	var note: Label = scr._label("", 14, ThemeManager.color("hint"))
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
	rc.add_child(scr._field("Recording length", scr._chips_row(["free", "1 bar", "2 bars", "4 bars", "8 bars", "16 bars"],
			int(App.setting(&"lp_rec_bars")), true, func(i: int) -> void:
				App.set_setting(&"lp_rec_bars", i), true)))
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
	_level_label = scr._label("", 16, ThemeManager.color("focus"))
	_level_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lh.add_child(_level_label)
	_level_bar = Panel.new()
	_level_bar.custom_minimum_size.y = 10
	_level_bar.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("border"), Color.TRANSPARENT, 5, 0, 0, 0))
	lv.add_child(_level_bar)
	_level_fill = Panel.new()
	_level_fill.add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("focus"), Color.TRANSPARENT, 5, 0, 0, 0))
	_level_bar.add_child(_level_fill)
	rc.add_child(scr._label("Space – playback · R – recording", 14, ThemeManager.color("hint")))


func _outline_item(text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var sw := Panel.new()
	sw.custom_minimum_size = Vector2(11, 11)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.add_theme_stylebox_override("panel", ThemeManager.box(Color.TRANSPARENT, ThemeManager.color("focus"), 3, 2, 0, 0))
	h.add_child(sw)
	h.add_child(scr._label(text, 16, ThemeManager.color("hint")))
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
	_play.icon = ButtonGlyph.icon("stop" if _playing else "play", ThemeManager.color("accent_text"))
	_play.add_theme_constant_override("h_separation", 10)
	var bg: Color = STOP if _playing else ThemeManager.color("accent")
	var dark := ThemeManager.color("accent_text")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_play.add_theme_color_override(c, dark)
	_play.add_theme_stylebox_override("normal", ThemeManager.box(bg, Color.TRANSPARENT, 14, 0, 36, 10))
	_play.add_theme_stylebox_override("hover", ThemeManager.box(bg.lightened(0.1), Color.TRANSPARENT, 14, 0, 36, 10))
	_play.add_theme_stylebox_override("pressed", ThemeManager.box(bg.darkened(0.1), Color.TRANSPARENT, 14, 0, 36, 10))
	var rec := not _rec.is_empty()
	_record.text = tr("Finish recording") if rec else tr("Record new")
	var rbg := RED if rec else Color(RED, 0.10)
	var fg := Color.WHITE if rec else Color("FF8A8E")
	_record.icon = ButtonGlyph.icon("stop" if rec else "dot", fg if rec else RED)
	_record.add_theme_constant_override("h_separation", 10)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_record.add_theme_color_override(c, fg)
	_record.add_theme_stylebox_override("normal", ThemeManager.box(rbg, RED, 14, 1, 31, 10))
	_record.add_theme_stylebox_override("hover", ThemeManager.box(rbg.lightened(0.08) if rec else Color(RED, 0.18), RED, 14, 1, 31, 10))
	_record.add_theme_stylebox_override("pressed", ThemeManager.box(Color(RED, 0.3), RED, 14, 1, 31, 10))


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
func _configure(bpm: int, metre: int, bed: int, countin := 0, bars := 0) -> void:
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
		# Odliczanie przed nagraniem: przy automacie same pałeczki na każde uderzenie (jak perkusista),
		# przy metronomie – jego kliknięcia.
		"countin_bars": countin, "countin_sticks": bed == 1,
		"play_bars": countin + bars if bars > 0 else 0,
	}, flat)


# --- Nagrywanie ----------------------------------------------------------------------------

func toggle_record() -> void:
	# Ochrona przed podwójnym kliknięciem i kliknięciem „Zakończ” w chwili, gdy nagranie właśnie samo się
	# skończyło: bez niej drugie naciśnięcie zaczynałoby od razu nowe nagranie.
	if Time.get_ticks_msec() - _toggle_at < TOGGLE_GUARD_MS:
		return
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
	var rate0: float = _core.sample_rate()
	var limit := _space_seconds(rate0)
	if limit < MIN_SECONDS:
		_show_error(tr("Not enough free disk space to record – free up some space and try again."))
		return
	_show_error("")
	var bpm: int = scr._bpm()
	var metre: int = scr._metre()
	var bed := 1 if int(App.setting(&"lp_rec_with")) == 0 else 2
	var rate: float = _core.sample_rate()
	var countin := int(App.setting(&"lp_countin"))
	var rec_bars := int(REC_BARS[clampi(int(App.setting(&"lp_rec_bars")), 0, REC_BARS.size() - 1)])
	_configure(bpm, metre, bed, countin, rec_bars)
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
			"bars": rec_bars, "limit": limit, "seen": Time.get_ticks_msec(), "checked": Time.get_ticks_msec(),
			"out": -1, "next": -1, "buf": PackedFloat32Array()}
	_toggle_at = Time.get_ticks_msec()
	_live = _add_row({}, true)
	_live.set_live(tr("New recording"), _meta_text(bpm, metre, bed, _bed_name(bed)))
	_update_empty()
	_update_buttons()


func _poll_record(v: Dictionary) -> void:
	# Strumień stoi (urządzenie odłączone, sterownik zawieszony): rdzeń dawno nie dostał wywołania.
	if _core.has_method(&"stream_age_ms") and float(_core.stream_age_ms()) > STALL_MS:
		_finish_record(false, tr("The audio device stopped responding – recording stopped."))
		return
	var cs := int(v.clock_start)
	if int(_rec.next) < 0:
		if cs < 0:
			return
		var out := cs + roundi(int(_rec.countin) * _bar_frames(int(_rec.bpm), int(_rec.metre), float(_rec.rate)))
		_rec.out = out
		# Próbka wejścia z chwili, w której zabrzmi „raz” pierwszego taktu (opóźnienie wejścia i wyjścia,
		# osobne zegary urządzeń, pomiar i ręczna korekta z ustawień dźwięku).
		_rec.next = AudioEngine.input_frame_for(_core, out)
	if not _core.is_open() or not _core.input_ok():
		_finish_record(false, tr("The audio device stopped responding – recording stopped."))
		return
	var chunk: Variant = _core.input_read(int(_rec.next), 1 << 17)
	if chunk == null:
		_finish_record(false, tr("Recording interrupted – the input was not read in time."))
		return
	var now := Time.get_ticks_msec()
	if (chunk as PackedFloat32Array).size() > 0 or int(v.frame) < int(_rec.out):
		_rec.seen = now
	elif now - int(_rec.seen) > STALL_MS:
		# Wejście przestało dawać próbki (urządzenie odłączone albo zawieszone).
		_finish_record(false, tr("The audio input stopped responding – recording stopped."))
		return
	var buf: PackedFloat32Array = _rec.buf
	buf.append_array(chunk)
	_rec.buf = buf
	_rec.next = int(_rec.next) + (chunk as PackedFloat32Array).size()
	var bar := _bar_frames(int(_rec.bpm), int(_rec.metre), float(_rec.rate))
	var heard := int(v.frame)
	var bars := int(_rec.bars)
	var status: String
	if heard < int(_rec.out):
		# Odliczanie uderzeniami: 4, 3, 2, 1 (w 2 taktach – od 8).
		var beat := bar / float(BEATS[int(_rec.metre)])
		status = tr("count-in: %d") % maxi(ceili((int(_rec.out) - heard) / beat), 1)
	else:
		var n := floori((heard - int(_rec.out)) / bar) + 1
		if bars > 0:
			status = tr("recording · bar %d of %d") % [mini(n, bars), bars]
		else:
			# Dowolna długość: pozostały czas widoczny cały czas, ostatnie 30 s jako ostrzeżenie.
			var left := maxf(_limit_frames() - (heard - int(_rec.out)), 0.0) / float(_rec.rate)
			status = tr("recording · bar %d") % n + " · " + (tr("%s left – the recording will stop at the end of a bar")
					if left <= WARN_SECONDS else tr("%s left")) % _clock(left)
	_live.set_status(status)
	_live_tick += 1
	if _live_tick % 6 == 0 and buf.size() > 0:
		var span := maxf(buf.size(), bar * 4.0)
		_live.wave.frames = int(span)
		_live.wave.peaks = _core.waveform(buf, maxi(1, roundi(PEAKS * buf.size() / span)))
		_live.wave.peak_frames = buf.size()
		_live.wave.trim = Vector2i(0, buf.size())
		_live.wave.queue_redraw()
	# Zadana liczba taktów albo limit czasu / miejsca (zaokrąglony w dół do pełnych taktów): koniec
	# dokładnie na granicy taktu, nagranie przycięte co do próbki.
	var target := roundi(bars * bar) if bars > 0 else roundi(_limit_frames())
	if buf.size() >= target:
		buf.resize(target)
		_rec.buf = buf
		_finish_record(true, "" if bars > 0 else tr("The maximum recording length was reached – the recording was saved."))
		return
	# Co 2 s: czy na dysku nadal jest miejsce na to, co już nagrane (inne programy też zapisują).
	if now - int(_rec.checked) > 2000:
		_rec.checked = now
		if _space_seconds(float(_rec.rate)) < buf.size() / float(_rec.rate) + 2.0:
			_finish_record(false, tr("The disk is almost full – recording stopped."))


## Limit nagrania w próbkach: mniejszy z 10 minut i wolnego miejsca, w pełnych taktach.
func _limit_frames() -> float:
	var bar := _bar_frames(int(_rec.bpm), int(_rec.metre), float(_rec.rate))
	var frames := minf(MAX_SECONDS, float(_rec.limit)) * float(_rec.rate)
	return maxf(floorf(frames / bar), 1.0) * bar


## Ile sekund nagrania (32-bit float, mono) zmieści się na dysku, z zapasem DISK_RESERVE.
func _space_seconds(rate: float) -> float:
	DirAccess.make_dir_recursive_absolute(DIR)
	var d := DirAccess.open(DIR)
	if d == null or rate <= 0.0:
		return 0.0
	var free := d.get_space_left() if _test_free < 0 else _test_free
	if free <= 0:
		return MAX_SECONDS   # system nie podaje wolnego miejsca – zapis i tak jest sprawdzany
	return maxf(float(free - DISK_RESERVE), 0.0) / (rate * 4.0)


static func _clock(sec: float) -> String:
	var s := ceili(sec)
	return "%d:%02d" % [s / 60, s % 60]


func _finish_record(complete := false, reason := "") -> void:
	if _rec.is_empty():
		return
	_toggle_at = Time.get_ticks_msec()
	if int(_rec.next) >= 0 and not complete:
		var chunk: Variant = _core.input_read(int(_rec.next), 1 << 17)
		if chunk != null:
			var b: PackedFloat32Array = _rec.buf
			b.append_array(chunk)
			var most := roundi(int(_rec.bars) * _bar_frames(int(_rec.bpm), int(_rec.metre), float(_rec.rate)))
			if most > 0 and b.size() > most:
				b.resize(most)
			_rec.buf = b
	var rec := _rec
	_rec = {}
	stop_all()
	var buf: PackedFloat32Array = rec.buf
	if buf.size() < float(rec.rate) * 0.3:
		_show_error((reason + " " if not reason.is_empty() else "") + tr("The recording is too short – it was not saved."))
		return
	_show_error(reason)
	_store(rec, buf)


# Zapis nagrania: plik WAV (atomowo – najpierw plik tymczasowy) i opis ścieżki. Gdy się nie uda
# (np. brak miejsca), nagranie zostaje w pamięci, a przycisk „Zapisz ponownie” ponawia zapis.
func _store(rec: Dictionary, buf: PackedFloat32Array) -> void:
	var t := _new_track(rec, buf.size())
	if _test_fail or not _save_wav(DIR + t.id + ".wav", buf, int(rec.rate)):
		_pending = {"rec": rec, "buf": buf}
		_show_error(tr("Could not save the recording – the disk may be full. The recording is kept in memory: free up some space and press „Save again”."))
		_retry.visible = true
		return
	_pending = {}
	_retry.visible = false
	_samples[t.id] = buf
	_tracks.insert(0, t)
	_save_index()
	_add_row(t, true)
	_select(t.id)
	_update_empty()
	scr._update_texts()


func _save_pending() -> void:
	if _pending.is_empty():
		_retry.visible = false
		return
	_show_error("")
	_store(_pending.rec, _pending.buf)


func _new_track(rec: Dictionary, frames: int) -> Dictionary:
	var n := 1
	for t in _tracks:
		n = maxi(n, int(t.get("num", 0)) + 1)
	var bed := int(rec.bed)
	return {"id": "%d" % Time.get_unix_time_from_system() + "_%d" % randi_range(1000, 9999), "num": n,
		"name": tr("Recording %d") % n, "bpm": int(rec.bpm), "metre": int(rec.metre), "bed": bed,
		"bed_name": _bed_name(bed), "rate": float(rec.rate), "frames": frames,
		"trim": [0, frames], "range": [], "on": true}


# Test nagrywania (-- --looper-test, bez zapisu ustawień): 1 takt odliczania i 1 takt nagrania przy
# 120 BPM, podwójne naciśnięcie, naciśnięcie tuż po samoczynnym końcu, zatrzymanie ręczne przed końcem.
func _selftest() -> void:
	var tree := scr.get_tree()
	App.set_settings({&"lp_rec_bars": 1, &"lp_countin": 1, &"lp_rec_with": 0, &"met_bpm": 120})
	await tree.create_timer(1.0).timeout
	var m: Dictionary = await AudioEngine.measure_latency()
	print("[looper-test] pomiar: ", m)
	if m.ok:
		AudioEngine.set_latency_fix("measured", float(m.residual_ms))
	var n0 := _tracks.size()
	toggle_record()
	toggle_record()
	print("[looper-test] podwójne naciśnięcie: nagrywa nadal = ", not _rec.is_empty())
	var t0 := Time.get_ticks_msec()
	while not _rec.is_empty() and Time.get_ticks_msec() - t0 < 10000:
		await tree.create_timer(0.5).timeout
		if not _rec.is_empty():
			print("[looper-test] stan: next %d, próbek %d, zegar %s, wejście %d" % [int(_rec.next),
					(_rec.buf as PackedFloat32Array).size(), str(_core.visual_state()), _core.input_frames()])
	var bar := _bar_frames(120, scr._metre(), _core.sample_rate()) if _core else 0.0
	print("[looper-test] komunikat: '%s', zgranie: %s" % [_error.text if _error else "", _core.timing_info() if _core else {}])
	print("[looper-test] samoczynny koniec po %d ms, ścieżek +%d, długość %d próbek (takt %d)" % [
			Time.get_ticks_msec() - t0, _tracks.size() - n0, int(_tracks[0].frames) if _tracks.size() > n0 else -1, roundi(bar)])
	if _tracks.size() > n0:
		# Przy pętli zwrotnej nagranie zawiera sam podkład: pierwsze uderzenie ma wypaść w próbce 0.
		var smp := _track_samples(_tracks[0])
		var pk := 0.0
		for v in smp:
			pk = maxf(pk, absf(v))
		for k in smp.size():
			if pk > 0.01 and absf(smp[k]) >= pk * 0.3:
				print("[looper-test] pierwsze uderzenie w nagraniu: %.2f ms od początku" % (k * 1000.0 / _core.sample_rate()))
				break
	toggle_record()
	print("[looper-test] naciśnięcie tuż po końcu: nowe nagranie = ", not _rec.is_empty())
	await tree.create_timer(1.0).timeout
	toggle_record()
	await tree.create_timer(3.0).timeout
	toggle_record()
	print("[looper-test] koniec ręczny przed czasem: ścieżek +%d, długość %d próbek" % [_tracks.size() - n0,
			int(_tracks[0].frames) if _tracks.size() > n0 else -1])
	print("[looper-test] zgranie: ", _core.timing_info() if _core else {})
	# Zabezpieczenia: brak miejsca przed startem, limit miejsca w trakcie (dowolna długość), błąd zapisu.
	App.set_settings({&"lp_rec_bars": 0, &"lp_countin": 0})
	await tree.create_timer(1.0).timeout
	_test_free = DISK_RESERVE + int(_core.sample_rate() * 4 * 3)
	toggle_record()
	print("[looper-test] 3 s miejsca: nagrywa = %s, komunikat: %s" % [not _rec.is_empty(), _error.text])
	await tree.create_timer(1.0).timeout
	_test_free = DISK_RESERVE + int(_core.sample_rate() * 4 * 7)
	var n1 := _tracks.size()
	toggle_record()
	var t1 := Time.get_ticks_msec()
	var shown := ""
	while not _rec.is_empty() and Time.get_ticks_msec() - t1 < 15000:
		await tree.create_timer(0.5).timeout
		if _live and is_instance_valid(_live):
			shown = _live.info.text
	print("[looper-test] 7 s miejsca: koniec po %d ms, ścieżek +%d, długość %.2f s (%.2f taktu), status: %s, komunikat: %s" % [
			Time.get_ticks_msec() - t1, _tracks.size() - n1, float(_tracks[0].frames) / _core.sample_rate(),
			float(_tracks[0].frames) / _bar_frames(120, scr._metre(), _core.sample_rate()), shown, _error.text])
	_test_free = -1
	_test_fail = true
	await tree.create_timer(1.0).timeout
	toggle_record()
	await tree.create_timer(2.0).timeout
	toggle_record()
	print("[looper-test] błąd zapisu: czeka w pamięci = %s, przycisk = %s, komunikat: %s" % [not _pending.is_empty(), _retry.visible, _error.text])
	_test_fail = false
	var n2 := _tracks.size()
	_retry.pressed.emit()
	print("[looper-test] zapisz ponownie: ścieżek +%d, czeka = %s, przycisk = %s" % [_tracks.size() - n2, not _pending.is_empty(), _retry.visible])
	var part := 0
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".part"):
			part += 1
	print("[looper-test] pliki tymczasowe .part: ", part)
	if OS.has_environment("FBM_TEST_KILL_AUDIO"):
		# Urządzenie znika w trakcie: test zewnętrzny zatrzymuje serwer dźwięku po ok. 2 s nagrywania.
		await tree.create_timer(1.0).timeout
		var n3 := _tracks.size()
		toggle_record()
		print("[looper-test] odłączenie: start")
		var t3 := Time.get_ticks_msec()
		while not _rec.is_empty() and Time.get_ticks_msec() - t3 < 12000:
			await tree.process_frame
		print("[looper-test] odłączenie: koniec po %d ms, ścieżek +%d, komunikat: %s" % [Time.get_ticks_msec() - t3, _tracks.size() - n3, _error.text])
	tree.quit()


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
	# Atomowo: plik tymczasowy, potem podmiana – przerwany zapis nie psuje listy ścieżek.
	var tmp := INDEX + ".part"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_tracks, " "))
	var ok := f.get_error() == OK
	f.close()
	if ok:
		DirAccess.remove_absolute(INDEX)
		ok = DirAccess.rename_absolute(tmp, INDEX) == OK
	if not ok:
		DirAccess.remove_absolute(tmp)
		_show_error(tr("Could not save the track list – the disk may be full."))


## Zapis WAV (32-bit float, mono) atomowo: plik tymczasowy, sprawdzenie błędu i długości, dopiero
## wtedy zmiana nazwy. Nieudany zapis (np. brak miejsca) nie zostawia uszkodzonego pliku.
static func _save_wav(path: String, samples: PackedFloat32Array, rate: int) -> bool:
	var tmp := path + ".part"
	if not _write_wav(tmp, samples, rate):
		DirAccess.remove_absolute(tmp)
		return false
	DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return true


static func _write_wav(path: String, samples: PackedFloat32Array, rate: int) -> bool:
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
	var ok := f.get_error() == OK and f.get_position() == 44 + data.size()
	f.close()
	return ok and FileAccess.get_size(path) == 44 + data.size()


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
		name_edit.add_theme_stylebox_override("focus", ThemeManager.box(ThemeManager.color("well"), ThemeManager.color("border_strong"), 6, 1, 4, 0))
		name_edit.text_submitted.connect(func(s: String) -> void:
			tab.row_rename(t, s)
			name_edit.release_focus())
		name_edit.focus_exited.connect(func() -> void:
			if not t.is_empty():
				tab.row_rename(t, name_edit.text)
				name_edit.text = t.name)
		col.add_child(name_edit)
		meta = _small(14, ThemeManager.color("hint"))
		col.add_child(meta)
		info = _small(14, ThemeManager.color("faint"))
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
		info.add_theme_color_override("font_color", ThemeManager.color("faint"))

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
		var border: Color = (RED if t.is_empty() else ThemeManager.color("border_strong")) if _selected else Color.TRANSPARENT
		add_theme_stylebox_override("panel", ThemeManager.box(ThemeManager.color("surface_2") if on else ThemeManager.color("surface_low"), border, 14, 1, 17, 12))
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
			draw_style_box(ThemeManager.box(ThemeManager.color("focus"), Color.TRANSPARENT, 7, 0, 0, 0), r)
			var p := PackedVector2Array([Vector2(size.x * 0.25, size.y * 0.52), Vector2(size.x * 0.43, size.y * 0.70),
					Vector2(size.x * 0.76, size.y * 0.32)])
			draw_polyline(p, Color("04201E"), 3.0, true)
		else:
			draw_style_box(ThemeManager.box(Color.TRANSPARENT, ThemeManager.color("placeholder"), 7, 2, 0, 0), r)


## Fala ścieżki: słupki szczytów, przyciemnione przycięte końce z pomarańczowymi uchwytami (przeciągane),
## turkusowa ramka wybranego zakresu (przeciągnięcie po fali; kliknięcie bez przeciągania – bez zakresu)
## i biała kreska odtwarzania.
class WaveView extends Control:
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
		draw_style_box(ThemeManager.box(ThemeManager.color("well"), Color.TRANSPARENT, 9, 0, 0, 0), Rect2(Vector2.ZERO, size))
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
				col = ThemeManager.color("placeholder")
			elif has_range and (mid < span.x or mid > span.y):
				col = Color("2E6F75")
			else:
				col = ThemeManager.color("focus")
			if f0 >= peak_frames and live:
				col = ThemeManager.color("border_strong")
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
				draw_style_box(ThemeManager.box(Color(ThemeManager.color("focus"), 0.10), ThemeManager.color("focus"), 5, 2, 0, 0), r)
		if head >= 0 and head <= frames:
			draw_rect(Rect2(_x(head) - 1.0, 0, 2.0, h), ThemeManager.color("text"))
