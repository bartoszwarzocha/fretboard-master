# Fretboard Master – okno główne: wyświetla jeden ekran naraz. Ekran nieaktywny jest usuwany
# z drzewa, więc nie zużywa czasu procesora ani wywołań rysowania.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Control

const SplashScreen := preload("res://scripts/screens/splash_screen.gd")
const MenuScreen := preload("res://scripts/screens/menu_screen.gd")
const ModuleScreen := preload("res://scripts/screens/module_screen.gd")
const SettingsScreen := preload("res://scripts/screens/settings_screen.gd")
const AboutScreen := preload("res://scripts/screens/about_screen.gd")
const MetronomeScreen := preload("res://scripts/screens/metronome_screen.gd")
const TunerScreen := preload("res://scripts/screens/tuner_screen.gd")
const EncyclopediaScreen := preload("res://scripts/screens/encyclopedia_screen.gd")

var _screen: Control


# Tło okna rysuje Backdrop (pod ekranami). Ekran startowy jest całkowicie czarny.
func _ready() -> void:
	set_process(false)
	App.screen_requested.connect(_show)
	_show(&"splash")   # ekran startowy (reklama firmy) zawsze – bez wyłączania i pomijania
	if "--measure-screens" in OS.get_cmdline_user_args():
		_measure_screens()
	elif "--morph-test" in OS.get_cmdline_user_args():
		_open_after_splash(&"encyclopedia")
	elif "--audio-timing" in OS.get_cmdline_user_args():
		_audio_timing()
	elif "--looper-test" in OS.get_cmdline_user_args():
		App.set_setting(&"met_mode", 2)
		_open_after_splash(&"metronome")


func _exit_tree() -> void:
	FretboardView.free_cache()


func _show(screen_id: StringName) -> void:
	var t0 := Time.get_ticks_usec()
	# Przejście ze startu do menu: menu dostaje położenie logo, a tło płynnie zmienia kolor.
	var intro := {}
	if _screen and App.current_screen == &"splash" and screen_id == &"menu" \
			and not "--perf-audit" in OS.get_cmdline_user_args() and App.animations() != "off":
		intro = _screen.logo_rects()
	if _screen:
		_screen.queue_free()
		remove_child(_screen)
	App.current_screen = screen_id
	match screen_id:
		&"splash":
			_screen = SplashScreen.new()
		&"menu":
			_screen = MenuScreen.new()
			_screen.intro_from = intro
		&"settings":
			_screen = SettingsScreen.new()
		&"about":
			_screen = AboutScreen.new()
		&"metronome":
			_screen = MetronomeScreen.new()
		&"tuning":
			_screen = TunerScreen.new()
		&"encyclopedia":
			_screen = EncyclopediaScreen.new()
		_:
			_screen = ModuleScreen.new()
			_screen.module_id = screen_id
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	if screen_id == &"splash":
		Backdrop.set_fade(0.0)
	elif not intro.is_empty() and App.animations() != "off":
		Backdrop.set_fade(1.0, App.anim_time(0.8))
	else:
		Backdrop.set_fade(1.0)
	if screen_id != &"splash" and screen_id != &"about":
		App.set_setting(&"last_screen", String(screen_id))
	_report_time(String(screen_id), t0)


# Czas otwarcia ekranu: od żądania do końca pierwszej narysowanej klatki (z kompilacją shaderów).
func _report_time(what: String, t0: int) -> void:
	var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
	await RenderingServer.frame_post_draw
	print("[ekran] %s: budowa %.0f ms, pierwsza klatka %.0f ms" % [what, build_ms, (Time.get_ticks_usec() - t0) / 1000.0])


# Test płynności „Dużego gryfu”: FretboardMaster.exe -- --morph-test --morph-log (Encyklopedia po starcie).
func _open_after_splash(id: StringName) -> void:
	while App.current_screen == &"splash":
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	App.go(id)


# Diagnostyka zgrania nagrań: FretboardMaster.exe -- --audio-timing (bez zapisu ustawień). Wypisuje
# opóźnienia wg sterownika, przesunięcie startu strumieni i to, co looper kompensował przed poprawką
# (opóźnienia bez przesunięcia) i po niej. Z „--measure” także pięć impulsów pomiaru (słychać kliknięcia;
# wynik tylko przy pętli zwrotnej – kabel albo mikrofon przy głośniku).
func _audio_timing() -> void:
	while App.current_screen == &"splash":
		await get_tree().create_timer(0.2).timeout
	var c := AudioEngine.ensure_open()
	if c == null:
		print("[opóźnienie] brak wyjścia: ", AudioEngine.last_error())
		get_tree().quit()
		return
	await get_tree().create_timer(1.5).timeout
	var info: Dictionary = c.timing_info()
	print("[opóźnienie] sterownik %s, wejście %s: %s" % [AudioEngine.driver(), str(c.input_ok()), str(info)])
	print("[opóźnienie] looper teraz: %.1f ms + przesunięcie numeracji %.1f ms; poprawka: %s" % [
			float(info.get("roundtrip_ms", 0.0)), float(info.get("start_offset_ms", 0.0)), str(AudioEngine.latency_fix())])
	if "--measure" in OS.get_cmdline_user_args():
		var r: Dictionary = await AudioEngine.measure_latency()
		print("[opóźnienie] pomiar impulsami: ", r)
	get_tree().quit()


# Pomiar czasów otwarcia ekranów: FretboardMaster.exe -- --measure-screens
# (każdy ekran dwa razy: pierwsze i kolejne otwarcie; zakładki ustawień z gryfem osobno).
func _measure_screens() -> void:
	while App.current_screen == &"splash":
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.5).timeout
	for _pass in 2:
		for id in [&"menu", &"settings", &"metronome", &"tuning", &"encyclopedia", &"about", &"menu"]:
			App.go(id)
			await get_tree().create_timer(1.5).timeout
			if id == &"settings":
				for tab in [&"guitar", &"look"]:
					var t0 := Time.get_ticks_usec()
					_screen.call(&"_select_tab", tab)
					_report_time("settings/" + String(tab), t0)
					await get_tree().create_timer(1.5).timeout
	get_tree().quit()
