# Fretboard Master – okno wyboru czcionki systemowej: pole wyszukiwania i lista nazw, każda zapisana
# swoją czcionką. Czcionki wczytywane są dopiero dla pozycji widocznych na liście (systemowych bywa
# kilkaset – wczytanie wszystkich naraz spowalniałoby otwarcie okna).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name FontPopup
extends PopupPanel

signal picked(font_name: String)

var _filter: LineEdit
var _scroll: ScrollContainer
var _list: VBoxContainer
var _names := PackedStringArray()
var _current := ""


func _init() -> void:
	transparent_bg = true
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(440, 460)
	add_child(col)
	var title := Label.new()
	title.text = "System font"
	title.theme_type_variation = &"Strong"
	col.add_child(title)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Search…"
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_t: String) -> void: _fill())
	col.add_child(_filter)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _load_visible.call_deferred())
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel.pressed.connect(hide)
	col.add_child(cancel)


## Otwiera okno pod wskazanym prostokątem; current – nazwa wybranej teraz czcionki systemowej.
func open(current: String, below: Rect2) -> void:
	add_theme_stylebox_override("panel", ThemeManager.card_box(ThemeManager.color("surface_2"),
			ThemeManager.color("border_strong"), 18))
	_current = current
	if _names.is_empty():
		_names = OS.get_system_fonts()
		_names.sort()
	_filter.text = ""
	_fill()
	reset_size()
	popup(Rect2i(Vector2i(below.position + Vector2(0, below.size.y + 8)), Vector2i.ZERO))
	_filter.grab_focus()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var q := _filter.text.strip_edges().to_lower()
	for n in _names:
		if not q.is_empty() and not n.to_lower().contains(q):
			continue
		var b := Button.new()
		b.text = n
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.custom_minimum_size.y = 40
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", ThemeManager.fs(18))
		var bg := ThemeManager.color("border") if n == _current else Color.TRANSPARENT
		b.add_theme_stylebox_override("normal", ThemeManager.box(bg, Color.TRANSPARENT, 8, 0, 12, 6))
		b.add_theme_stylebox_override("hover", ThemeManager.box(ThemeManager.color("border_strong"), Color.TRANSPARENT, 8, 0, 12, 6))
		b.add_theme_stylebox_override("pressed", ThemeManager.box(ThemeManager.color("border_strong"), Color.TRANSPARENT, 8, 0, 12, 6))
		b.pressed.connect(func() -> void:
			hide()
			picked.emit(n))
		b.set_meta(&"font", n)
		_list.add_child(b)
	_scroll.scroll_vertical = 0
	_load_visible.call_deferred()


# Czcionka podglądu tylko dla pozycji w widocznym fragmencie listy (z zapasem jednego ekranu).
func _load_visible() -> void:
	var top := _scroll.scroll_vertical - _scroll.size.y
	var bottom := _scroll.scroll_vertical + _scroll.size.y * 2.0
	for c in _list.get_children():
		var b := c as Button
		if b.is_queued_for_deletion() or not b.has_meta(&"font"):
			continue
		if b.position.y + b.size.y < top or b.position.y > bottom:
			continue
		b.add_theme_font_override("font", ThemeManager.body_font("system:" + str(b.get_meta(&"font"))))
		b.remove_meta(&"font")
