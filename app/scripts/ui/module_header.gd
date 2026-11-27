# Fretboard Master – nagłówek ekranów modułów: logo (pole zastępcze), zakładki modułów,
# przycisk ustawień. Klawisz Esc wraca do menu głównego.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
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
	logo.custom_minimum_size = Vector2(117, 55)
	logo.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	logo.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	logo.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	logo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ph := Logo3D.create(Vector2(117, 55), false)
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

	# Stan jak w makiecie: strój gitary i gotowość wejścia audio.
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 10)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(status)
	status.add_child(_status_label(tr("Tuning:"), ThemeManager.color("muted"), false))
	status.add_child(_status_label(tuning_text(), ThemeManager.color("text"), true))
	status.add_child(_status_label("|", ThemeManager.color("placeholder"), false))
	status.add_child(_status_label(tr("Audio input:"), ThemeManager.color("muted"), false))
	var ready := AudioServer.get_input_device_list().size() > 0
	status.add_child(_status_label(tr("ready") if ready else tr("none"),
			ThemeManager.color("focus") if ready else ThemeManager.color("faint"), true))
	var gap2 := Control.new()
	gap2.custom_minimum_size.x = 8
	row.add_child(gap2)

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


func _status_label(text: String, color: Color, strong: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", ThemeManager.fs(15))
	l.add_theme_color_override("font_color", color)
	if strong:
		l.add_theme_font_override("font", ThemeManager.font_body_bold)
	return l


# Dźwięki pustych strun z ustawienia „Strój” (od najniższej), w wybranym zapisie nazw dźwięków.
const TUNING_MIDI := {
	"standard": [40, 45, 50, 55, 59, 64], "drop_d": [38, 45, 50, 55, 59, 64],
	"half_down": [39, 44, 49, 54, 58, 63], "full_down": [38, 43, 48, 53, 57, 62],
	"drop_c": [36, 43, 48, 53, 57, 62], "dadgad": [38, 45, 50, 55, 57, 62],
	"open_g": [38, 43, 50, 55, 59, 62], "open_d": [38, 45, 50, 54, 57, 62], "open_e": [40, 47, 52, 56, 59, 64],
}


static func tuning_text() -> String:
	var notes: Array = TUNING_MIDI.get(str(App.setting(&"tuning")), TUNING_MIDI["standard"])
	var parts := PackedStringArray()
	for m in notes:
		parts.append(NoteNames.note_name(m, App.notation()))
	return " ".join(parts)
