# Fretboard Master – stan programu: ustawienia, moduły, nawigacja między ekranami.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Node

signal screen_requested(screen_id: StringName)
signal settings_changed(key: StringName)

const SETTINGS_PATH := "user://settings.cfg"
# Testy (--morph-test, --audio-timing) nie zapisują ustawień – plik użytkownika zostaje nietknięty.
var _readonly := "--morph-test" in OS.get_cmdline_user_args() or "--audio-timing" in OS.get_cmdline_user_args() \
		or "--looper-test" in OS.get_cmdline_user_args()
const LANGUAGES: Array[String] = ["", "en", "pl", "de", "es", "ru"]  # "" = język systemu

# Wszystkie ustawienia z wartościami domyślnymi, pogrupowane jak zakładki okna konfiguracji
# (przycisk „Przywróć domyślne” przywraca klucze jednej grupy). Grupa „state” nie ma zakładki.
const DEFAULTS := {
	&"audio": {
		&"audio_driver": "wasapi", &"audio_input": "Default", &"input_channel": 0,
		&"audio_output": "Default", &"output_volume": 70, &"input_monitor": false, &"buffer_samples": 128, &"latency_fix": {},
		&"midi_output": "internal", &"midi_instrument": 24, &"bass_midi_instrument": 33,
	},
	&"guitar": {
		&"instrument": "guitar", &"tuning": "standard", &"strings": 6,
		&"bass_tuning": "standard", &"bass_strings": 4, &"frets": 22, &"left_handed": false, &"a4": 440.0,
		&"neck_view": "electric_3d", &"fretboard_wood": "auto", &"fret_metal": "auto",
		&"inlays": "auto", &"string_color": "auto",
		&"marker_color": "", &"marker_root_color": "", &"marker_text_color": "",
		&"marker_rim": true, &"marker_rim_color": "",
	},
	&"look": {
		&"theme": "graphite", &"accent": "", &"bg_mode": "pattern", &"bg_color": "", &"bg_color2": "",
		&"bg_color3": "", &"bg_gradient_type": "linear",
		&"bg_gradient_angle": 135.0, &"bg_gradient_x": 0.5, &"bg_gradient_y": 0.5, &"bg_pattern": "hex", &"bg_intensity": 0.55, &"bg_scale": 1.0,
		&"bg_dim": 0.0, &"bg_blur": 0.0, &"bg_image": "", &"bg_animated": false, &"bg_anim_speed": 1.0,
		&"particles": "off", &"particles_density": 0.5, &"particles_speed": 1.0, &"particles_color": "",
		&"hit_particles": true, &"hit_style": "sparks",
		&"panel_opacity": 1.0, &"panel_radius": 20, &"panel_shadow": 0, &"font_scale": 1.0,
		&"menu_encyclopedia_art": "guitar",
		&"ui_font": "manrope", &"start_screen": "menu",
		&"window_mode": "maximized", &"resolution": "1600x900", &"monitor": -1, &"ui_scale": 1.0,
		&"vsync": "on", &"max_fps": 60, &"quality": "high", &"msaa": 4, &"render_scale": 1.0,
		&"anisotropy": 4, &"shadows": "medium", &"reflections": false,
		&"brightness": 1.0, &"contrast": 1.0, &"gamma": 1.0, &"animations": "full", &"anim_speed": 1.0,
		&"logo_spin": true, &"logo_spin_rate": "normal", &"neck_tilt_range": 15.0, &"neck_zoom_max": 3.0, &"neck_fov": 22.0,
		&"perf_info": false, &"power_saving": true, &"background_fps": 10,
	},
	&"language": {
		&"language": "", &"notation": 0,
	},
	&"profile": {
		&"profile_name": "", &"daily_goal": 20,
	},
	# Metronom – ostatnie ustawienia ekranu (bez zakładki w konfiguracji).
	&"metronome": {
		&"met_mode": 0, &"met_bpm": 96, &"met_metre": 2, &"met_sub": 0, &"met_sound": 0, &"met_grid": 0,
		&"met_kit": 0, &"met_pattern": "", &"met_preset": 0, &"met_ramp": true, &"met_ramp_to": 120,
		&"met_ramp_step": 4, &"met_ramp_bars": 8, &"lp_bed": 1, &"lp_rec_with": 0, &"lp_countin": 1, &"lp_rec_bars": 3,
	},
	# Tuner – widok, tryb i wybrana struna (0 = 6. struna).
	&"tuner": {
		&"tun_view": 0, &"tun_mode": 0, &"tun_string": 1, &"tun_chromatic": false, &"tun_note": 9,
	},
	# Encyklopedia – ostatnio wybrana pozycja, tonika, opis dźwięków, zakres progów i klucz.
	&"encyclopedia": {
		&"enc_kind": "scale", &"enc_scale": "dorian", &"enc_chord": "maj7", &"enc_interval": "M3", &"enc_tonic": 2,
		&"enc_mode": "names", &"enc_from": 5, &"enc_to": 9, &"enc_clef": "treble", &"enc_clef_bass": "bass", &"enc_big_neck": false, &"enc_shapes": false, &"enc_octaves": true, &"enc_barre": true,
	},
	# Stan programu zapamiętywany między uruchomieniami – bez zakładki, nie jest przywracany.
	&"state": {
		&"last_screen": "menu", &"window_rect": "",
	},
}

