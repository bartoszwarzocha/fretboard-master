# Fretboard Master – dostęp do rdzenia audio w C++ (singleton FbmAudio): otwarcie wyjścia według
# ustawień (sterownik, urządzenie, bufor w próbkach), wczytanie brzmień SoundFont, głośność.
# Wyjście otwiera się przy pierwszym użyciu i otwiera ponownie po zmianie ustawień dźwięku.
# Gdy rdzeń nie jest zbudowany (sam GDScript), available() zwraca false.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name AudioEngine
extends RefCounted

const SOUNDFONT := "res://assets/sound/GeneralUser-GS.sf2"
const REOPEN_KEYS := [&"audio_driver", &"audio_output", &"audio_input", &"input_channel", &"buffer_samples"]

static var _core: Object
static var _ready := false
static var _error := ""


static func available() -> bool:
	return Engine.has_singleton(&"FbmAudio")


static func core() -> Object:
	if _core == null and available():
		_core = Engine.get_singleton(&"FbmAudio")
	return _core


## Rdzeń z otwartym wyjściem (albo null, gdy się nie udało – powód w last_error()).
static func ensure_open() -> Object:
	var c := core()
	if c == null:
		_error = "core"
		return null
	if not _ready:
		_ready = true
		App.settings_changed.connect(_on_setting)
		var data := FileAccess.get_file_as_bytes(SOUNDFONT)
		if data.is_empty() or not c.load_soundfont(data):
			push_warning("FbmAudio: SoundFont not loaded")
		c.set_volume(int(App.setting(&"output_volume")) / 100.0)
		_apply_pitch_min(c)
	if not c.is_open():
		_open()
	return c if c.is_open() else null


# Najniższy rozpoznawany dźwięk: bas schodzi do H0 (30,9 Hz), gitara – do ok. 55 Hz.
static func _apply_pitch_min(c: Object) -> void:
	if c.has_method(&"set_pitch_min"):
		c.set_pitch_min(27.0 if Instrument.is_bass() else 55.0)


static func last_error() -> String:
	return _error


## Sterowniki dostępne w rdzeniu (asio, wasapi, wdm_ks; na Linuksie alsa).
static func drivers() -> PackedStringArray:
	var c := core()
	return c.host_apis() if c else PackedStringArray()


static func output_devices(driver: String) -> PackedStringArray:
	var c := core()
	return c.output_devices(driver) if c else PackedStringArray()


## Sterownik do otwarcia: wybrany w ustawieniach, a gdy go nie ma w systemie – pierwszy dostępny.
static func driver() -> String:
	var want := str(App.setting(&"audio_driver"))
	var list := drivers()
	if want in list or list.is_empty():
		return want
	return list[0]


static func input_devices(driver: String) -> PackedStringArray:
	var c := core()
	return c.input_devices(driver) if c else PackedStringArray()


static func _open() -> void:
	var c := core()
	var input := str(App.setting(&"audio_input"))
	var channel := int(App.setting(&"input_channel"))
	var buffer := int(App.setting(&"buffer_samples"))
	_error = c.open(driver(), str(App.setting(&"audio_output")), input, channel, buffer)
	if not _error.is_empty():
		# Urządzenie z ustawień niedostępne (np. odłączone) – próba z domyślnym.
		_error = c.open(driver(), "Default", input, channel, buffer)
	elif not c.input_ok() and input != "Default":
		_error = c.open(driver(), str(App.setting(&"audio_output")), "Default", channel, buffer)


# --- Opóźnienie nagrania (looper) ----------------------------------------------------------
# Rdzeń zgrywa wejście z wyjściem według czasów przetworników podawanych przez sterownik. Sterownik
# nie zna jednak opóźnienia samych przetworników i kabli – to dopełnia pomiar (impuls na wyjściu
# wraca na wejście) i ręczna korekta. Oba zapisane osobno dla sterownika, urządzeń i bufora.

static func latency_key() -> String:
	return "%s|%s|%s|%d" % [driver(), str(App.setting(&"audio_output")), str(App.setting(&"audio_input")),
			int(App.setting(&"buffer_samples"))]


