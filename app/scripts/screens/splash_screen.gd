# Fretboard Master – ekran startowy: całkowicie czarny, logo firmy, „przedstawia”, logo programu.
# Bez klikania; logo programu nadlatuje z oddali, po 3 s przejście do menu głównego.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Control

const DURATION := 3.0

var _company: Control
var _logo: Control


func _ready() -> void:
	set_process(false)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	center.add_child(col)

	var company := CompanyLogo.create(Vector2(260, 70), false)
	_company = company
	company.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(company)
	var presents := Label.new()
	presents.text = "presents"
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents.add_theme_color_override("font_color", Color("8C96B3"))
	presents.add_theme_font_size_override("font_size", 20)
	col.add_child(presents)
	var logo := Logo3D.create(Vector2(680, 320), true, DURATION - 0.4)
	_logo = logo
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(logo)

	if not "--perf-audit" in OS.get_cmdline_user_args():
		get_tree().create_timer(DURATION).timeout.connect(App.go.bind(&"menu"))


# Położenie obu logo – menu główne zaczyna od nich przejście (logo odjeżdżają na swoje miejsca).
func logo_rects() -> Dictionary:
	return {"logo": _logo.get_global_rect(), "company": _company.get_global_rect()}
