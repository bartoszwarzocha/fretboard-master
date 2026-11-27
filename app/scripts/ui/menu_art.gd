# Fretboard Master – miejsce na ilustrację 3D w kafelku menu (gitara albo ikona modułu).
# Sam nic nie renderuje: rysuje swój wycinek wspólnego obrazu sceny menu (MenuStage3D), więc
# animacje kafelka (skala, przezroczystość) działają na ilustrację bez dodatkowych kosztów.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name MenuArt
extends Control

enum Kind { GUITAR, ICON }

var kind := Kind.ICON
var module_id: StringName
var tile: Control             # kafel, w którym leży (położenie w siatce bez animacji skali)
var texture: Texture2D        # obraz wspólnej sceny
var region := Rect2()         # wycinek obrazu sceny (w pikselach)


static func create(p_kind: Kind, p_id: StringName, p_min: Vector2) -> MenuArt:
	var a := MenuArt.new()
	a.kind = p_kind
	a.module_id = p_id
	a.custom_minimum_size = p_min
	a.size_flags_vertical = Control.SIZE_EXPAND_FILL
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


# Prostokąt w układzie siatki kafelków – bez skali animacji wejścia kafelka.
func layout_rect() -> Rect2:
	var p := Vector2.ZERO
	var n: Control = self
	while n != null and n != tile:
		p += n.position
		n = n.get_parent() as Control
	return Rect2(tile.position + p, size)


func _draw() -> void:
	if texture:
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), region)
