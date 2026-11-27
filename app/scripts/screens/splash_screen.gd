# Fretboard Master – ekran startowy: całkowicie czarny, logo firmy, „przedstawia”, logo programu.
# Bez klikania; logo programu nadlatuje z oddali, pod nim napis „Wczytywanie...”. Równocześnie w tle
# rozgrzewka: modele 3D, otwarcie dźwięku (z SoundFontem), gryf 3D zbudowany i narysowany raz
# (kompilacja shaderów) – ekrany otwierają się potem bez czekania. Przejście do menu po 3 s, a gdy
# rozgrzewka trwa dłużej – zaraz po jej końcu.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Control

const DURATION := 3.0
const LOGO_SIZE := Vector2(680, 320)
static var CACHE: Array = []     # wczytane z wyprzedzeniem modele 3D (trzymane w pamięci)

var _company: Control
var _logo: Control
var _time_up := false
var _warm_done := false
var _left := false


func _ready() -> void:
	set_process(false)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	center.add_child(col)

	var company := CompanyLogo.create(Vector2(260, 70), false)
	_company = company
	company.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(company)
	var presents := Label.new()
	presents.text = "presents"
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents.add_theme_color_override("font_color", Color("8C96B3"))
	presents.add_theme_font_size_override("font_size", 20)
	col.add_child(presents)
	var logo := Logo3D.create(LOGO_SIZE, true, 0.0 if App.animations() == "off" else DURATION - 0.4)
	_logo = logo
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(logo)
	var loading := Label.new()
	loading.text = "Loading..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_color_override("font_color", Color("8C96B3"))
	loading.add_theme_font_size_override("font_size", 16)
	col.add_child(loading)
	_warm_up.call_deferred()
	if not "--perf-audit" in OS.get_cmdline_user_args():
		get_tree().create_timer(DURATION).timeout.connect(func() -> void:
			_time_up = true
			_finish())


func _finish() -> void:
	if _time_up and _warm_done and not _left:
		_left = true
		App.go(App.start_screen())


func _warm_up() -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	# 1) Modele 3D – wczytywanie w tle; zostają w pamięci (CACHE) do końca działania programu.
	var paths: Array = [ModuleIcon3D.MODEL_PATH]   # logo wczytuje się samo (jest już na ekranie)
	for k in GuitarModel3D.KINDS:
		if ResourceLoader.exists(GuitarModel3D.MODEL_DIR % k):
			paths.append(GuitarModel3D.MODEL_DIR % k)
	for p in paths:
		ResourceLoader.load_threaded_request(p)
	var pending := paths.duplicate()
	while not pending.is_empty():
		for p in paths:
			var st := ResourceLoader.load_threaded_get_status(p)
			if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS and p in pending:
				pending.erase(p)
				var res := ResourceLoader.load_threaded_get(p)
				if res:
					CACHE.append(res)
		await get_tree().process_frame
	# 2) Dźwięk: otwarcie urządzeń i wczytanie SoundFontu (pierwsze otwarcie Tunera/Metronomu).
	AudioEngine.ensure_open()
	await get_tree().process_frame
	# 3) Gryf 3D wg ustawień – budowa siatek i kompilacja shaderów.
	await FretboardView.warm_up(self)
	print("[ekran] rozgrzewka: %d ms" % (Time.get_ticks_msec() - t0))
	_warm_done = true
	_finish()


# Położenie obu logo – menu główne zaczyna od nich przejście (logo odjeżdżają na swoje miejsca).
func logo_rects() -> Dictionary:
	return {"logo": _logo.get_global_rect(), "company": _company.get_global_rect()}
