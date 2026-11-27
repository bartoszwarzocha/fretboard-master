# Fretboard Master – audyt wydajności.
#  • F3 – dane wydajności w stopce okna (FPS, karta graficzna, wywołania rysowania, obiekty, prymitywy, pamięć wideo).
#  • Uruchomienie z argumentem „-- --perf-audit” przechodzi przez wszystkie ekrany, mierzy je
#    i porównuje z budżetami z res://perf/budgets.cfg. Przekroczenie = kod wyjścia 1 (do CI).
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Node

const BUDGETS_PATH := "res://perf/budgets.cfg"
const SETTLE_FRAMES := 12
const SAMPLE_FRAMES := 120



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if "--perf-audit" in OS.get_cmdline_user_args():
		_run_audit.call_deferred()


# F3 włącza i wyłącza dane wydajności w stopce okna (to samo co opcja w ustawieniach grafiki).
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		App.set_setting(&"perf_info", not bool(App.setting(&"perf_info")))
		get_viewport().set_input_as_handled()


# Jednowierszowy opis do stopki: FPS, ekran, wywołania rysowania, obiekty, prymitywy, węzły, VRAM.
func summary() -> String:
	var m := measure()
	return "FPS %d · %s · %s · draw calls %d (%d) · objects %d · primitives %d · processing %d/%d · VRAM %.1f MB" % [
		Engine.get_frames_per_second(), gpu_info(), App.current_screen, m.draw_calls, m.total_draw_calls,
		m.objects, m.primitives, m.processing_nodes, m.nodes, m.video_mem_mb]


# Karta graficzna, z której korzysta program: nazwa, producent, wersja OpenGL/sterownika.
func gpu_info() -> String:
	return "GPU %s (%s, OpenGL %s)" % [RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()]


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


# Viewport główny i wszystkie SubViewporty (logo, scena ilustracji menu).
func _viewports() -> Array[RID]:
	var out: Array[RID] = [get_viewport().get_viewport_rid()]
	for v in get_tree().root.find_children("*", "SubViewport", true, false):
		out.append((v as SubViewport).get_viewport_rid())
	return out


# --- Audyt wszystkich ekranów ------------------------------------------------------

# Opcjonalnie: „--shots=<katalog>” zapisuje zrzut każdego ekranu (do przeglądu wyglądu).
func _shots_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			return a.substr(8)
	return ""


func _run_audit() -> void:
	OS.low_processor_usage_mode = false
	# Pomiar klatek bez ograniczeń: bez V-Sync i limitu FPS – widać rzeczywisty koszt klatki.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print(gpu_info())
	# Okno bez fokusu (np. uruchomione zdalnie) bywa dławione przez system lub sterownik –
	# wtedy FPS z audytu nie odpowiada kosztowi renderowania.
	if not get_window().has_focus():
		print("UWAGA: okno audytu nie ma fokusu – FPS mogą być ograniczone przez system.")
	var budgets := ConfigFile.new()
	if budgets.load(BUDGETS_PATH) != OK:
		push_error("Brak pliku budżetów: %s" % BUDGETS_PATH)
		get_tree().quit(2)
		return
	var failures := 0
	var focused := get_window().has_focus()
	var lines: PackedStringArray = ["screen                 fps  max ms  gpu ms  cpu ms  draw  all vp  objects  prims  proc.nodes  nodes  vram MB  budget"]
	for screen in budgets.get_sections():
		App.go(StringName(screen))
		# Odczekanie, aż poprzedni ekran zniknie z drzewa, a nowy się narysuje (także przy wolnym
		# pierwszym uruchomieniu, gdy kompilują się shadery).
		await get_tree().create_timer(0.3).timeout
		for i in SETTLE_FRAMES:
			await RenderingServer.frame_post_draw
		var vps := _viewports()
		for rid in vps:
			RenderingServer.viewport_set_measure_render_time(rid, true)
		var gpu_ms := 0.0
		var cpu_ms := 0.0
		var worst := {}
		# Klatki mierzone z animacjami (logo, ilustracje 3D menu) – najgorszy przypadek.
		var t_start := Time.get_ticks_usec()
		var t_prev := t_start
		var max_ms := 0.0
		for i in SAMPLE_FRAMES:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			max_ms = maxf(max_ms, (now - t_prev) / 1000.0)
			t_prev = now
			# Czas renderowania wszystkich viewportów (GPU i CPU) – niezależny od limitów klatek
			# i od fokusu okna; najgorsza klatka z próbki.
			var g := 0.0
			var c := 0.0
			for rid in vps:
				g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
				c += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			if i >= 3:
				gpu_ms = maxf(gpu_ms, g)
				cpu_ms = maxf(cpu_ms, c)
			var m := measure()
			for k in m:
				worst[k] = maxf(worst.get(k, 0.0), m[k])
		var fps := SAMPLE_FRAMES / maxf((t_prev - t_start) / 1e6, 0.000001)
		var shots := _shots_dir()
		if not shots.is_empty():
			get_viewport().get_texture().get_image().save_png(shots.path_join("%s.png" % screen))
		var verdict := "OK"
		var min_fps = budgets.get_value(screen, "min_fps") if budgets.has_section_key(screen, "min_fps") else null
		if min_fps != null and focused and fps < float(min_fps):
			verdict = "PRZEKROCZONY: fps %.0f < %s" % [fps, min_fps]
			failures += 1
		for key in ["max_gpu_ms", "max_cpu_ms"]:
			var lim = budgets.get_value(screen, key) if budgets.has_section_key(screen, key) else null
			var val := gpu_ms if key == "max_gpu_ms" else cpu_ms
			if lim != null and val > float(lim):
				verdict = "PRZEKROCZONY: %s %.2f > %s" % [key, val, lim]
				failures += 1
		for key in ["draw_calls", "total_draw_calls", "objects", "primitives", "processing_nodes", "video_mem_mb"]:
			var limit = budgets.get_value(screen, key, null)
			if limit != null and worst[key] > float(limit):
				verdict = "PRZEKROCZONY: %s %s > %s" % [key, worst[key], limit]
				failures += 1
		lines.append("%-20s %5.0f %7.1f %7.2f %7.2f %5d %7d %8d %6d %11d %6d %8.1f  %s" % [screen, fps, max_ms, gpu_ms, cpu_ms, worst.draw_calls, worst.total_draw_calls, worst.objects,
				worst.primitives, worst.processing_nodes, worst.nodes, worst.video_mem_mb, verdict])
	print("\n".join(lines))
	if not focused:
		print("Okno bez fokusu – FPS nie były porównywane z budżetem (decydują czasy GPU/CPU).")
	print("Audyt wydajności: %s" % ("OK" if failures == 0 else "%d przekroczeń budżetu" % failures))
	get_tree().quit(1 if failures > 0 else 0)
