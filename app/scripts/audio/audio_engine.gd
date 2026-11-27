# Fretboard Master – dostęp do rdzenia audio w C++ (singleton FbmAudio): otwarcie wyjścia według
# ustawień (sterownik, urządzenie, bufor w próbkach), wczytanie brzmień SoundFont, głośność.
# Wyjście otwiera się przy pierwszym użyciu i otwiera ponownie po zmianie ustawień dźwięku.
# Gdy rdzeń nie jest zbudowany (sam GDScript), available() zwraca false.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
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
	if not c.is_open():
		_open()
	return c if c.is_open() else null


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


static func _on_setting(key: StringName) -> void:
	var c := core()
	if c == null:
		return
	if key == &"output_volume":
		c.set_volume(int(App.setting(key)) / 100.0)
	elif key in REOPEN_KEYS and c.is_open():
		var was_playing: bool = c.is_playing()
		c.close()
		_open()
		if was_playing:
			c.start()


## Dźwięk próbny: struna A (A2) wybranym instrumentem MIDI.
static func play_test_note() -> bool:
	var c := ensure_open()
	if c == null:
		return false
	c.play_note(int(App.setting(&"midi_instrument")), 45, 0.8, 1.6)
	return true
