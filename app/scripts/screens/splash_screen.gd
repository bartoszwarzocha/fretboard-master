# Fretboard Master – ekran startowy: całkowicie czarny, logo firmy, „przedstawia”, logo programu.
# Bez klikania. Najpierw rozgrzewka (pasek postępu): modele 3D wczytywane w tle, otwarcie dźwięku
# (z SoundFontem), gryf 3D zbudowany i narysowany raz (kompilacja shaderów) – dzięki temu ekrany
# otwierają się potem bez czekania. Następnie logo programu nadlatuje z oddali i po 3 s przejście do menu.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Control

const DURATION := 3.0
const LOGO_SIZE := Vector2(680, 320)
static var CACHE: Array = []     # wczytane z wyprzedzeniem modele 3D (trzymane w pamięci)

var _company: Control
var _logo: Control
var _slot: Control
var _bar: ProgressBar


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
	# Miejsce na logo programu; do końca rozgrzewki – tylko cienki pasek postępu.
	_slot = Control.new()
	_slot.custom_minimum_size = LOGO_SIZE
	_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_slot)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(260, 3)
	_bar.add_theme_stylebox_override("background", _bar_box(Color(1, 1, 1, 0.08)))
	_bar.add_theme_stylebox_override("fill", _bar_box(Color("8C96B3")))
	_bar.position = Vector2((LOGO_SIZE.x - 260.0) * 0.5, LOGO_SIZE.y * 0.5)
	_bar.size = Vector2(260, 3)
	_slot.add_child(_bar)
	_warm_up.call_deferred()


func _bar_box(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(2)
	b.content_margin_top = 0
	b.content_margin_bottom = 0
	return b


func _warm_up() -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	# 1) Modele 3D – wczytywanie w tle; zostają w pamięci (CACHE) do końca działania programu.
	var paths: Array = [Logo3D.MODEL_PATH, ModuleIcon3D.MODEL_PATH]
	for k in GuitarModel3D.KINDS:
		if ResourceLoader.exists(GuitarModel3D.MODEL_DIR % k):
			paths.append(GuitarModel3D.MODEL_DIR % k)
	for p in paths:
		ResourceLoader.load_threaded_request(p)
	var pending := paths.duplicate()
	while not pending.is_empty():
		var sum := 0.0
		for p in paths:
			var prog := []
			var st := ResourceLoader.load_threaded_get_status(p, prog)
			sum += 1.0 if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS else float(prog[0])
			if st != ResourceLoader.THREAD_LOAD_IN_PROGRESS and p in pending:
				pending.erase(p)
				var res := ResourceLoader.load_threaded_get(p)
				if res:
					CACHE.append(res)
		_bar.value = 0.6 * sum / paths.size()
		await get_tree().process_frame
	# 2) Dźwięk: otwarcie urządzeń i wczytanie SoundFontu (pierwsze otwarcie Tunera/Metronomu).
	AudioEngine.ensure_open()
	_bar.value = 0.75
	await get_tree().process_frame
	# 3) Gryf 3D wg ustawień – budowa siatek i kompilacja shaderów.
	await FretboardView.warm_up(self)
	_bar.value = 1.0
	print("[ekran] rozgrzewka: %d ms" % (Time.get_ticks_msec() - t0))
	await get_tree().process_frame
	_bar.queue_free()
	var logo := Logo3D.create(LOGO_SIZE, true, 0.0 if App.animations() == "off" else DURATION - 0.4)
	_logo = logo
	_slot.add_child(logo)
	logo.size = LOGO_SIZE
	if not "--perf-audit" in OS.get_cmdline_user_args():
		get_tree().create_timer(DURATION).timeout.connect(func() -> void: App.go(App.start_screen()))


# Położenie obu logo – menu główne zaczyna od nich przejście (logo odjeżdżają na swoje miejsca).
func logo_rects() -> Dictionary:
	return {"logo": _logo.get_global_rect(), "company": _company.get_global_rect()}
