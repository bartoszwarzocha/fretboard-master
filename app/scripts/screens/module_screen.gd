# Fretboard Master – ekran modułu: nagłówek z nawigacją i treść. Na razie tylko pole
# „Moduł w przygotowaniu” – logika modułów powstanie w kolejnych etapach.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name ModuleScreen
extends Control

var module_id: StringName
var content: VBoxContainer


func _ready() -> void:
	set_process(false)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(ModuleHeader.create(module_id))
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	col.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)
	_build_content()


func _build_content() -> void:
	var m := App.module(module_id)
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(card)
	var center := CenterContainer.new()
	card.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var icon := IconGlyph.new()
	icon.glyph = m.get("icon", "")
	icon.font_size = 64
	icon.color = m.get("color", Color.WHITE)
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var title := Label.new()
	title.text = m.get("name", "")
	title.theme_type_variation = &"Heading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var info := Label.new()
	info.text = "This module is under construction."
	info.theme_type_variation = &"Muted"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var hint := Label.new()
	hint.text = "Esc – back to the main menu"
	hint.theme_type_variation = &"Caption"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
