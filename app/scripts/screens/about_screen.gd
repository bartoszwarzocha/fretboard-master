# Fretboard Master – okno „O programie”: wersja, prawa autorskie, licencja, składniki innych autorów.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends ModuleScreen

const COMPONENTS := [
	["Godot Engine", "MIT"], ["godot-cpp", "MIT"], ["PortAudio", "MIT"], ["PortMidi", "MIT"],
	["libsndfile", "LGPL 2.1"], ["TinySoundFont", "MIT"], ["PFFFT / KissFFT", "BSD"],
	["SQLite", "Public domain"], ["Inter, Space Grotesk, Noto", "OFL 1.1"],
]

var _version: Label
var _core: Label


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
	logos.add_child(Logo3D.create(Vector2(180, 90), false))

	_version = Label.new()
	_version.theme_type_variation = &"Muted"
	_version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(_version)
	var text := Label.new()
	text.text = "Fretboard Master is a guitar-learning program: an encyclopedia of scales and chords, trainers, note reading, a tuner and a metronome – with real-time recognition of the notes you play."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)

	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", 32)
	facts.add_theme_constant_override("v_separation", 8)
	col.add_child(facts)
	_fact(facts, "Copyright", "© 2026 BW Digital Systems & Publishing", false)
	_fact(facts, "Licence", "Freeware – proprietary licence", true)
	_core = _fact(facts, "C++ core", "", false)

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
	_refresh()


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
