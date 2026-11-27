# Fretboard Master – okno „Licencja” (otwierane z „O programie”): licencja programu (freeware)
# i składniki innych autorów z ich licencjami. Treść z plików res://legal/*.txt – kopii LICENSE.md
# i THIRD-PARTY-NOTICES.md z katalogu głównego (tools/sync_legal.py) – oraz z informacji silnika
# Godot o jego licencji i składnikach (Engine.get_license_text, get_copyright_info, get_license_info).
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
class_name LicenseView
extends PanelContainer

const LICENSE_PATH := "res://legal/LICENSE.txt"
const NOTICES_PATH := "res://legal/THIRD-PARTY-NOTICES.txt"
const OFL_PATH := "res://assets/fonts/OFL-manrope.txt"
const GUGS_PATH := "res://assets/sound/GeneralUser-GS-LICENSE.txt"

var _text: RichTextLabel
var _tabs: Array[Button] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", ThemeManager.card_box(ThemeManager.color("surface"), ThemeManager.color("border"), 24))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)
	for i in 2:
		var b := Button.new()
		b.text = ["Program licence", "Third-party components"][i]
		b.toggle_mode = true
		b.pressed.connect(_show.bind(i))
		bar.add_child(b)
		_tabs.append(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	bar.add_child(close)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.selection_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.add_theme_font_override("bold_font", ThemeManager.font_body_bold)
	col.add_child(_text)
	_show(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _show(tab: int) -> void:
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(i == tab)
	_text.clear()
	_text.text = _program_licence() if tab == 0 else _third_party()
	_text.scroll_to_line(0)


# Licencja programu: wersja polska przy języku polskim, w pozostałych – angielska.
func _program_licence() -> String:
	var md := _read(LICENSE_PATH)
	var cut := md.find("## English version")
	if cut >= 0:
		var title := md.substr(0, md.find("\n"))
		md = md.substr(0, cut) if TranslationServer.get_locale().begins_with("pl") else title + "\n\n" + md.substr(cut)
	md = md.replace("*English version below.*\n", "")
	return _bbcode(md)


func _third_party() -> String:
	var out := _bbcode(_read(NOTICES_PATH))
	out += "\n\n" + _heading("Godot Engine", 2) + _escape(Engine.get_license_text())
	out += "\n" + _heading("Godot Engine – third-party components", 2)
	for part in Engine.get_copyright_info():
		var names := PackedStringArray()
		var lic := ""
		for p in part.parts:
			names.append(", ".join(p.copyright))
			lic = p.license
		out += "[b]%s[/b] – %s\n%s\n\n" % [_escape(part.name), _escape(lic), _escape("\n".join(names))]
	var licences := Engine.get_license_info()
	for key in licences:
		out += _heading(str(key), 3) + _escape(str(licences[key])) + "\n"
	for p in [OFL_PATH, GUGS_PATH]:
		var t := _read(p)
		if not t.is_empty():
			out += "\n" + _heading(p.get_file().get_basename(), 2) + _escape(t)
	return out


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""


static func _escape(s: String) -> String:
	return s.replace("[", "[lb]")


static func _heading(s: String, level: int) -> String:
	var size: int = [0, 26, 21, 17][clampi(level, 1, 3)]
	return "[font_size=%d][b]%s[/b][/font_size]\n" % [size, _escape(s)]


# Prosty Markdown → BBCode: nagłówki, pogrubienia, kursywa, kod, tabele (wiersze jako punkty).
static func _bbcode(md: String) -> String:
	var out := PackedStringArray()
	var header_row := true
	for raw in md.split("\n"):
		var line := raw.strip_edges(false, true)
		if line.begins_with("|"):
			if line.replace("|", "").replace("-", "").strip_edges().is_empty():
				continue   # wiersz oddzielający w tabeli
			var cells := PackedStringArray()
			for c in line.trim_prefix("|").trim_suffix("|").split("|"):
				cells.append(_inline(c.strip_edges()))
			if header_row:
				header_row = false
				continue   # nagłówek tabeli – kolumny wynikają z treści
			out.append("• [b]%s[/b] – %s" % [cells[0], " – ".join(cells.slice(1))])
			continue
		header_row = true
		if line == "---":
			out.append("")
		elif line.begins_with("### "):
			out.append(_heading_inline(line.substr(4), 3))
		elif line.begins_with("## "):
			out.append(_heading_inline(line.substr(3), 2))
		elif line.begins_with("# "):
			out.append(_heading_inline(line.substr(2), 1))
		else:
			out.append(_inline(line))
	return "\n".join(out)


static func _heading_inline(s: String, level: int) -> String:
	var size: int = [0, 26, 21, 17][level]
	return "[font_size=%d][b]%s[/b][/font_size]" % [size, _inline(s)]


static func _inline(s: String) -> String:
	s = _escape(s)
	var re := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	s = re.sub(s, "[b]$1[/b]", true)
	re = RegEx.create_from_string("(?<![\\w*])\\*(?!\\s)(.+?)(?<!\\s)\\*(?![\\w*])")
	s = re.sub(s, "[i]$1[/i]", true)
	re = RegEx.create_from_string("`([^`]+)`")
	s = re.sub(s, "[code]$1[/code]", true)
	return s
