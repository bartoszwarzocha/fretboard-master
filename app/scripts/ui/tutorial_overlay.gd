# Fretboard Master – samouczek: przyciemnienie ekranu z „oknem” na omawiany fragment interfejsu
# i dymek z opisem (krok, tytuł, tekst, Wstecz / Dalej / Zakończ). Kroki: [{title, text, target, action}]
# – target: Callable zwracający Control (albo null – dymek na środku), action: Callable wykonywany
# przy wejściu w krok (ustawia przykład). Esc zamyka. Rysuje się tylko przy zmianie kroku lub rozmiaru.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name TutorialOverlay
extends Control

signal finished

const SHADE := Color(0.02, 0.03, 0.07, 0.72)
const PAD := 8.0
const BUBBLE_W := 460.0

var steps: Array = []
var _i := 0
var _hole := Rect2()
var _bubble: PanelContainer
var _count: Label
var _title: Label
var _text: Label
var _back: Button
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("accent"), 20))
	_bubble.custom_minimum_size.x = BUBBLE_W
	add_child(_bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_bubble.add_child(col)
	_count = _label(13, ThemeManager.color("accent"), ThemeManager.font_body_bold)
	col.add_child(_count)
	_title = _label(22, ThemeManager.color("text"), ThemeManager.font_heading)
	col.add_child(_title)
	_text = _label(16, ThemeManager.color("muted"), null)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = BUBBLE_W - 40.0
	col.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var close := _button(tr("Close"))
	close.pressed.connect(_finish)
	row.add_child(close)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_back = _button(tr("Back"))
	_back.pressed.connect(func(): _go(_i - 1))
	row.add_child(_back)
	_next = _button(tr("Next"))
	_next.pressed.connect(func(): _go(_i + 1))
	row.add_child(_next)
	resized.connect(_place)
	_go(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()


func _go(i: int) -> void:
	if i >= steps.size():
		_finish()
		return
	_i = clampi(i, 0, steps.size() - 1)
	var st: Dictionary = steps[_i]
	if st.has("action"):
		(st.action as Callable).call()
	_count.text = tr("Step %d of %d") % [_i + 1, steps.size()]
	_title.text = tr(st.title)
	_text.text = tr(st.text)
	_back.disabled = _i == 0
	_next.text = tr("Finish") if _i == steps.size() - 1 else tr("Next")
	# Układ po akcji kroku może się zmienić (kontenery układają się w kolejnej klatce) – położenie
	# liczone po dwóch klatkach.
	_place()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		_place()


func _place() -> void:
	if steps.is_empty():
		return
	var st: Dictionary = steps[_i]
	var target: Control = st.target.call() if st.has("target") else null
	if target and is_instance_valid(target) and target.is_visible_in_tree():
		var r := target.get_global_rect()
		_hole = Rect2(r.position - global_position, r.size).grow(PAD)
	else:
		_hole = Rect2()
	_bubble.reset_size()
	var bs := _bubble.get_combined_minimum_size()
	var pos: Vector2
	if _hole.size == Vector2.ZERO:
		pos = (size - bs) * 0.5
	else:
		# Pod fragmentem, gdy się mieści; inaczej nad nim; inaczej z boku.
		var x := clampf(_hole.position.x, 16.0, size.x - bs.x - 16.0)
		if _hole.end.y + 14.0 + bs.y < size.y - 16.0:
			pos = Vector2(x, _hole.end.y + 14.0)
		elif _hole.position.y - 14.0 - bs.y > 16.0:
			pos = Vector2(x, _hole.position.y - 14.0 - bs.y)
		elif _hole.end.x + 14.0 + bs.x < size.x - 16.0:
			pos = Vector2(_hole.end.x + 14.0, clampf(_hole.position.y, 16.0, size.y - bs.y - 16.0))
		else:
			pos = Vector2(clampf(_hole.position.x - 14.0 - bs.x, 16.0, size.x - bs.x - 16.0),
					clampf(_hole.position.y, 16.0, size.y - bs.y - 16.0))
	_bubble.position = pos
	queue_redraw()


func _draw() -> void:
	if _hole.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), SHADE)
		return
	var h := _hole
	draw_rect(Rect2(0, 0, size.x, h.position.y), SHADE)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), SHADE)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), SHADE)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), SHADE)
	draw_rect(h, ThemeManager.color("accent"), false, 3.0)


func _finish() -> void:
	finished.emit()
	queue_free()


func _label(px: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", ThemeManager.fs(px))
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(96, 40)
	return b
