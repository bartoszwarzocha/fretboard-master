# Fretboard Master – ustawienia grafiki i okna stosowane na żywo: tryb okna, rozdzielczość, monitor,
# skala interfejsu, V-Sync, limit klatek, oszczędzanie energii, jakość 3D, jasność/kontrast/gamma,
# dane wydajności w stopce.
# Zasada: każdy efekt kosztuje tylko wtedy, gdy jest włączony – korekcja obrazu i dane wydajności
# istnieją w drzewie wyłącznie przy wartościach innych niż domyślne.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Node

# Profile jakości: klucze ustawiane razem. Zmiana jednego z nich ręcznie = profil „własny”.
const QUALITY := {
	"low": {&"msaa": 0, &"render_scale": 0.75, &"anisotropy": 0, &"shadows": "off", &"reflections": false},
	"medium": {&"msaa": 2, &"render_scale": 1.0, &"anisotropy": 2, &"shadows": "low", &"reflections": false},
	"high": {&"msaa": 4, &"render_scale": 1.0, &"anisotropy": 4, &"shadows": "medium", &"reflections": false},
	"ultra": {&"msaa": 8, &"render_scale": 1.0, &"anisotropy": 16, &"shadows": "high", &"reflections": true},
}
const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]

var _audit := false
# Fokus okna śledzony z powiadomień – Window.has_focus() bywa w chwili powiadomienia FOCUS_IN
# jeszcze nieaktualne, przez co program z fokusem zostawał przy limicie klatek „w tle” (10 FPS).
var _focused := true
var _closing := false
var _post: CanvasLayer
var _post_rect: ColorRect
var _info: CanvasLayer
var _info_label: Label
var _info_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_audit = "--perf-audit" in OS.get_cmdline_user_args()
	App.settings_changed.connect(_on_setting)
	Backdrop.live_changed.connect(_apply_fps)
	_apply_all.call_deferred()


func _apply_all() -> void:
	if not _audit:
		_apply_window()
	for key in [&"ui_scale", &"vsync", &"max_fps", &"power_saving", &"anisotropy", &"msaa",
			&"render_scale", &"brightness", &"perf_info"]:
		_on_setting(key)


func _on_setting(key: StringName) -> void:
	match key:
		&"window_mode", &"resolution", &"monitor":
			if key == &"resolution" and not _closing:
				App.set_setting(&"window_rect", "")   # wybrany rozmiar zastępuje zapamiętany
			if not _audit and not _closing:
				_apply_window()
		&"ui_scale":
			get_tree().root.content_scale_factor = float(App.setting(&"ui_scale"))
		&"vsync":
			var mode := DisplayServer.VSYNC_ENABLED
			match str(App.setting(&"vsync")):
				"off": mode = DisplayServer.VSYNC_DISABLED
				"adaptive": mode = DisplayServer.VSYNC_ADAPTIVE
			DisplayServer.window_set_vsync_mode(mode)
		&"max_fps", &"power_saving", &"background_fps", &"perf_info":
			_apply_fps()
			if key == &"perf_info":
				_update_info()
		&"msaa", &"render_scale", &"anisotropy":
			var vp := get_tree().root
			vp.msaa_3d = msaa_mode()
			vp.scaling_3d_scale = float(App.setting(&"render_scale"))
			vp.anisotropic_filtering_level = _aniso_level()
		&"brightness", &"contrast", &"gamma":
			_update_post()


# --- Okno ---------------------------------------------------------------------

func _apply_window() -> void:
	var win := get_window()
	var screen := int(App.setting(&"monitor"))
	if screen >= 0 and screen < DisplayServer.get_screen_count() and screen != win.current_screen:
		win.current_screen = screen
	match str(App.setting(&"window_mode")):
		"maximized":
			win.mode = Window.MODE_MAXIMIZED
		"fullscreen":
			win.mode = Window.MODE_FULLSCREEN
		"exclusive":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			win.mode = Window.MODE_WINDOWED
			var rect := _saved_rect()
			if rect.has_area():
				win.size = rect.size
				win.position = rect.position
				return
			var r := str(App.setting(&"resolution")).split("x")
			if r.size() == 2:
				var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
				var want := Vector2i(int(r[0]), int(r[1])).min(usable.size)
				win.size = want
				win.position = usable.position + (usable.size - want) / 2


# Zapamiętane położenie i rozmiar okna – tylko gdy pasek tytułu leży na którymś z monitorów
# (monitor mógł zostać odłączony) i okno mieści się na nim.
func _saved_rect() -> Rect2i:
	var p := str(App.setting(&"window_rect")).split(",")
	if p.size() != 4:
		return Rect2i()
	var rect := Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
	for i in DisplayServer.get_screen_count():
		var usable := DisplayServer.screen_get_usable_rect(i)
		var title := Rect2i(rect.position, Vector2i(rect.size.x, 40)).intersection(usable)
		if title.size.x >= 120 and title.size.y >= 20 and rect.size.x <= usable.size.x \
				and rect.size.y <= usable.size.y:
			return rect
	return Rect2i()