## {"measured": ms (dopełnienie z pomiaru), "manual": ms (ręczna korekta)} dla bieżących urządzeń.
static func latency_fix() -> Dictionary:
	var all: Variant = App.setting(&"latency_fix")
	return (all as Dictionary).get(latency_key(), {}) if all is Dictionary else {}


static func set_latency_fix(field: String, ms: float) -> void:
	var all: Dictionary = (App.setting(&"latency_fix") as Dictionary).duplicate(true) \
			if App.setting(&"latency_fix") is Dictionary else {}
	var e: Dictionary = (all.get(latency_key(), {}) as Dictionary).duplicate()
	e[field] = snappedf(ms, 0.1)
	all[latency_key()] = e
	App.set_setting(&"latency_fix", all)


## Numer próbki wejścia nagranej w chwili, gdy brzmi próbka wyjścia `out_frame` (z korektami).
static func input_frame_for(c: Object, out_frame: int) -> int:
	var f := latency_fix()
	var fix := roundi((float(f.get("measured", 0.0)) + float(f.get("manual", 0.0))) * float(c.sample_rate()) / 1000.0)
	if c.has_method(&"input_frame_at"):
		return int(c.input_frame_at(out_frame)) + fix
	return out_frame + int(c.latency_frames()) + fix


## Opóźnienie wyjście → wejście w ms, które looper kompensuje (wg sterownika + korekty); −1 – brak wejścia.
static func roundtrip_ms() -> float:
	var c := core()
	if c == null or not c.is_open() or not c.input_ok() or not c.has_method(&"timing_info"):
		return -1.0
	var f := latency_fix()
	return float(c.timing_info().get("roundtrip_ms", 0.0)) + float(f.get("measured", 0.0)) + float(f.get("manual", 0.0))


## Pomiar: pięć impulsów na wyjściu, każdy szukany na wejściu (kabel z wyjścia do wejścia albo mikrofon
## przy głośniku). Wynik: {"ok", "total_ms", "residual_ms", "spread_ms", "info"} albo {"ok": false, "error"}.
static func measure_latency() -> Dictionary:
	var c := ensure_open()
	if c == null or not c.input_ok() or not c.has_method(&"probe_click"):
		return {"ok": false, "error": "input"}
	var tree := Engine.get_main_loop() as SceneTree
	var rate: float = c.sample_rate()
	var res: Array[float] = []
	for i in 5:
		var at: int = c.probe_click()
		var expected: int = c.input_frame_at(at)
		await tree.create_timer(0.6).timeout
		var from := expected - int(rate * 0.15)
		var data: Variant = c.input_read(from, int(rate * 0.5))
		if data == null:
			continue
		var buf := data as PackedFloat32Array
		var peak := 0.0
		for v in buf:
			peak = maxf(peak, absf(v))
		if peak < 0.03:
			continue
		var thr := peak * 0.3
		for k in buf.size():
			if absf(buf[k]) >= thr:
				res.append((from + k - expected) * 1000.0 / rate)
				break
	if res.size() < 3:
		return {"ok": false, "error": "signal"}
	res.sort()
	var med := res[res.size() / 2]
	var info: Dictionary = c.timing_info()
	return {"ok": true, "residual_ms": med, "spread_ms": res[-1] - res[0],
			"total_ms": float(info.get("roundtrip_ms", 0.0)) + med, "info": info}


static func _on_setting(key: StringName) -> void:
	var c := core()
	if c == null:
		return
	if key == &"output_volume":
		c.set_volume(int(App.setting(key)) / 100.0)
	elif key == &"instrument":
		_apply_pitch_min(c)
	elif key in REOPEN_KEYS and c.is_open():
		var was_playing: bool = c.is_playing()
		c.close()
		_open()
		if was_playing:
			c.start()


## Dźwięk próbny: struna A (A2, na basie A1) wybranym instrumentem MIDI.
static func play_test_note() -> bool:
	var c := ensure_open()
	if c == null:
		return false
	c.play_note(Instrument.midi_program(), 33 if Instrument.is_bass() else 45, 0.8, 1.6)
	return true
