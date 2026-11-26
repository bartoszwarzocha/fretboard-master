# Fretboard Master – audyt wydajności.
#  • F3 – nakładka z liczbą wywołań rysowania, obiektów i prymitywów, czasem klatki i pamięcią wideo.
#  • Uruchomienie z argumentem „-- --perf-audit” przechodzi przez wszystkie ekrany, mierzy je
#    i porównuje z budżetami z res://perf/budgets.cfg. Przekroczenie = kod wyjścia 1 (do CI).
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Node

const BUDGETS_PATH := "res://perf/budgets.cfg"
const SETTLE_FRAMES := 8
const SAMPLE_FRAMES := 30

var _overlay: CanvasLayer
var _label: Label
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if "--perf-audit" in OS.get_cmdline_user_args():
		_run_audit.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		toggle_overlay()
		get_viewport().set_input_as_handled()


func toggle_overlay() -> void:
	if _overlay == null:
		_create_overlay()
	var show := not _overlay.visible
	_overlay.visible = show
	_timer.paused = not show
	# Nakładka wymaga odświeżania ekranu – na czas jej działania wyłączamy tryb oszczędny.
	OS.low_processor_usage_mode = not show


# Pomiar jednej klatki: wartości z ostatniej narysowanej klatki głównego okna.
func measure() -> Dictionary:
	var vp_rid := get_viewport().get_viewport_rid()
	var draw_calls := RenderingServer.viewport_get_render_info(vp_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME) \
			+ RenderingServer.viewport_get_render_info(vp_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	return {
		"draw_calls": draw_calls,
		"total_draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"video_mem_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"processing_nodes": count_processing_nodes(get_tree().root),
		"nodes": get_tree().get_node_count(),
		"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
	}


# Węzły z włączonym _process/_physics_process – każdy taki węzeł to koszt w każdej klatce.
func count_processing_nodes(root: Node) -> int:
	var n := 0
	if root.is_processing() or root.is_physics_processing():
		n += 1
	for child in root.get_children():
		n += count_processing_nodes(child)
	return n


func _create_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128
	_overlay.visible = false
	add_child(_overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.add_theme_stylebox_override("panel", ThemeManager.box(Color(0, 0, 0, 0.78), Color.TRANSPARENT, 8, 0, 12, 8))
	_overlay.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	panel.add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = 0.5
	_timer.timeout.connect(_refresh_overlay)
	add_child(_timer)
	_timer.start()


func _refresh_overlay() -> void:
	var m := measure()
	_label.text = "FPS %d · %s\ndraw calls %d (all viewports %d) · objects %d · primitives %d\nprocessing nodes %d / %d · VRAM %.1f MB" % [
		Engine.get_frames_per_second(), App.current_screen,
		m.draw_calls, m.total_draw_calls, m.objects, m.primitives,
		m.processing_nodes, m.nodes, m.video_mem_mb]


# --- Audyt wszystkich ekranów ------------------------------------------------------

# Opcjonalnie: „--shots=<katalog>” zapisuje zrzut każdego ekranu (do przeglądu wyglądu).
func _shots_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			return a.substr(8)
	return ""


func _run_audit() -> void:
	OS.low_processor_usage_mode = false
	var budgets := ConfigFile.new()
	if budgets.load(BUDGETS_PATH) != OK:
		push_error("Brak pliku budżetów: %s" % BUDGETS_PATH)
		get_tree().quit(2)
		return
	var failures := 0
	var lines: PackedStringArray = ["screen                draw  objects  prims  proc.nodes  nodes  vram MB  budget"]
	for screen in budgets.get_sections():
		App.go(StringName(screen))
		for i in SETTLE_FRAMES:
			await RenderingServer.frame_post_draw
		var worst := {}
		for i in SAMPLE_FRAMES:
			await RenderingServer.frame_post_draw
			var m := measure()
			for k in m:
				worst[k] = maxf(worst.get(k, 0.0), m[k])
		var shots := _shots_dir()
		if not shots.is_empty():
			get_viewport().get_texture().get_image().save_png(shots.path_join("%s.png" % screen))
		var verdict := "OK"
		for key in ["draw_calls", "objects", "primitives", "processing_nodes", "video_mem_mb"]:
			var limit = budgets.get_value(screen, key, null)
			if limit != null and worst[key] > float(limit):
				verdict = "PRZEKROCZONY: %s %s > %s" % [key, worst[key], limit]
				failures += 1
		lines.append("%-20s %5d %8d %6d %11d %6d %8.1f  %s" % [screen, worst.draw_calls, worst.objects,
				worst.primitives, worst.processing_nodes, worst.nodes, worst.video_mem_mb, verdict])
	print("\n".join(lines))
	print("Audyt wydajności: %s" % ("OK" if failures == 0 else "%d przekroczeń budżetu" % failures))
	get_tree().quit(1 if failures > 0 else 0)
