# Fretboard Master – własne okno wyboru koloru w stylu programu: pole nasycenie/jasność, pasek barwy,
# podgląd i kod HEX. Wszystkie napisy przechodzą przez tłumaczenia (wbudowany próbnik Godota ma
# etykiety, których nie da się przetłumaczyć). Kolor trafia do ustawień dopiero po „OK”.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ColorPopup
extends PopupPanel

signal picked(color: Color)

const SV_SHADER := """
shader_type canvas_item;
uniform float hue = 0.0;
vec3 hsv(float h, float s, float v) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return v * mix(vec3(1.0), k, s);
}
void fragment() { COLOR = vec4(hsv(hue, UV.x, 1.0 - UV.y), 1.0); }
"""
const HUE_SHADER := """
shader_type canvas_item;
void fragment() {
	vec3 k = clamp(abs(mod(UV.y * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	COLOR = vec4(k, 1.0);
}
"""

var _h := 0.0
var _s := 1.0
var _v := 1.0
var _sv: ColorRect
var _sv_mat: ShaderMaterial
var _sv_mark: Control
var _hue: ColorRect
var _hue_mark: Control
var _preview: Panel
var _hex: LineEdit


func _init() -> void:
	transparent_bg = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var title := Label.new()
	title.text = "Custom colour"
	title.theme_type_variation = &"Strong"
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_sv = ColorRect.new()
	_sv.custom_minimum_size = Vector2(240, 170)
	_sv_mat = ShaderMaterial.new()
	_sv_mat.shader = _shader(SV_SHADER)
	_sv.material = _sv_mat
	_sv.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_sv.gui_input.connect(_on_sv_input)
	row.add_child(_sv)
	_sv_mark = _marker(_sv)
	_hue = ColorRect.new()
	_hue.custom_minimum_size = Vector2(22, 170)
	var hm := ShaderMaterial.new()
	hm.shader = _shader(HUE_SHADER)
	_hue.material = hm
	_hue.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hue.gui_input.connect(_on_hue_input)
	row.add_child(_hue)
	_hue_mark = _marker(_hue)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	col.add_child(line)
	_preview = Panel.new()
	_preview.custom_minimum_size = Vector2(44, 36)
	line.add_child(_preview)
	var hex_label := Label.new()
	hex_label.text = "HEX"
	hex_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hex_label.theme_type_variation = &"Muted"
	line.add_child(hex_label)
	_hex = LineEdit.new()
	_hex.custom_minimum_size.x = 130
	_hex.max_length = 7
	_hex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hex.text_submitted.connect(func(_t: String) -> void: _from_hex())
	_hex.focus_exited.connect(_from_hex)
	line.add_child(_hex)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(hide)
	buttons.add_child(cancel)
	var ok := Button.new()
	ok.text = "OK"
	ok.theme_type_variation = &"AccentButton"
	ok.pressed.connect(func() -> void:
		_from_hex()
		hide()
		picked.emit(current()))
	buttons.add_child(ok)


## Otwiera okno pod wskazanym prostokątem (np. próbką „+”) z kolorem początkowym.
func open(start: Color, below: Rect2) -> void:
	add_theme_stylebox_override("panel", ThemeManager.card_box(ThemeManager.color("surface_2"),
			ThemeManager.color("border_strong"), 18))
	_h = start.h
	_s = start.s
	_v = start.v
	_update()
	reset_size()
	popup(Rect2i(Vector2i(below.position + Vector2(0, below.size.y + 8)), Vector2i.ZERO))
	if not _sv.resized.is_connected(_update):
		_sv.resized.connect(_update, CONNECT_ONE_SHOT)


func current() -> Color:
	return Color.from_hsv(_h, _s, _v)


func _on_sv_input(e: InputEvent) -> void:
	if _dragging(e):
		var p := ((e as InputEventMouse).position / _sv.size).clamp(Vector2.ZERO, Vector2.ONE)
		_s = p.x
		_v = 1.0 - p.y
		_update()


func _on_hue_input(e: InputEvent) -> void:
	if _dragging(e):
		_h = clampf((e as InputEventMouse).position.y / _hue.size.y, 0.0, 0.999)
		_update()


static func _dragging(e: InputEvent) -> bool:
	if e is InputEventMouseButton:
		return (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and e.pressed
	return e is InputEventMouseMotion and ((e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0


func _from_hex() -> void:
	var t := _hex.text.strip_edges().trim_prefix("#")
	if t.is_valid_html_color() and (t.length() == 6 or t.length() == 3):
		var c := Color(t)
		_h = c.h
		_s = c.s
		_v = c.v
	_update()


func _update() -> void:
	_sv_mat.set_shader_parameter(&"hue", _h)
	_sv_mark.position = Vector2(_s, 1.0 - _v) * _sv.size - _sv_mark.size * 0.5
	_hue_mark.position = Vector2(_hue.size.x * 0.5, _h * _hue.size.y) - _hue_mark.size * 0.5
	var c := current()
	_preview.add_theme_stylebox_override("panel", ThemeManager.box(c, ThemeManager.color("border_strong"), 8, 1))
	_hex.text = "#" + c.to_html(false).to_upper()


# Znacznik (pierścień) nad polem z shaderem – osobny węzeł, więc rysowany bez shadera rodzica.
static func _marker(parent: Control) -> Control:
	var m := Control.new()
	m.size = Vector2(14, 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func() -> void:
		m.draw_arc(m.size * 0.5, 6.0, 0.0, TAU, 24, Color.BLACK, 3.0, true)
		m.draw_arc(m.size * 0.5, 6.0, 0.0, TAU, 24, Color.WHITE, 1.5, true))
	parent.add_child(m)
	return m


static func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s
