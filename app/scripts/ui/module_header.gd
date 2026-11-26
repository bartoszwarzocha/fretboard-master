# Fretboard Master – nagłówek ekranów modułów: logo (pole zastępcze), zakładki modułów,
# przycisk ustawień. Klawisz Esc wraca do menu głównego.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ModuleHeader
extends PanelContainer

var active: StringName


static func create(p_active: StringName) -> ModuleHeader:
	var h := ModuleHeader.new()
	h.active = p_active
	return h


func _ready() -> void:
	set_process(false)
	theme_type_variation = &"Bar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var logo := Button.new()
	logo.flat = true
	logo.tooltip_text = "Main menu"
	logo.focus_mode = Control.FOCUS_NONE
	logo.custom_minimum_size = Vector2(210, 48)
	logo.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	logo.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	logo.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	logo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ph := Placeholder.create("Program logo", "assets/branding/logo.svg", "", Vector2(210, 48), true)
	ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.add_child(ph)
	logo.pressed.connect(App.go.bind(&"menu"))
	row.add_child(logo)

	var gap := Control.new()
	gap.custom_minimum_size.x = 24
	row.add_child(gap)

	for m in App.MODULES:
		if m.id == &"settings":
			continue
		var b := Button.new()
		b.theme_type_variation = &"NavButton"
		b.text = m.name
		b.toggle_mode = true
		b.button_pressed = m.id == active
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(App.go.bind(m.id))
		row.add_child(b)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var settings := Button.new()
	settings.theme_type_variation = &"NavButton"
	settings.text = "⚙"
	settings.tooltip_text = "Settings"
	settings.toggle_mode = true
	settings.button_pressed = active == &"settings"
	settings.add_theme_font_override("font", ThemeManager.font_symbols)
	settings.add_theme_font_size_override("font_size", 22)
	settings.pressed.connect(App.go.bind(&"settings"))
	row.add_child(settings)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		App.go(&"menu")
		get_viewport().set_input_as_handled()
