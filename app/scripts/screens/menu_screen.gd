# Fretboard Master – menu główne: logo, kafelki modułów, stopka z wersją i logo firmy.
# Copyright © 2026 BW Digital Systems & Publishing – Bartosz Warzocha. Wszelkie prawa zastrzeżone.
extends Control


func _ready() -> void:
	set_process(false)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 32)
	margin.add_child(page)

	# Nagłówek: logo programu i hasło
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 32)
	page.add_child(head)
	head.add_child(Placeholder.create("Program logo", "assets/branding/logo.svg", "", Vector2(620, 150)))
	var tagline := Label.new()
	tagline.text = "fretboard · theory · training"
	tagline.theme_type_variation = &"Caption"
	tagline.uppercase = true
	tagline.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(tagline)

	# Treść: powitanie po lewej, kafelki po prawej
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 48)
	page.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 360
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var hello := Label.new()
	hello.text = "Hello!"
	hello.theme_type_variation = &"Muted"
	hello.add_theme_font_size_override("font_size", 18)
	left.add_child(hello)
	var question := Label.new()
	question.text = "What shall we practise today?"
	question.theme_type_variation = &"Title"
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(question)

	var grid := TileGrid.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var first: Control
	for i in App.MODULES.size():
		var tile := ModuleTile.create(App.MODULES[i], i == 0)
		grid.add_child(tile)
		if i == 0:
			first = tile

	# Stopka
	page.add_child(HSeparator.new())
	var foot := HBoxContainer.new()
	foot.custom_minimum_size.y = 72
	foot.add_theme_constant_override("separation", 24)
	page.add_child(foot)
	var company := CompanyLogo.create(Vector2(150, 40))
	company.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(company)
	var copyright := Label.new()
	copyright.text = "© 2026 BW Digital Systems & Publishing"
	copyright.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	copyright.theme_type_variation = &"Muted"
	copyright.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(copyright)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var about := Button.new()
	about.text = "About"
	about.theme_type_variation = &"TextLink"
	about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	about.pressed.connect(App.go.bind(&"about"))
	foot.add_child(about)
	var bar := Label.new()
	bar.text = "|"
	bar.theme_type_variation = &"Caption"
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(bar)
	var version := Label.new()
	version.theme_type_variation = &"Strong"
	version.add_theme_font_size_override("font_size", 16)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	version.text = tr("Version %s") % App.version()
	foot.add_child(version)
	_version_label = version

	first.grab_focus.call_deferred()


var _version_label: Label


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _version_label:
		_version_label.text = tr("Version %s") % App.version()
