# Fretboard Master – okno „O programie”: wersja, prawa autorskie, licencja, składniki innych autorów.
# Copyright © 2026 BW Digital Systems and Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends ModuleScreen

const COMPONENTS := [
	["Godot Engine", "MIT"], ["godot-cpp", "MIT"], ["PortAudio", "MIT"], ["PortMidi", "MIT"],
	["libsndfile", "LGPL 2.1"], ["TinySoundFont", "MIT"], ["PFFFT / KissFFT", "BSD"],
	["SQLite", "Public domain"], ["ASIO SDK (Steinberg)", "Steinberg licence"],
	["GeneralUser GS (S. Christian Collins)", "GeneralUser GS licence"], ["Manrope, Montserrat, Rubik, Inter, Space Grotesk, Anton, Noto, Bravura", "OFL 1.1"],
]

var _version: Label
var _core: Label
var _licence: LicenseView


func _init() -> void:
	module_id = &"about"


func _build_content() -> void:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 920
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)

	var logos := HBoxContainer.new()
	logos.add_theme_constant_override("separation", 32)
	col.add_child(logos)
	logos.add_child(CompanyLogo.create(Vector2(250, 84)))
	logos.add_child(Logo3D.create(Vector2(191, 90), false))

	_version = Label.new()
	_version.theme_type_variation = &"Muted"
	_version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_version)
	var text := Label.new()
	text.text = "Fretboard Master is a guitar-learning program: an encyclopedia of scales and chords, exercises, note reading, a tuner and a metronome – with live assessment of your playing."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)

	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", 32)
	facts.add_theme_constant_override("v_separation", 8)
	col.add_child(facts)
	_fact(facts, "Copyright", "© 2026 BW Digital Systems and Publishing – Bartosz Warzocha", false)
	_fact(facts, "Licence", "Freeware – proprietary licence", true)
	_core = _fact(facts, "C++ core", "", false)
	var show := Button.new()
	show.text = "Show licence"
	show.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	show.pressed.connect(_open_licence)
	col.add_child(show)

	col.add_child(HSeparator.new())
	var head := Label.new()
	head.text = "Third-party components"
	head.theme_type_variation = &"Strong"
	col.add_child(head)
	var libs := GridContainer.new()
	libs.columns = 6
	libs.add_theme_constant_override("h_separation", 20)
	libs.add_theme_constant_override("v_separation", 6)
	col.add_child(libs)
	for c in COMPONENTS:
		var n := Label.new()
		n.text = c[0]
		n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		libs.add_child(n)
		var l := Label.new()
		l.text = c[1]
		l.theme_type_variation = &"Caption"
		libs.add_child(l)
	var tm := Label.new()
	tm.text = "ASIO is a registered trademark of Steinberg Media Technologies GmbH."
	tm.theme_type_variation = &"Caption"
	tm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(tm)
	_refresh()


# Okno licencji nad treścią ekranu (tworzone przy pierwszym otwarciu).
func _open_licence() -> void:
	if _licence == null:
		_licence = LicenseView.new()
		_licence.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_licence.offset_left = 64
		_licence.offset_right = -64
		_licence.offset_top = 110
		_licence.offset_bottom = -40
		add_child(_licence)
	_licence.show()


func _fact(grid: GridContainer, key: String, value: String, translate: bool) -> Label:
	var k := Label.new()
	k.text = key
	k.theme_type_variation = &"Caption"
	grid.add_child(k)
	var v := Label.new()
	v.text = value
	v.theme_type_variation = &"Strong"
	if not translate:
		v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	grid.add_child(v)
	return v


func _refresh() -> void:
	_version.text = tr("Version %s") % App.version() + " · Godot " + Engine.get_version_info().string
	_core.text = tr("version %s") % NoteNames.core_version() if NoteNames.core_available() else tr("not built – GDScript fallback")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _version:
		_refresh()
