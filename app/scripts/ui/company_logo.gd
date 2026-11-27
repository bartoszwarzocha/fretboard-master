# Fretboard Master – logo firmy BW Digital Systems & Publishing (białe, z przezroczystością).
# Kolor nadaje modulate: na ekranie startowym biały, w pozostałych – kolor tekstu bieżącego motywu.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name CompanyLogo
extends TextureRect

const TEXTURE := preload("res://assets/branding/bw-logo.png")

var _follow_theme := true


static func create(p_size: Vector2, follow_theme := true) -> CompanyLogo:
	var l := CompanyLogo.new()
	l.texture = TEXTURE
	l.custom_minimum_size = p_size
	l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	l.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.tooltip_text = "BW Digital Systems & Publishing"
	l._follow_theme = follow_theme
	return l


func _ready() -> void:
	set_process(false)
	if _follow_theme:
		_apply_color()
		ThemeManager.theme_changed.connect(_apply_color)


func _apply_color() -> void:
	self_modulate = ThemeManager.color("text")