# Zapis stanu okna przy zamykaniu programu (pełny ekran wybrany w ustawieniach zostaje).
func _save_window() -> void:
	var win := get_window()
	var values := {&"monitor": win.current_screen}
	match win.mode:
		Window.MODE_MAXIMIZED:
			values[&"window_mode"] = "maximized"
		Window.MODE_WINDOWED:
			values[&"window_mode"] = "windowed"
			values[&"window_rect"] = "%d,%d,%d,%d" % [win.position.x, win.position.y, win.size.x, win.size.y]
	_closing = true
	App.set_settings(values)


# Rozdzielczości mieszczące się na bieżącym monitorze.
func resolutions() -> Array:
	var screen := DisplayServer.screen_get_size(get_window().current_screen)
	return RESOLUTIONS.filter(func(r: String) -> bool:
		var p := r.split("x")
		return int(p[0]) <= screen.x and int(p[1]) <= screen.y)


# --- Klatki i energia ---------------------------------------------------------

func _apply_fps() -> void:
	if _audit:
		return   # audyt mierzy klatki bez limitów (ustawia je sam)
	var saving := bool(App.setting(&"power_saving"))
	# Dane wydajności liczą FPS, a tło ruchome i cząsteczki są animowane – wtedy obraz
	# odświeża się stale.
	OS.low_processor_usage_mode = saving and not bool(App.setting(&"perf_info")) and not Backdrop.is_live()
	if _focused or not saving:
		Engine.max_fps = 30 if int(App.setting(&"max_fps")) == 30 else 60   # do wyboru tylko 60 albo 30
	else:
		Engine.max_fps = int(App.setting(&"background_fps"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _audit:
		_save_window()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		_apply_fps()


# --- Jakość 3D ----------------------------------------------------------------

func msaa_mode() -> Viewport.MSAA:
	match int(App.setting(&"msaa")):
		2: return Viewport.MSAA_2X
		4: return Viewport.MSAA_4X
		8: return Viewport.MSAA_8X
	return Viewport.MSAA_DISABLED


func _aniso_level() -> Viewport.AnisotropicFiltering:
	match int(App.setting(&"anisotropy")):
		2: return Viewport.ANISOTROPY_2X
		4: return Viewport.ANISOTROPY_4X
		8: return Viewport.ANISOTROPY_8X
		16: return Viewport.ANISOTROPY_16X
	return Viewport.ANISOTROPY_DISABLED


func apply_quality(preset: String) -> void:
	var values: Dictionary = QUALITY.get(preset, {}).duplicate()
	values[&"quality"] = preset
	App.set_settings(values)


# --- Jasność, kontrast, gamma (jedna warstwa korekcji – tylko gdy potrzebna) ----

func _update_post() -> void:
	var b := float(App.setting(&"brightness"))
	var c := float(App.setting(&"contrast"))
	var g := float(App.setting(&"gamma"))
	var needed := not (is_equal_approx(b, 1.0) and is_equal_approx(c, 1.0) and is_equal_approx(g, 1.0))
	if not needed:
		if _post:
			_post.queue_free()
			_post = null
		return
	if _post == null:
		_post = CanvasLayer.new()
		_post.layer = 120
		add_child(_post)
		_post_rect = ColorRect.new()
		_post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/color_adjust.gdshader")
		_post_rect.material = mat
		_post.add_child(_post_rect)
	var m := _post_rect.material as ShaderMaterial
	m.set_shader_parameter(&"brightness", b)
	m.set_shader_parameter(&"contrast", c)
	m.set_shader_parameter(&"gamma", g)


# --- Dane wydajności w stopce -------------------------------------------------

func _update_info() -> void:
	var on := bool(App.setting(&"perf_info"))
	if not on:
		if _info:
			_info.queue_free()
			_info = null
		return
	if _info:
		return
	_info = CanvasLayer.new()
	_info.layer = 110
	add_child(_info)
	_info_label = Label.new()
	_info_label.theme_type_variation = &"Caption"
	_info_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_info_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info_label.offset_bottom = -10
	_info.add_child(_info_label)
	_info_timer = Timer.new()
	_info_timer.wait_time = 0.5
	_info_timer.timeout.connect(func() -> void: _info_label.text = PerfAudit.summary())
	_info.add_child(_info_timer)
	_info_timer.start()
	_info_label.text = PerfAudit.summary()
