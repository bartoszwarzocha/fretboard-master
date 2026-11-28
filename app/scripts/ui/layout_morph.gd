# Fretboard Master – płynna zmiana układu ekranu (np. „Duży gryf” w Encyklopedii, później Ćwiczenia).
# Wszystko w jednej animacji z wygładzeniem: kontenery dostają kolejne wartości minimalnych rozmiarów,
# więc panele przesuwają się i zmieniają rozmiar w każdej klatce – bez skoków i bez przebudowy sceny.
# Treść, która ma inny układ w obu stanach, przechodzi przez „swap”: wygasza się, zmienia, gdy jest
# niewidoczna, i pojawia się z powrotem. Z „--morph-log” w argumentach programu wypisuje czasy klatek.
#   LayoutMorph.new(self).height(panel, 260).width(holder, 0).fade(staff, 0).swap(card, rebuild).play()
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name LayoutMorph
extends RefCounted

const DURATION := 0.38
const SWAP_AT := 0.4          # część czasu na wygaszenie treści przed zmianą

var duration := DURATION
var _tw: Tween
var _frames: Array[float] = []
var _t_prev := 0
var _held: Array[Control] = []


func _init(owner: Node, d := DURATION) -> void:
	duration = d
	_tw = owner.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func height(c: Control, h: float) -> LayoutMorph:
	_tw.tween_property(c, "custom_minimum_size:y", h, duration)
	return self


func width(c: Control, w: float) -> LayoutMorph:
	_tw.tween_property(c, "custom_minimum_size:x", w, duration)
	return self


func fade(c: CanvasItem, a: float) -> LayoutMorph:
	_tw.tween_property(c, "modulate:a", a, duration * 0.6)
	return self


# Treść o innym układzie: wygaszenie, zmiana (change) w chwili niewidoczności, rozjaśnienie.
func swap(c: CanvasItem, change: Callable) -> LayoutMorph:
	var t := duration * SWAP_AT
	_tw.tween_property(c, "modulate:a", 0.0, t).set_ease(Tween.EASE_IN)
	_tw.tween_callback(change).set_delay(t)
	_tw.tween_property(c, "modulate:a", 1.0, duration - t).set_delay(t).set_ease(Tween.EASE_OUT)
	return self


# Widok z obrazem 3D (FretboardView), który w trakcie animacji urośnie o `grow` (ujemne – zmaleje):
# bufor obrazu dostaje od razu największy rozmiar i nie jest tworzony od nowa w każdej klatce.
func hold(view: Control, grow: Vector2) -> LayoutMorph:
	view.reserve(view.size + grow.max(Vector2.ZERO) + Vector2(0, 16))
	_held.append(view)
	return self


func then(done: Callable) -> LayoutMorph:
	_tw.tween_callback(done).set_delay(duration)
	return self


func play() -> Tween:
	if not _held.is_empty():
		_tw.tween_callback(_release).set_delay(duration)
	if "--morph-log" in OS.get_cmdline_user_args():
		_t_prev = Time.get_ticks_usec()
		_tw.tween_method(_sample, 0.0, 1.0, duration)
		_tw.finished.connect(_report)
	return _tw


func kill() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_release()


func _release() -> void:
	for v in _held:
		if is_instance_valid(v):
			v.release()
	_held.clear()


func _sample(_v: float) -> void:
	var now := Time.get_ticks_usec()
	_frames.append((now - _t_prev) / 1000.0)
	_t_prev = now


func _report() -> void:
	if _frames.size() < 2:
		return
	var f := _frames.slice(1)
	var mx := 0.0
	var sum := 0.0
	for v in f:
		mx = maxf(mx, v)
		sum += v
	print("[morph] klatek %d, średnio %.1f ms, najdłuższa %.1f ms" % [f.size(), sum / f.size(), mx])
