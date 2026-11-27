# Fretboard Master – siatka kafelków menu głównego: 3 kolumny × 3 wiersze, pierwszy kafelek
# (Encyklopedia) zajmuje dwa wiersze, tak jak w makiecie.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name TileGrid
extends Container

const COLUMNS := 3
const ROWS := 3
var gap := 24.0


func _ready() -> void:
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout()


func _get_minimum_size() -> Vector2:
	return Vector2(COLUMNS * 260 + (COLUMNS - 1) * gap, ROWS * 170 + (ROWS - 1) * gap)


func _layout() -> void:
	var cw := (size.x - gap * (COLUMNS - 1)) / COLUMNS
	var rh := (size.y - gap * (ROWS - 1)) / ROWS
	# Kolejność miejsc: [kolumna, wiersz, wysokość w wierszach]
	var slots := [[0, 0, 2], [1, 0, 1], [2, 0, 1], [1, 1, 1], [2, 1, 1], [0, 2, 1], [1, 2, 1], [2, 2, 1]]
	var i := 0
	for child in get_children():
		var c := child as Control
		if c == null or not c.visible or i >= slots.size():
			continue
		var s: Array = slots[i]
		var rect := Rect2(s[0] * (cw + gap), s[1] * (rh + gap), cw, rh * s[2] + gap * (s[2] - 1))
		fit_child_in_rect(c, rect)
		i += 1
