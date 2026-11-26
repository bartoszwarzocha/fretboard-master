# Fretboard Master – stan programu: ustawienia, moduły, nawigacja między ekranami.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Node

signal screen_requested(screen_id: StringName)
signal settings_changed(key: StringName)

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES: Array[String] = ["", "en", "pl", "de", "es", "ru"]  # "" = język systemu
const UNFOCUSED_MAX_FPS := 10

# Moduły w kolejności z menu głównego. Nazwy i opisy to identyfikatory tłumaczeń (gettext).
const MODULES: Array[Dictionary] = [
	{"id": &"encyclopedia", "name": "Encyclopedia", "icon": "♮", "color": Color("F5B544"),
		"desc": "Scales, chords and arpeggios on the fretboard and the staff. Start any trainer from here."},
	{"id": &"trainers", "name": "Trainers", "icon": "◎", "color": Color("3FD0C9"),
		"desc": "The program listens to your guitar and rates your playing: find the note, play the scale, recognise the chord."},
	{"id": &"reading", "name": "Note reading", "icon": "𝄞", "color": Color("B98CFF"),
		"desc": "Notes and tablature at a gradually increasing tempo."},
	{"id": &"tuning", "name": "Tuning", "icon": "◐", "color": Color("7BD88F"),
		"desc": "Chromatic tuner and alternate tunings."},
	{"id": &"metronome", "name": "Metronome", "icon": "♩", "color": Color("FF7A59"),
		"desc": "Tempo, metre, accents and gradual speed-up."},
	{"id": &"plan", "name": "Practice plan", "icon": "☰", "color": Color("5AA9FF"),
		"desc": "Your set of exercises for today and for the week."},
	{"id": &"progress", "name": "Progress", "icon": "↗", "color": Color("F2D15C"),
		"desc": "Statistics, weak spots on the fretboard, achievements."},
	{"id": &"settings", "name": "Settings", "icon": "⚙", "color": Color("AEB7CF"),
		"desc": "Sound and MIDI, guitar, appearance, language."},
]

var current_screen: StringName = &""
var _config := ConfigFile.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_config.load(SETTINGS_PATH)
	_apply_language()
	get_window().min_size = Vector2i(1280, 720)


func _notification(what: int) -> void:
	# Oszczędzanie energii: niski limit klatek, gdy okno nie ma fokusu.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			Engine.max_fps = UNFOCUSED_MAX_FPS
		NOTIFICATION_APPLICATION_FOCUS_IN:
			Engine.max_fps = 0


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "2.0.0"))


func module(id: StringName) -> Dictionary:
	for m in MODULES:
		if m.id == id:
			return m
	return {}


func go(screen_id: StringName) -> void:
	screen_requested.emit(screen_id)


# --- Ustawienia ---------------------------------------------------------------

func get_setting(key: StringName, default_value: Variant) -> Variant:
	return _config.get_value("settings", key, default_value)


func set_setting(key: StringName, value: Variant) -> void:
	if get_setting(key, null) == value:
		return
	_config.set_value("settings", key, value)
	_config.save(SETTINGS_PATH)
	if key == &"language":
		_apply_language()
	settings_changed.emit(key)


func language() -> String:
	return str(get_setting(&"language", ""))


func _apply_language() -> void:
	var lang := language()
	if lang.is_empty():
		lang = OS.get_locale_language()
	if not lang in LANGUAGES:
		lang = "en"
	TranslationServer.set_locale(lang)


# Zapis nazw dźwięków – osobne ustawienie, niezależne od języka.
func notation() -> int:
	return int(get_setting(&"notation", NoteNames.INTERNATIONAL))
