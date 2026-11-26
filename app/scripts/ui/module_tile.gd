# Fretboard Master – kafelek modułu w menu głównym (przycisk z ikoną, nazwą i opisem).
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ModuleTile
extends Button

var module: Dictionary
var big := false
var _icon_box: PanelContainer
var _icon: Label


static func create(p_module: Dictionary, p_big := false) -> ModuleTile:
	var t := ModuleTile.new()
	t.module = p_module
	t.big = p_big
	return t


func _ready() -> void:
	set_process(false)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_icon_box = PanelContainer.new()
	_icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var s := 72 if big else 52
	_icon_box.custom_minimum_size = Vector2(s, s)
	box.add_child(_icon_box)
	_icon = Label.new()
	_icon.text = module.icon
	_icon.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon.add_theme_font_override("font", ThemeManager.font_symbols)
	_icon.add_theme_font_size_override("font_size", 40 if big else 28)
	_icon.add_theme_color_override("font_color", module.color)
	_icon_box.add_child(_icon)

	if big:
		var art := Placeholder.create("Guitar artwork", "assets/graphics/menu-guitar.png",
				"1800 × 1200 px (3:2), PNG", Vector2(0, 220))
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(art)
	else:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(spacer)

	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = module.name
	box.add_child(title)
	var desc := Label.new()
	desc.theme_type_variation = &"Muted"
	desc.text = module.desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 120
	box.add_child(desc)

	pressed.connect(func(): App.go(module.id))
	ThemeManager.theme_changed.connect(_apply_styles)
	_apply_styles()


func _apply_styles() -> void:
	var c: Color = module.color
	var normal := ThemeManager.box(ThemeManager.color("surface"), ThemeManager.color("border"), ThemeManager.RADIUS_CARD, 1, 24, 24)
	var hover := ThemeManager.box(ThemeManager.color("surface").lerp(c, 0.08), c, ThemeManager.RADIUS_CARD, 1, 24, 24)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("focus", ThemeManager.box(Color.TRANSPARENT, ThemeManager.color("focus"), ThemeManager.RADIUS_CARD + 3, 2))
	get_theme_stylebox("focus").draw_center = false
	_icon_box.add_theme_stylebox_override("panel", ThemeManager.box(Color(c, 0.12), Color.TRANSPARENT, 16, 0, 0, 0))