# Moduły w kolejności z menu głównego. Nazwy i opisy to identyfikatory tłumaczeń (gettext).
const MODULES: Array[Dictionary] = [
	{"id": &"encyclopedia", "name": "Encyclopedia", "icon": "♮", "color": Color("F5B544"),
		"desc": "Scales, chords and arpeggios on the fretboard and the staff. Start any exercise from here."},
	{"id": &"trainers", "name": "Exercises", "icon": "◎", "color": Color("3FD0C9"),
		"desc": "The program listens to your guitar and rates your playing: find the note, play the scale, recognise the chord."},
	{"id": &"reading", "name": "Note reading", "icon": "𝄞", "color": Color("B98CFF"),
		"desc": "Notes and tablature at a gradually increasing tempo."},
	{"id": &"tuning", "name": "Tuner", "icon": "◐", "color": Color("7BD88F"),
		"desc": "Chromatic tuner and alternate tunings."},
	{"id": &"metronome", "name": "Metronome", "icon": "♩", "color": Color("FF7A59"),
		"desc": "Metronome, drum machine and looper."},
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
	# Dane wydajności (F3) nie są pamiętane między uruchomieniami – program startuje zawsze bez nich.
	if _config.has_section_key("settings", "perf_info"):
		_config.erase_section_key("settings", "perf_info")
	_apply_language()
	get_window().min_size = Vector2i(1280, 720)
	for key in [&"audio_input", &"audio_output", &"output_volume"]:
		_apply_audio(key)
	settings_changed.connect(_apply_audio)


# Urządzenia dźwięku i głośność programu (szyna Master). Docelowo przejmie to rdzeń audio w C++.
func _apply_audio(key: StringName) -> void:
	match key:
		&"audio_input":
			var name := str(setting(key))
			if name in AudioServer.get_input_device_list():
				AudioServer.input_device = name
		&"audio_output":
			var name := str(setting(key))
			if name in AudioServer.get_output_device_list():
				AudioServer.output_device = name
		&"output_volume":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(int(setting(key)) / 100.0, 0.0001)))


# Strona programu – adres ustawiany w project.godot (application/config/website).
func website() -> String:
	return str(ProjectSettings.get_setting("application/config/website", "https://bwdsp.com.pl"))


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "2.0.0"))


func module(id: StringName) -> Dictionary:
	for m in MODULES:
		if m.id == id:
			return m
	return {}


# Ekran po starcie: menu, ostatnio otwarty albo wybrany moduł (ustawienie „start_screen”).
func start_screen() -> StringName:
	var id := str(App.setting(&"start_screen"))
	if id == "last":
		id = str(App.setting(&"last_screen"))
	if id != "menu" and id != "settings" and App.module(StringName(id)).is_empty():
		id = "menu"
	return StringName(id)


func go(screen_id: StringName) -> void:
	screen_requested.emit(screen_id)


# --- Ustawienia ---------------------------------------------------------------

func get_setting(key: StringName, default_value: Variant) -> Variant:
	return _config.get_value("settings", key, default_value)


# Ustawienie z wartością domyślną z DEFAULTS.
func setting(key: StringName) -> Variant:
	return _config.get_value("settings", key, default_of(key))


func default_of(key: StringName) -> Variant:
	for group in DEFAULTS.values():
		if group.has(key):
			return group[key]
	return null


# Przywrócenie domyślnych wartości jednej grupy (zakładki).
func reset_group(group: StringName) -> void:
	for key in DEFAULTS[group]:
		if _config.has_section_key("settings", key):
			_config.erase_section_key("settings", key)
	_save()
	if group == &"language":
		_apply_language()
	for key in DEFAULTS[group]:
		settings_changed.emit(key)


# Kilka ustawień naraz (np. profil jakości grafiki) – jeden zapis pliku.
func set_settings(values: Dictionary) -> void:
	var changed: Array = []
	for key in values:
		if setting(key) != values[key]:
			_config.set_value("settings", key, values[key])
			changed.append(key)
	if changed.is_empty():
		return
	_save()
	if &"language" in changed:
		_apply_language()
	for key in changed:
		settings_changed.emit(key)


func set_setting(key: StringName, value: Variant) -> void:
	if setting(key) == value and typeof(setting(key)) == typeof(value):
		return
	_config.set_value("settings", key, value)
	_save()
	if key == &"language":
		_apply_language()
	settings_changed.emit(key)


func _save() -> void:
	if not _readonly:
		_config.save(SETTINGS_PATH)


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
	return int(setting(&"notation"))


# Animacje interfejsu: "full", "reduced", "off"; mnożnik czasu trwania (większa szybkość = krótszy czas).
func animations() -> String:
	return str(setting(&"animations"))


func anim_time(seconds: float) -> float:
	return seconds / maxf(float(setting(&"anim_speed")), 0.1)
