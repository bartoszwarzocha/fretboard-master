# Fretboard Master – pole zastępcze dla grafiki, którą dostarczy autor.
# Pokazuje przeznaczenie, docelową ścieżkę pliku i wymiary. Rysowane jednym _draw.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name Placeholder
extends Control

var title := ""
var file_path := ""
var details := ""
var compact := false


static func create(p_title: String, p_file: String, p_details: String, p_size: Vector2, p_compact := false) -> Placeholder:
	var ph := Placeholder.new()
	ph.title = p_title
	ph.file_path = p_file
	ph.details = p_details
	ph.compact = p_compact
	ph.custom_minimum_size = p_size
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ph


func _ready() -> void:
	set_process(false)
	tooltip_text = file_path
	ThemeManager.theme_changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ONE, size - Vector2.ONE * 2)
	var c := ThemeManager.color("placeholder")
	var dash := 8.0
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], c, 1.5, dash)
	var font := ThemeManager.font_body_medium
	var small := ThemeManager.font_body
	var lines: Array = [[tr(title), font, 18 if not compact else 13, ThemeManager.color("muted")]]
	if not compact:
		lines.append([file_path, small, 14, ThemeManager.color("faint")])
		if not details.is_empty():
			lines.append([tr(details), small, 14, ThemeManager.color("faint")])
	var heights := 0.0
	for l in lines:
		heights += l[1].get_height(l[2]) + 4.0
	var y := (size.y - heights) * 0.5
	for l in lines:
		var f: Font = l[1]
		var asc := f.get_ascent(l[2])
		draw_string(f, Vector2(8, y + asc), l[0], HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, l[2], l[3])
		y += f.get_height(l[2]) + 4.0
